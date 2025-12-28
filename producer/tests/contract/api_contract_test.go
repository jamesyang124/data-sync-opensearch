package contract

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/murcurial/data-sync-opensearch/producer/internal/api"
	"github.com/murcurial/data-sync-opensearch/producer/internal/database"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
	"go.uber.org/zap"
)

func setupTestDB(ctx context.Context, t *testing.T) (*postgres.PostgresContainer, string) {
	dbName := "testdb"
	dbUser := "testuser"
	dbPassword := "testpassword"

	postgresContainer, err := postgres.Run(ctx,
		"postgres:15-alpine",
		postgres.WithDatabase(dbName),
		postgres.WithUsername(dbUser),
		postgres.WithPassword(dbPassword),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(5*time.Second)),
	)
	if err != nil {
		t.Fatalf("failed to start postgres container: %s", err)
	}

	connStr, err := postgresContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %s", err)
	}

	return postgresContainer, connStr
}

func initSchema(ctx context.Context, pool *pgxpool.Pool, t *testing.T) {
	queries := []string{
		`CREATE TABLE users (
			user_id UUID PRIMARY KEY,
			username VARCHAR(50) UNIQUE NOT NULL,
			email VARCHAR(255) UNIQUE NOT NULL,
			created_at TIMESTAMP NOT NULL,
			updated_at TIMESTAMP NOT NULL
		);`,
		`CREATE TABLE videos (
			video_id UUID PRIMARY KEY,
			user_id UUID NOT NULL REFERENCES users(user_id),
			title VARCHAR(255) NOT NULL,
			description TEXT,
			duration INT,
			created_at TIMESTAMP NOT NULL,
			updated_at TIMESTAMP NOT NULL
		);`,
	}

	for _, query := range queries {
		_, err := pool.Exec(ctx, query)
		if err != nil {
			t.Fatalf("failed to execute query %s: %v", query, err)
		}
	}
}

func TestAPIContract(t *testing.T) {
	ctx := context.Background()
	container, connStr := setupTestDB(ctx, t)
	defer container.Terminate(ctx)

	poolConfig, _ := pgxpool.ParseConfig(connStr)
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		t.Fatalf("failed to connect to db: %v", err)
	}
	defer pool.Close()

	initSchema(ctx, pool, t)

	logger := zap.NewNop()
	db := &database.Database{Pool: pool}
	server := api.NewServer(db, logger)

	t.Run("CreateUser_Contract", func(t *testing.T) {
		payload := map[string]string{
			"username": "contract_user",
			"email":    "contract@example.com",
		}
		body, _ := json.Marshal(payload)
		req := httptest.NewRequest("POST", "/api/v1/users", bytes.NewBuffer(body))
		w := httptest.NewRecorder()

		server.Router.ServeHTTP(w, req)

		if w.Code != http.StatusCreated {
			t.Errorf("expected 201, got %d", w.Code)
		}

		var resp map[string]interface{}
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to unmarshal response: %v", err)
		}

		// Validate expected keys in response
		expectedKeys := []string{"user_id", "username", "created_at"}
		for _, key := range expectedKeys {
			if _, ok := resp[key]; !ok {
				t.Errorf("missing expected key: %s", key)
			}
		}
	})

	t.Run("HealthCheck_Contract", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/health", nil)
		w := httptest.NewRecorder()

		server.Router.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("expected 200, got %d", w.Code)
		}

		var resp map[string]interface{}
		json.Unmarshal(w.Body.Bytes(), &resp)

		if val, ok := resp["status"]; !ok || val != "up" {
			t.Errorf("expected status: up, got %v", val)
		}
		if _, ok := resp["db_connection"]; !ok {
			t.Error("missing db_connection key")
		}
	})

	t.Run("Metrics_Contract", func(t *testing.T) {
		req := httptest.NewRequest("GET", "/metrics", nil)
		w := httptest.NewRecorder()

		server.Router.ServeHTTP(w, req)

		var resp map[string]interface{}
		json.Unmarshal(w.Body.Bytes(), &resp)

		expectedSections := []string{"http", "db", "runtime"}
		for _, section := range expectedSections {
			if _, ok := resp[section]; !ok {
				t.Errorf("missing expected section: %s", section)
			}
		}
	})
}
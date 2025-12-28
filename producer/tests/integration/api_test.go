package integration

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
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
	"go.uber.org/zap"
)

var (
	dbPool *pgxpool.Pool
	server *api.Server
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

func TestAPI(t *testing.T) {
	ctx := context.Background()
	container, connStr := setupTestDB(ctx, t)
	defer container.Terminate(ctx)

	// Parse connStr to Config
	// This is a bit manual but required since we're bypassing config loading
	// connStr format: postgres://user:pass@host:port/dbname?sslmode=disable
	
	// Create DB connection
	poolConfig, _ := pgxpool.ParseConfig(connStr)
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		t.Fatalf("failed to connect to db: %v", err)
	}
	defer pool.Close()

	initSchema(ctx, pool, t)

	logger := zap.NewNop()
	db := &database.Database{Pool: pool}
	server = api.NewServer(db, logger)
	ts := httptest.NewServer(server.Router)
	defer ts.Close()

	t.Run("CreateUser_HappyPath", func(t *testing.T) {
		user := models.User{
			Username: "testuser",
			Email:    "test@example.com",
		}
		body, _ := json.Marshal(user)
		resp, err := http.Post(ts.URL+"/api/v1/users", "application/json", bytes.NewBuffer(body))
		if err != nil {
			t.Fatalf("failed to make request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusCreated {
			t.Errorf("expected status 201, got %d", resp.StatusCode)
		}

		var created models.User
		json.NewDecoder(resp.Body).Decode(&created)
		if created.ID.String() == "00000000-0000-0000-0000-000000000000" {
			t.Error("expected valid ID")
		}
	})

	t.Run("CreateUser_Duplicate", func(t *testing.T) {
		user := models.User{
			Username: "testuser", // Same username as above
			Email:    "other@example.com",
		}
		body, _ := json.Marshal(user)
		resp, err := http.Post(ts.URL+"/api/v1/users", "application/json", bytes.NewBuffer(body))
		if err != nil {
			t.Fatalf("failed to make request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusConflict {
			t.Errorf("expected status 409, got %d", resp.StatusCode)
		}
	})
	
	t.Run("CreateVideo_HappyPath", func(t *testing.T) {
		// First verify user exists (from previous test) or create new one
		// We'll create a dedicated user for this test to be safe
		u := models.User{Username: "videouser", Email: "video@test.com"}
		uBody, _ := json.Marshal(u)
		uResp, _ := http.Post(ts.URL+"/api/v1/users", "application/json", bytes.NewBuffer(uBody))
		var createdUser models.User
		json.NewDecoder(uResp.Body).Decode(&createdUser)

		video := models.Video{
			UserID: createdUser.ID,
			Title: "Test Video",
			Duration: 120,
		}
		body, _ := json.Marshal(video)
		resp, err := http.Post(ts.URL+"/api/v1/videos", "application/json", bytes.NewBuffer(body))
		if err != nil {
			t.Fatalf("failed to make request: %v", err)
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusCreated {
			t.Errorf("expected status 201, got %d", resp.StatusCode)
		}
	})

	t.Run("CreateVideo_InvalidUser", func(t *testing.T) {
		// Random UUID that doesn't exist
		video := models.Video{
			UserID: models.User{}.ID, // Nil UUID or we could generate random
			Title: "Orphan Video",
		}
		// Actually set a random valid-format UUID
		// But here we rely on the DB to fail FK constraint.
		// Let's use 00000.. which shouldn't exist unless created.
		
		body, _ := json.Marshal(video)
		resp, err := http.Post(ts.URL+"/api/v1/videos", "application/json", bytes.NewBuffer(body))
		if err != nil {
			t.Fatalf("failed to make request: %v", err)
		}
		defer resp.Body.Close()

		// Should return 409 Conflict per our handler logic for FK violations
		if resp.StatusCode != http.StatusConflict {
			t.Errorf("expected status 409, got %d", resp.StatusCode)
		}
	})
}

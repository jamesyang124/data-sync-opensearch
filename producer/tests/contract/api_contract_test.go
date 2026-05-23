package contract

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
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
	t.Helper()
	defer func() {
		if r := recover(); r != nil {
			t.Skipf("Docker/testcontainers unavailable: %v", r)
		}
	}()

	postgresContainer, err := postgres.Run(ctx,
		"postgres:15-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("testuser"),
		postgres.WithPassword("testpassword"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(10*time.Second)),
	)
	if err != nil {
		t.Skipf("Docker/testcontainers unavailable: %s", err)
	}

	connStr, err := postgresContainer.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("failed to get connection string: %s", err)
	}

	return postgresContainer, connStr
}

func initSchema(ctx context.Context, pool *pgxpool.Pool, t *testing.T) {
	t.Helper()
	schemaPath := filepath.Join("..", "..", "..", "postgres", "init", "01-create-schema.sql")
	schema, err := os.ReadFile(schemaPath)
	if err != nil {
		t.Fatalf("failed to read canonical schema: %v", err)
	}

	sql := strings.ReplaceAll(string(schema), "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app;", "")
	if _, err := pool.Exec(ctx, sql); err != nil {
		t.Fatalf("failed to initialize schema: %v", err)
	}
}

func TestAPIContract(t *testing.T) {
	ctx := context.Background()
	container, connStr := setupTestDB(ctx, t)
	defer func() { _ = container.Terminate(ctx) }()

	poolConfig, _ := pgxpool.ParseConfig(connStr)
	pool, err := pgxpool.NewWithConfig(ctx, poolConfig)
	if err != nil {
		t.Fatalf("failed to connect to db: %v", err)
	}
	defer pool.Close()

	initSchema(ctx, pool, t)

	server := api.NewServer(&database.Database{Pool: pool}, zap.NewNop())

	t.Run("CreateUser_Contract", func(t *testing.T) {
		payload := map[string]string{
			"channel_id":   "contract_channel",
			"channel_name": "Contract Channel",
		}
		body, _ := json.Marshal(payload)
		req := httptest.NewRequest(http.MethodPost, "/api/v1/users", bytes.NewBuffer(body))
		w := httptest.NewRecorder()

		server.Router.ServeHTTP(w, req)

		if w.Code != http.StatusCreated {
			t.Fatalf("expected 201, got %d", w.Code)
		}

		var resp map[string]interface{}
		if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
			t.Fatalf("failed to unmarshal response: %v", err)
		}

		for _, key := range []string{"channel_id", "channel_name", "created_at", "updated_at"} {
			if _, ok := resp[key]; !ok {
				t.Errorf("missing expected key: %s", key)
			}
		}
	})

	t.Run("Routes_Contract", func(t *testing.T) {
		expectedRoutes := []struct {
			method string
			path   string
		}{
			{http.MethodPost, "/api/v1/videos"},
			{http.MethodPut, "/api/v1/videos/contract_video"},
			{http.MethodDelete, "/api/v1/videos/contract_video"},
			{http.MethodPost, "/api/v1/comments"},
			{http.MethodPut, "/api/v1/comments/contract_comment"},
			{http.MethodDelete, "/api/v1/comments/contract_comment"},
		}

		for _, route := range expectedRoutes {
			req := httptest.NewRequest(route.method, route.path, bytes.NewBufferString(`{}`))
			w := httptest.NewRecorder()
			server.Router.ServeHTTP(w, req)
			if w.Code == http.StatusNotFound || w.Code == http.StatusMethodNotAllowed {
				t.Errorf("%s %s route is not registered, got %d", route.method, route.path, w.Code)
			}
		}
	})

	t.Run("HealthCheck_Contract", func(t *testing.T) {
		req := httptest.NewRequest(http.MethodGet, "/health", nil)
		w := httptest.NewRecorder()

		server.Router.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("expected 200, got %d", w.Code)
		}
	})
}

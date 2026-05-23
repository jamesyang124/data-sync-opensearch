package integration

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
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
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

func requestJSON(t *testing.T, client *http.Client, method, url string, payload interface{}) *http.Response {
	t.Helper()
	body, err := json.Marshal(payload)
	if err != nil {
		t.Fatalf("failed to marshal payload: %v", err)
	}
	req, err := http.NewRequest(method, url, bytes.NewBuffer(body))
	if err != nil {
		t.Fatalf("failed to build request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		t.Fatalf("failed to make request: %v", err)
	}
	return resp
}

func TestAPI(t *testing.T) {
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
	ts := httptest.NewServer(server.Router)
	defer ts.Close()

	client := ts.Client()

	user := models.User{ChannelID: "channel_test_1", ChannelName: "Test Channel"}
	resp := requestJSON(t, client, http.MethodPost, ts.URL+"/api/v1/users", user)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create user expected 201, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	user.ChannelName = "Renamed Channel"
	resp = requestJSON(t, client, http.MethodPut, ts.URL+"/api/v1/users/"+user.ChannelID, user)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("update user expected 200, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	video := models.Video{VideoID: "video_test_1", Title: "Test Video", Category: "education"}
	resp = requestJSON(t, client, http.MethodPost, ts.URL+"/api/v1/videos", video)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create video expected 201, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	video.Title = "Updated Video"
	resp = requestJSON(t, client, http.MethodPut, ts.URL+"/api/v1/videos/"+video.VideoID, video)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("update video expected 200, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	comment := models.Comment{
		CommentID:      "comment_test_1",
		VideoID:        video.VideoID,
		ChannelID:      user.ChannelID,
		CommentText:    "Great video",
		Likes:          3,
		Replies:        1,
		SentimentLabel: "positive",
		CountryCode:    "US",
	}
	resp = requestJSON(t, client, http.MethodPost, ts.URL+"/api/v1/comments", comment)
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("create comment expected 201, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	comment.CommentText = "Updated comment"
	resp = requestJSON(t, client, http.MethodPut, ts.URL+"/api/v1/comments/"+comment.CommentID, comment)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("update comment expected 200, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	resp = requestJSON(t, client, http.MethodPost, ts.URL+"/api/v1/comments", models.Comment{
		CommentID:   "comment_orphan",
		VideoID:     "missing_video",
		ChannelID:   user.ChannelID,
		CommentText: "orphan",
	})
	if resp.StatusCode != http.StatusConflict {
		t.Fatalf("orphan comment expected 409, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	req, _ := http.NewRequest(http.MethodDelete, ts.URL+"/api/v1/comments/"+comment.CommentID, nil)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("delete comment request failed: %v", err)
	}
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("delete comment expected 204, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	req, _ = http.NewRequest(http.MethodDelete, ts.URL+"/api/v1/videos/"+video.VideoID, nil)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("delete video request failed: %v", err)
	}
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("delete video expected 204, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()

	req, _ = http.NewRequest(http.MethodDelete, ts.URL+"/api/v1/users/"+user.ChannelID, nil)
	resp, err = client.Do(req)
	if err != nil {
		t.Fatalf("delete user request failed: %v", err)
	}
	if resp.StatusCode != http.StatusNoContent {
		t.Fatalf("delete user expected 204, got %d", resp.StatusCode)
	}
	defer resp.Body.Close()
}

package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
)

// CreateVideo inserts a new video
func (db *Database) CreateVideo(ctx context.Context, video *models.Video) error {
	if video.ID == uuid.Nil {
		video.ID = uuid.New()
	}
	now := time.Now()
	if video.CreatedAt.IsZero() {
		video.CreatedAt = now
	}
	if video.UpdatedAt.IsZero() {
		video.UpdatedAt = now
	}

	query := `
		INSERT INTO videos (video_id, user_id, title, description, duration, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`

	_, err := db.Pool.Exec(ctx, query, 
		video.ID, video.UserID, video.Title, video.Description, 
		video.Duration, video.CreatedAt, video.UpdatedAt,
	)
	if err != nil {
		return fmt.Errorf("failed to insert video: %w", err)
	}

	return nil
}

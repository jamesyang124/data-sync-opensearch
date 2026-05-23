package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
)

// CreateVideo inserts a new video
func (db *Database) CreateVideo(ctx context.Context, video *models.Video) error {
	if video.VideoID == "" {
		video.VideoID = "video_" + uuid.NewString()
	}
	now := time.Now()
	if video.CreatedAt.IsZero() {
		video.CreatedAt = now
	}
	if video.UpdatedAt.IsZero() {
		video.UpdatedAt = now
	}

	query := `
		INSERT INTO videos (video_id, title, category, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING created_at, updated_at
	`

	err := db.Pool.QueryRow(ctx, query,
		video.VideoID, video.Title, video.Category, video.CreatedAt, video.UpdatedAt,
	).Scan(&video.CreatedAt, &video.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert video: %w", err)
	}

	return nil
}

// UpdateVideo updates an existing video
func (db *Database) UpdateVideo(ctx context.Context, video *models.Video) error {
	video.UpdatedAt = time.Now()

	query := `
		UPDATE videos
		SET title = $2, category = $3, updated_at = $4
		WHERE video_id = $1
		RETURNING created_at, updated_at
	`

	err := db.Pool.QueryRow(ctx, query, video.VideoID, video.Title, video.Category, video.UpdatedAt).
		Scan(&video.CreatedAt, &video.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("video not found: %s", video.VideoID)
		}
		return fmt.Errorf("failed to update video: %w", err)
	}

	return nil
}

// DeleteVideo deletes a video
func (db *Database) DeleteVideo(ctx context.Context, id string) error {
	query := `DELETE FROM videos WHERE video_id = $1`

	cmdTag, err := db.Pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete video: %w", err)
	}

	if cmdTag.RowsAffected() == 0 {
		return fmt.Errorf("video not found: %s", id)
	}

	return nil
}

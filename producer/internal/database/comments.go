package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
)

// CreateComment inserts a new comment.
func (db *Database) CreateComment(ctx context.Context, comment *models.Comment) error {
	if comment.CommentID == "" {
		comment.CommentID = "comment_" + uuid.NewString()
	}
	now := time.Now()
	if comment.CreatedAt.IsZero() {
		comment.CreatedAt = now
	}
	if comment.UpdatedAt.IsZero() {
		comment.UpdatedAt = now
	}

	query := `
		INSERT INTO comments (
			comment_id, video_id, channel_id, comment_text, likes, replies,
			published_at, sentiment_label, country_code, created_at, updated_at
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING created_at, updated_at
	`

	err := db.Pool.QueryRow(ctx, query,
		comment.CommentID, comment.VideoID, comment.ChannelID, comment.CommentText,
		comment.Likes, comment.Replies, comment.PublishedAt, comment.SentimentLabel,
		comment.CountryCode, comment.CreatedAt, comment.UpdatedAt,
	).Scan(&comment.CreatedAt, &comment.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert comment: %w", err)
	}

	return nil
}

// UpdateComment updates an existing comment.
func (db *Database) UpdateComment(ctx context.Context, comment *models.Comment) error {
	comment.UpdatedAt = time.Now()

	query := `
		UPDATE comments
		SET video_id = $2,
		    channel_id = $3,
		    comment_text = $4,
		    likes = $5,
		    replies = $6,
		    published_at = $7,
		    sentiment_label = $8,
		    country_code = $9,
		    updated_at = $10
		WHERE comment_id = $1
		RETURNING created_at, updated_at
	`

	err := db.Pool.QueryRow(ctx, query,
		comment.CommentID, comment.VideoID, comment.ChannelID, comment.CommentText,
		comment.Likes, comment.Replies, comment.PublishedAt, comment.SentimentLabel,
		comment.CountryCode, comment.UpdatedAt,
	).Scan(&comment.CreatedAt, &comment.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("comment not found: %s", comment.CommentID)
		}
		return fmt.Errorf("failed to update comment: %w", err)
	}

	return nil
}

// DeleteComment deletes a comment.
func (db *Database) DeleteComment(ctx context.Context, id string) error {
	query := `DELETE FROM comments WHERE comment_id = $1`

	cmdTag, err := db.Pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete comment: %w", err)
	}

	if cmdTag.RowsAffected() == 0 {
		return fmt.Errorf("comment not found: %s", id)
	}

	return nil
}

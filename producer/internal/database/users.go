package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
)

// CreateUser inserts a new user
func (db *Database) CreateUser(ctx context.Context, user *models.User) error {
	if user.ChannelID == "" {
		user.ChannelID = "channel_" + uuid.NewString()
	}
	now := time.Now()
	if user.CreatedAt.IsZero() {
		user.CreatedAt = now
	}
	if user.UpdatedAt.IsZero() {
		user.UpdatedAt = now
	}

	query := `
		INSERT INTO users (channel_id, channel_name, created_at, updated_at)
		VALUES ($1, $2, $3, $4)
		RETURNING created_at, updated_at
	`

	err := db.Pool.QueryRow(ctx, query, user.ChannelID, user.ChannelName, user.CreatedAt, user.UpdatedAt).
		Scan(&user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to insert user: %w", err)
	}

	return nil
}

// UpdateUser updates an existing user
func (db *Database) UpdateUser(ctx context.Context, user *models.User) error {
	user.UpdatedAt = time.Now()

	query := `
		UPDATE users 
		SET channel_name = $2, updated_at = $3
		WHERE channel_id = $1
		RETURNING created_at, updated_at
	`

	err := db.Pool.QueryRow(ctx, query, user.ChannelID, user.ChannelName, user.UpdatedAt).
		Scan(&user.CreatedAt, &user.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("user not found: %s", user.ChannelID)
		}
		return fmt.Errorf("failed to update user: %w", err)
	}

	return nil
}

// DeleteUser deletes a user
func (db *Database) DeleteUser(ctx context.Context, id string) error {
	query := `DELETE FROM users WHERE channel_id = $1`

	cmdTag, err := db.Pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	if cmdTag.RowsAffected() == 0 {
		return fmt.Errorf("user not found: %s", id)
	}

	return nil
}

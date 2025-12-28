package database

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
)

// CreateUser inserts a new user
func (db *Database) CreateUser(ctx context.Context, user *models.User) error {
	if user.ID == uuid.Nil {
		user.ID = uuid.New()
	}
	now := time.Now()
	if user.CreatedAt.IsZero() {
		user.CreatedAt = now
	}
	if user.UpdatedAt.IsZero() {
		user.UpdatedAt = now
	}

	query := `
		INSERT INTO users (user_id, username, email, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5)
	`

	_, err := db.Pool.Exec(ctx, query, user.ID, user.Username, user.Email, user.CreatedAt, user.UpdatedAt)
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
		SET username = $2, email = $3, updated_at = $4
		WHERE user_id = $1
	`

	cmdTag, err := db.Pool.Exec(ctx, query, user.ID, user.Username, user.Email, user.UpdatedAt)
	if err != nil {
		return fmt.Errorf("failed to update user: %w", err)
	}

	if cmdTag.RowsAffected() == 0 {
		return fmt.Errorf("user not found: %s", user.ID)
	}

	return nil
}

// DeleteUser deletes a user
func (db *Database) DeleteUser(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM users WHERE user_id = $1`

	cmdTag, err := db.Pool.Exec(ctx, query, id)
	if err != nil {
		return fmt.Errorf("failed to delete user: %w", err)
	}

	if cmdTag.RowsAffected() == 0 {
		return fmt.Errorf("user not found: %s", id)
	}

	return nil
}

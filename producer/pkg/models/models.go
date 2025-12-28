package models

import (
	"time"

	"github.com/google/uuid"
)

type User struct {
	ID        uuid.UUID `db:"user_id" json:"user_id"`
	Username  string    `db:"username" json:"username"`
	Email     string    `db:"email" json:"email"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

type Video struct {
	ID          uuid.UUID `db:"video_id" json:"video_id"`
	UserID      uuid.UUID `db:"user_id" json:"user_id"`
	Title       string    `db:"title" json:"title"`
	Description string    `db:"description" json:"description"`
	Duration    int       `db:"duration" json:"duration"`
	CreatedAt   time.Time `db:"created_at" json:"created_at"`
	UpdatedAt   time.Time `db:"updated_at" json:"updated_at"`
}

type Comment struct {
	ID        uuid.UUID `db:"comment_id" json:"comment_id"`
	VideoID   uuid.UUID `db:"video_id" json:"video_id"`
	UserID    uuid.UUID `db:"user_id" json:"user_id"`
	Text      string    `db:"comment_text" json:"comment_text"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

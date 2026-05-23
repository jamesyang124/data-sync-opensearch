package models

import (
	"time"
)

type User struct {
	ChannelID   string    `db:"channel_id" json:"channel_id"`
	ChannelName string    `db:"channel_name" json:"channel_name"`
	CreatedAt   time.Time `db:"created_at" json:"created_at"`
	UpdatedAt   time.Time `db:"updated_at" json:"updated_at"`
}

type Video struct {
	VideoID   string    `db:"video_id" json:"video_id"`
	Title     string    `db:"title" json:"title"`
	Category  string    `db:"category" json:"category"`
	CreatedAt time.Time `db:"created_at" json:"created_at"`
	UpdatedAt time.Time `db:"updated_at" json:"updated_at"`
}

type Comment struct {
	CommentID      string     `db:"comment_id" json:"comment_id"`
	VideoID        string     `db:"video_id" json:"video_id"`
	ChannelID      string     `db:"channel_id" json:"channel_id"`
	CommentText    string     `db:"comment_text" json:"comment_text"`
	Likes          int        `db:"likes" json:"likes"`
	Replies        int        `db:"replies" json:"replies"`
	PublishedAt    *time.Time `db:"published_at" json:"published_at,omitempty"`
	SentimentLabel string     `db:"sentiment_label" json:"sentiment_label"`
	CountryCode    string     `db:"country_code" json:"country_code"`
	CreatedAt      time.Time  `db:"created_at" json:"created_at"`
	UpdatedAt      time.Time  `db:"updated_at" json:"updated_at"`
}

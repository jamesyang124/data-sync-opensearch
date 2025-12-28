package transform

import (
	"fmt"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// VideoDocument represents a video document for OpenSearch
type VideoDocument struct {
	VideoID          string  `json:"video_id"`
	UserID           string  `json:"user_id"`
	Title            string  `json:"title"`
	Description      string  `json:"description"`
	DurationSeconds  int64   `json:"duration_seconds"`
	ViewCount        int64   `json:"view_count"`
	LikeCount        int64   `json:"like_count"`
	CreatedAt        string  `json:"created_at"`
	UpdatedAt        string  `json:"updated_at"`
}

// TransformVideo transforms a CDC event to a video document
func (t *Transformer) TransformVideo(event *models.CDCEvent) (docID string, doc *VideoDocument, err error) {
	var data map[string]interface{}

	// For deletes, use before payload to get document ID
	if event.Payload.Op == "d" {
		data = event.Payload.Before
		docID = models.GetStringField(data, "video_id")
		return docID, nil, nil
	}

	// For inserts and updates, use after payload
	data = event.Payload.After
	if data == nil {
		return "", nil, fmt.Errorf("after payload is nil for operation: %s", event.Payload.Op)
	}

	docID = models.GetStringField(data, "video_id")
	if docID == "" {
		return "", nil, fmt.Errorf("video_id is missing or empty")
	}

	doc = &VideoDocument{
		VideoID:         docID,
		UserID:          models.GetStringField(data, "user_id"),
		Title:           models.GetStringField(data, "title"),
		Description:     models.GetStringField(data, "description"),
		DurationSeconds: models.GetInt64Field(data, "duration_seconds"),
		ViewCount:       models.GetInt64Field(data, "view_count"),
		LikeCount:       models.GetInt64Field(data, "like_count"),
		CreatedAt:       models.GetStringField(data, "created_at"),
		UpdatedAt:       models.GetStringField(data, "updated_at"),
	}

	return docID, doc, nil
}

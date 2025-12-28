package transform

import (
	"fmt"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// CommentDocument represents a comment document for OpenSearch
type CommentDocument struct {
	CommentID       string `json:"comment_id"`
	VideoID         string `json:"video_id"`
	UserID          string `json:"user_id"`
	CommentText     string `json:"comment_text"`
	ParentCommentID string `json:"parent_comment_id,omitempty"`
	LikeCount       int64  `json:"like_count"`
	CreatedAt       string `json:"created_at"`
	UpdatedAt       string `json:"updated_at"`
}

// TransformComment transforms a CDC event to a comment document
func (t *Transformer) TransformComment(event *models.CDCEvent) (docID string, doc *CommentDocument, err error) {
	var data map[string]interface{}

	// For deletes, use before payload to get document ID
	if event.Payload.Op == "d" {
		data = event.Payload.Before
		docID = models.GetStringField(data, "comment_id")
		return docID, nil, nil
	}

	// For inserts and updates, use after payload
	data = event.Payload.After
	if data == nil {
		return "", nil, fmt.Errorf("after payload is nil for operation: %s", event.Payload.Op)
	}

	docID = models.GetStringField(data, "comment_id")
	if docID == "" {
		return "", nil, fmt.Errorf("comment_id is missing or empty")
	}

	doc = &CommentDocument{
		CommentID:       docID,
		VideoID:         models.GetStringField(data, "video_id"),
		UserID:          models.GetStringField(data, "user_id"),
		CommentText:     models.GetStringField(data, "comment_text"),
		ParentCommentID: models.GetStringField(data, "parent_comment_id"),
		LikeCount:       models.GetInt64Field(data, "like_count"),
		CreatedAt:       models.GetStringField(data, "created_at"),
		UpdatedAt:       models.GetStringField(data, "updated_at"),
	}

	return docID, doc, nil
}

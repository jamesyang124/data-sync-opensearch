package transform

import (
	"fmt"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// CommentDocument represents a comment document for OpenSearch
type CommentDocument struct {
	CommentID      string  `json:"comment_id"`
	VideoID        string  `json:"video_id"`
	ChannelID      string  `json:"channel_id"`
	CommentText    string  `json:"comment_text"`
	Likes          int64   `json:"likes"`
	Replies        int64   `json:"replies"`
	PublishedAt    *string `json:"published_at,omitempty"`
	SentimentLabel string  `json:"sentiment_label"`
	CountryCode    string  `json:"country_code"`
	SourceTsMs     int64   `json:"source_ts_ms"`
	CreatedAt      string  `json:"created_at"`
	UpdatedAt      string  `json:"updated_at"`
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
		CommentID:      docID,
		VideoID:        models.GetStringField(data, "video_id"),
		ChannelID:      models.GetStringField(data, "channel_id"),
		CommentText:    models.GetStringField(data, "comment_text"),
		Likes:          models.GetInt64Field(data, "likes"),
		Replies:        models.GetInt64Field(data, "replies"),
		SentimentLabel: models.GetStringField(data, "sentiment_label"),
		CountryCode:    models.GetStringField(data, "country_code"),
		SourceTsMs:     event.Payload.Source.TsMs,
		CreatedAt:      models.GetTimestampField(data, "created_at"),
		UpdatedAt:      models.GetTimestampField(data, "updated_at"),
	}

	if publishedAt := models.GetTimestampField(data, "published_at"); publishedAt != "" {
		doc.PublishedAt = &publishedAt
	}

	return docID, doc, nil
}

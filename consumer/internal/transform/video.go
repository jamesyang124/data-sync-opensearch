package transform

import (
	"fmt"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// VideoDocument represents a video document for OpenSearch
type VideoDocument struct {
	VideoID    string `json:"video_id"`
	Title      string `json:"title"`
	Category   string `json:"category"`
	SourceTsMs int64  `json:"source_ts_ms"`
	CreatedAt  string `json:"created_at"`
	UpdatedAt  string `json:"updated_at"`
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
		VideoID:    docID,
		Title:      models.GetStringField(data, "title"),
		Category:   models.GetStringField(data, "category"),
		SourceTsMs: event.Payload.Source.TsMs,
		CreatedAt:  models.GetTimestampField(data, "created_at"),
		UpdatedAt:  models.GetTimestampField(data, "updated_at"),
	}

	return docID, doc, nil
}

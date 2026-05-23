package transform

import (
	"fmt"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// UserDocument represents a user document for OpenSearch
type UserDocument struct {
	ChannelID   string `json:"channel_id"`
	ChannelName string `json:"channel_name"`
	SourceTsMs  int64  `json:"source_ts_ms"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

// TransformUser transforms a CDC event to a user document
func (t *Transformer) TransformUser(event *models.CDCEvent) (docID string, doc *UserDocument, err error) {
	var data map[string]interface{}

	// For deletes, use before payload to get document ID
	if event.Payload.Op == "d" {
		data = event.Payload.Before
		docID = models.GetStringField(data, "channel_id")
		return docID, nil, nil
	}

	// For inserts and updates, use after payload
	data = event.Payload.After
	if data == nil {
		return "", nil, fmt.Errorf("after payload is nil for operation: %s", event.Payload.Op)
	}

	docID = models.GetStringField(data, "channel_id")
	if docID == "" {
		return "", nil, fmt.Errorf("channel_id is missing or empty")
	}

	doc = &UserDocument{
		ChannelID:   docID,
		ChannelName: models.GetStringField(data, "channel_name"),
		SourceTsMs:  event.Payload.Source.TsMs,
		CreatedAt:   models.GetTimestampField(data, "created_at"),
		UpdatedAt:   models.GetTimestampField(data, "updated_at"),
	}

	return docID, doc, nil
}

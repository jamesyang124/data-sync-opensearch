package transform

import (
	"fmt"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// UserDocument represents a user document for OpenSearch
type UserDocument struct {
	ChannelID       string `json:"channel_id"`
	Username        string `json:"username"`
	Email           string `json:"email"`
	SubscriberCount int64  `json:"subscriber_count"`
	CreatedAt       string `json:"created_at"`
	UpdatedAt       string `json:"updated_at"`
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
		ChannelID:       docID,
		Username:        models.GetStringField(data, "username"),
		Email:           models.GetStringField(data, "email"),
		SubscriberCount: models.GetInt64Field(data, "subscriber_count"),
		CreatedAt:       models.GetStringField(data, "created_at"),
		UpdatedAt:       models.GetStringField(data, "updated_at"),
	}

	return docID, doc, nil
}

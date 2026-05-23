package unit

import (
	"encoding/json"
	"testing"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

func TestTransformCommentCDCEvent(t *testing.T) {
	tests := []struct {
		name        string
		cdcPayload  string
		expectError bool
		expectedID  string
	}{
		{
			name: "INSERT comment event",
			cdcPayload: `{
				"payload": {
					"op": "c",
					"after": {
						"comment_id": "comment_999",
						"video_id": "video_123",
						"channel_id": "channel_456",
						"comment_text": "Great video!",
						"likes": 0,
						"replies": 0,
						"sentiment_label": "positive",
						"country_code": "US",
						"created_at": "2024-06-20T10:00:00Z",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"ts_ms": 1710000000000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "comments"
					}
				}
			}`,
			expectError: false,
			expectedID:  "comment_999",
		},
		{
			name: "UPDATE comment event",
			cdcPayload: `{
				"payload": {
					"op": "u",
					"before": {
						"comment_id": "comment_999",
						"likes": 5,
				"replies": 0,
				"sentiment_label": "positive",
				"country_code": "US",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"after": {
						"comment_id": "comment_999",
						"video_id": "video_123",
						"channel_id": "channel_456",
						"comment_text": "Great video! Updated",
						"likes": 10,
						"replies": 0,
						"sentiment_label": "positive",
						"country_code": "US",
						"created_at": "2024-06-20T10:00:00Z",
						"updated_at": "2024-06-20T10:30:00Z"
					},
					"ts_ms": 1710001800000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "comments"
					}
				}
			}`,
			expectError: false,
			expectedID:  "comment_999",
		},
		{
			name: "DELETE comment event",
			cdcPayload: `{
				"payload": {
					"op": "d",
					"before": {
						"comment_id": "comment_999",
						"video_id": "video_123",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"ts_ms": 1710003600000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "comments"
					}
				}
			}`,
			expectError: false,
			expectedID:  "comment_999",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var event models.CDCEvent
			if err := json.Unmarshal([]byte(tt.cdcPayload), &event); err != nil {
				t.Fatalf("Failed to unmarshal CDC event: %v", err)
			}

			// Extract document ID
			var docID string
			if event.Payload.Op == "d" {
				docID = models.GetStringField(event.Payload.Before, "comment_id")
			} else {
				docID = models.GetStringField(event.Payload.After, "comment_id")
			}

			if docID != tt.expectedID {
				t.Errorf("Expected document ID %s, got %s", tt.expectedID, docID)
			}
		})
	}
}

func TestCommentDocumentMapping(t *testing.T) {
	cdcPayload := `{
		"payload": {
			"op": "c",
			"after": {
				"comment_id": "comment_999",
				"video_id": "video_123",
				"channel_id": "channel_456",
				"comment_text": "Great video!",
				"likes": 15,
				"replies": 0,
				"sentiment_label": "positive",
				"country_code": "US",
				"created_at": "2024-06-20T10:00:00Z",
				"updated_at": "2024-06-20T10:00:00Z"
			},
			"ts_ms": 1710000000000
		}
	}`

	var event models.CDCEvent
	if err := json.Unmarshal([]byte(cdcPayload), &event); err != nil {
		t.Fatalf("Failed to unmarshal CDC event: %v", err)
	}

	// Verify field extraction
	commentID := models.GetStringField(event.Payload.After, "comment_id")
	if commentID != "comment_999" {
		t.Errorf("Expected comment_id 'comment_999', got '%s'", commentID)
	}

	commentText := models.GetStringField(event.Payload.After, "comment_text")
	if commentText != "Great video!" {
		t.Errorf("Expected comment_text 'Great video!', got '%s'", commentText)
	}

	likes := models.GetInt64Field(event.Payload.After, "likes")
	if likes != 15 {
		t.Errorf("Expected likes 15, got %d", likes)
	}
}

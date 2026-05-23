package unit

import (
	"encoding/json"
	"testing"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

func TestTransformUserCDCEvent(t *testing.T) {
	tests := []struct {
		name        string
		cdcPayload  string
		expectError bool
		expectedID  string
	}{
		{
			name: "INSERT user event",
			cdcPayload: `{
				"payload": {
					"op": "c",
					"after": {
						"channel_id": "channel_789",
						"channel_name": "Test Channel",
						"created_at": "2024-06-20T10:00:00Z",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"ts_ms": 1710000000000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "users"
					}
				}
			}`,
			expectError: false,
			expectedID:  "channel_789",
		},
		{
			name: "UPDATE user event",
			cdcPayload: `{
				"payload": {
					"op": "u",
					"before": {
						"channel_id": "channel_789",
						"subscriber_count": 100,
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"after": {
						"channel_id": "channel_789",
						"channel_name": "Test Channel",
						"created_at": "2024-06-20T10:00:00Z",
						"updated_at": "2024-06-20T10:30:00Z"
					},
					"ts_ms": 1710001800000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "users"
					}
				}
			}`,
			expectError: false,
			expectedID:  "channel_789",
		},
		{
			name: "DELETE user event",
			cdcPayload: `{
				"payload": {
					"op": "d",
					"before": {
						"channel_id": "channel_789",
						"channel_name": "Test Channel",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"ts_ms": 1710003600000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "users"
					}
				}
			}`,
			expectError: false,
			expectedID:  "channel_789",
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
				docID = models.GetStringField(event.Payload.Before, "channel_id")
			} else {
				docID = models.GetStringField(event.Payload.After, "channel_id")
			}

			if docID != tt.expectedID {
				t.Errorf("Expected document ID %s, got %s", tt.expectedID, docID)
			}
		})
	}
}

func TestUserDocumentMapping(t *testing.T) {
	cdcPayload := `{
		"payload": {
			"op": "c",
			"after": {
				"channel_id": "channel_789",
				"channel_name": "Test Channel",
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
	channelID := models.GetStringField(event.Payload.After, "channel_id")
	if channelID != "channel_789" {
		t.Errorf("Expected channel_id 'channel_789', got '%s'", channelID)
	}

	channelName := models.GetStringField(event.Payload.After, "channel_name")
	if channelName != "Test Channel" {
		t.Errorf("Expected channel_name 'Test Channel', got '%s'", channelName)
	}
}

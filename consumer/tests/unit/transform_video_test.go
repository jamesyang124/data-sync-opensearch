package unit

import (
	"encoding/json"
	"testing"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

func TestTransformVideoCDCEvent(t *testing.T) {
	tests := []struct {
		name        string
		cdcPayload  string
		expectError bool
		expectedID  string
	}{
		{
			name: "INSERT video event",
			cdcPayload: `{
				"payload": {
					"op": "c",
					"after": {
						"video_id": "video_123",
						"user_id": "user_456",
						"title": "Sample Video",
						"description": "Test description",
						"duration_seconds": 120,
						"view_count": 0,
						"like_count": 0,
						"created_at": "2024-06-20T10:00:00Z",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"ts_ms": 1710000000000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "videos"
					}
				}
			}`,
			expectError: false,
			expectedID:  "video_123",
		},
		{
			name: "UPDATE video event",
			cdcPayload: `{
				"payload": {
					"op": "u",
					"before": {
						"video_id": "video_123",
						"view_count": 100,
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"after": {
						"video_id": "video_123",
						"user_id": "user_456",
						"title": "Updated Video Title",
						"description": "Updated description",
						"duration_seconds": 120,
						"view_count": 150,
						"like_count": 10,
						"created_at": "2024-06-20T10:00:00Z",
						"updated_at": "2024-06-20T10:30:00Z"
					},
					"ts_ms": 1710001800000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "videos"
					}
				}
			}`,
			expectError: false,
			expectedID:  "video_123",
		},
		{
			name: "DELETE video event",
			cdcPayload: `{
				"payload": {
					"op": "d",
					"before": {
						"video_id": "video_123",
						"user_id": "user_456",
						"title": "Deleted Video",
						"updated_at": "2024-06-20T10:00:00Z"
					},
					"ts_ms": 1710003600000,
					"source": {
						"db": "app",
						"schema": "public",
						"table": "videos"
					}
				}
			}`,
			expectError: false,
			expectedID:  "video_123",
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
				docID = models.GetStringField(event.Payload.Before, "video_id")
			} else {
				docID = models.GetStringField(event.Payload.After, "video_id")
			}

			if docID != tt.expectedID {
				t.Errorf("Expected document ID %s, got %s", tt.expectedID, docID)
			}

			// Verify operation type
			validOps := map[string]bool{"c": true, "u": true, "d": true, "r": true}
			if !validOps[event.Payload.Op] {
				t.Errorf("Invalid operation type: %s", event.Payload.Op)
			}
		})
	}
}

func TestVideoDocumentMapping(t *testing.T) {
	cdcPayload := `{
		"payload": {
			"op": "c",
			"after": {
				"video_id": "video_123",
				"user_id": "user_456",
				"title": "Sample Video",
				"description": "Test description",
				"duration_seconds": 120,
				"view_count": 100,
				"like_count": 10,
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
	videoID := models.GetStringField(event.Payload.After, "video_id")
	if videoID != "video_123" {
		t.Errorf("Expected video_id 'video_123', got '%s'", videoID)
	}

	title := models.GetStringField(event.Payload.After, "title")
	if title != "Sample Video" {
		t.Errorf("Expected title 'Sample Video', got '%s'", title)
	}

	viewCount := models.GetInt64Field(event.Payload.After, "view_count")
	if viewCount != 100 {
		t.Errorf("Expected view_count 100, got %d", viewCount)
	}
}

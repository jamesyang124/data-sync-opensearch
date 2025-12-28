package transform

import (
	"fmt"
	"strings"

	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
)

// Transformer handles CDC event transformation
type Transformer struct {
	// Add any shared dependencies here
}

// NewTransformer creates a new transformer
func NewTransformer() *Transformer {
	return &Transformer{}
}

// Transform routes CDC events to appropriate transformer based on topic
func (t *Transformer) Transform(topic string, event *models.CDCEvent) (index string, docID string, doc interface{}, err error) {
	// Extract table name from topic (dbserver.public.videos -> videos)
	parts := strings.Split(topic, ".")
	if len(parts) < 3 {
		return "", "", nil, fmt.Errorf("invalid topic format: %s", topic)
	}
	table := parts[len(parts)-1]

	switch table {
	case "videos":
		docID, videoDoc, err := t.TransformVideo(event)
		return "videos_index", docID, videoDoc, err

	case "users":
		docID, userDoc, err := t.TransformUser(event)
		return "users_index", docID, userDoc, err

	case "comments":
		docID, commentDoc, err := t.TransformComment(event)
		return "comments_index", docID, commentDoc, err

	default:
		return "", "", nil, fmt.Errorf("unsupported table: %s", table)
	}
}

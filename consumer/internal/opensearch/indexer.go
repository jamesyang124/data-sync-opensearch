package opensearch

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"time"

	opensearch "github.com/opensearch-project/opensearch-go/v2"
	"github.com/opensearch-project/opensearch-go/v2/opensearchapi"
	"go.uber.org/zap"
)

// Indexer handles OpenSearch indexing operations
type Indexer struct {
	client *opensearch.Client
	logger *zap.Logger
}

// NewIndexer creates a new indexer
func NewIndexer(client *Client) *Indexer {
	return &Indexer{
		client: client.GetClient(),
		logger: client.logger,
	}
}

// Index performs idempotent upsert with optimistic locking
func (i *Indexer) Index(index, docID string, document interface{}) error {
	// Convert document to map for manipulation
	docMap, err := toMap(document)
	if err != nil {
		return fmt.Errorf("failed to convert document to map: %w", err)
	}

	incomingSourceTs := int64(0)
	if v, ok := docMap["source_ts_ms"]; ok {
		switch ts := v.(type) {
		case float64:
			incomingSourceTs = int64(ts)
		case int64:
			incomingSourceTs = ts
		case int:
			incomingSourceTs = int64(ts)
		}
	}

	updatedAt, ok := docMap["updated_at"].(string)
	if !ok || updatedAt == "" {
		// If no updated_at field, proceed without optimistic locking.
		return i.indexDocument(index, docID, docMap)
	}

	// Check existing document for optimistic locking
	existingDoc, err := i.getDocument(index, docID)
	if err != nil && !strings.Contains(err.Error(), "not found") {
		return fmt.Errorf("failed to get existing document: %w", err)
	}

	// If document exists, check if update is stale
	if existingDoc != nil {
		if isStaleDocument(docMap, existingDoc) {
			i.logger.Info("Ignoring stale update",
				zap.String("index", index),
				zap.String("doc_id", docID),
				zap.Int64("incoming_source_ts_ms", incomingSourceTs),
				zap.String("incoming_updated_at", updatedAt),
			)
			return nil
		}
	}

	// Proceed with indexing
	return i.indexDocument(index, docID, docMap)
}

// indexDocument performs the actual indexing operation
func (i *Indexer) indexDocument(index, docID string, document map[string]interface{}) error {
	data, err := json.Marshal(document)
	if err != nil {
		return fmt.Errorf("failed to marshal document: %w", err)
	}

	req := opensearchapi.IndexRequest{
		Index:      index,
		DocumentID: docID,
		Body:       bytes.NewReader(data),
		Refresh:    "false",
	}

	res, err := req.Do(context.Background(), i.client)
	if err != nil {
		return fmt.Errorf("failed to execute index request: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() {
		body, _ := io.ReadAll(res.Body)
		return fmt.Errorf("index request failed: %s - %s", res.Status(), string(body))
	}

	return nil
}

// Delete removes a document from the index when the delete event is not stale.
func (i *Indexer) Delete(index, docID string, sourceTsMs int64) error {
	existingDoc, err := i.getDocument(index, docID)
	if err != nil {
		if strings.Contains(err.Error(), "not found") {
			return nil
		}
		return fmt.Errorf("failed to get existing document before delete: %w", err)
	}

	if isStaleDelete(sourceTsMs, existingDoc) {
		i.logger.Info("Ignoring stale delete",
			zap.String("index", index),
			zap.String("doc_id", docID),
			zap.Int64("delete_source_ts_ms", sourceTsMs),
			zap.Int64("existing_source_ts_ms", sourceTimestamp(existingDoc)),
		)
		return nil
	}

	req := opensearchapi.DeleteRequest{
		Index:      index,
		DocumentID: docID,
		Refresh:    "false",
	}

	res, err := req.Do(context.Background(), i.client)
	if err != nil {
		return fmt.Errorf("failed to execute delete request: %w", err)
	}
	defer res.Body.Close()

	if res.IsError() && res.StatusCode != 404 {
		body, _ := io.ReadAll(res.Body)
		return fmt.Errorf("delete request failed: %s - %s", res.Status(), string(body))
	}

	return nil
}

// getDocument retrieves an existing document
func (i *Indexer) getDocument(index, docID string) (map[string]interface{}, error) {
	req := opensearchapi.GetRequest{
		Index:      index,
		DocumentID: docID,
	}

	res, err := req.Do(context.Background(), i.client)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	if res.StatusCode == 404 {
		return nil, fmt.Errorf("document not found")
	}

	if res.IsError() {
		return nil, fmt.Errorf("get request failed: %s", res.Status())
	}

	var result struct {
		Source map[string]interface{} `json:"_source"`
	}

	if err := json.NewDecoder(res.Body).Decode(&result); err != nil {
		return nil, err
	}

	return result.Source, nil
}

// isStaleUpdate compares timestamps to determine if update is stale
func isStaleUpdate(incomingUpdatedAt, existingUpdatedAt string) bool {
	incomingTime, err1 := time.Parse(time.RFC3339, incomingUpdatedAt)
	existingTime, err2 := time.Parse(time.RFC3339, existingUpdatedAt)

	if err1 != nil || err2 != nil {
		// If parsing fails, allow the update
		return false
	}

	// Update is stale if incoming timestamp is older than existing
	return incomingTime.Before(existingTime)
}

func isStaleDocument(incomingDoc, existingDoc map[string]interface{}) bool {
	incomingSourceTs := sourceTimestamp(incomingDoc)
	existingSourceTs := sourceTimestamp(existingDoc)
	if incomingSourceTs > 0 && existingSourceTs > 0 {
		return incomingSourceTs < existingSourceTs
	}

	incomingUpdatedAt, incomingOK := incomingDoc["updated_at"].(string)
	existingUpdatedAt, existingOK := existingDoc["updated_at"].(string)
	if incomingOK && existingOK && incomingUpdatedAt != "" && existingUpdatedAt != "" {
		return isStaleUpdate(incomingUpdatedAt, existingUpdatedAt)
	}

	return false
}

func isStaleDelete(deleteSourceTs int64, existingDoc map[string]interface{}) bool {
	existingSourceTs := sourceTimestamp(existingDoc)
	return deleteSourceTs > 0 && existingSourceTs > 0 && deleteSourceTs < existingSourceTs
}

func sourceTimestamp(doc map[string]interface{}) int64 {
	if v, ok := doc["source_ts_ms"]; ok {
		switch ts := v.(type) {
		case float64:
			return int64(ts)
		case int64:
			return ts
		case int:
			return int64(ts)
		}
	}
	return 0
}

// toMap converts any type to map[string]interface{}
func toMap(v interface{}) (map[string]interface{}, error) {
	data, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}

	var result map[string]interface{}
	if err := json.Unmarshal(data, &result); err != nil {
		return nil, err
	}

	return result, nil
}

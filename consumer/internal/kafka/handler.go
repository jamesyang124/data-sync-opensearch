package kafka

import (
	"encoding/json"
	"fmt"

	"github.com/IBM/sarama"
	"github.com/murcurial/data-sync-opensearch/consumer/internal/transform"
	"github.com/murcurial/data-sync-opensearch/consumer/pkg/models"
	"go.uber.org/zap"
)

// MessageHandler implements sarama.ConsumerGroupHandler
type MessageHandler struct {
	logger      *zap.Logger
	transformer *transform.Transformer
	indexer     Indexer
	metrics     MetricsCollector
}

// Indexer interface for OpenSearch indexing operations
type Indexer interface {
	Index(index, docID string, document interface{}) error
	Delete(index, docID string) error
}

// MetricsCollector interface for tracking metrics
type MetricsCollector interface {
	IncrementProcessed()
	IncrementErrors()
}

// NewMessageHandler creates a new message handler
func NewMessageHandler(logger *zap.Logger, transformer *transform.Transformer, indexer Indexer, metrics MetricsCollector) *MessageHandler {
	return &MessageHandler{
		logger:      logger,
		transformer: transformer,
		indexer:     indexer,
		metrics:     metrics,
	}
}

// Setup is called at the beginning of a new session
func (h *MessageHandler) Setup(sarama.ConsumerGroupSession) error {
	h.logger.Info("Consumer group session started")
	return nil
}

// Cleanup is called at the end of a session
func (h *MessageHandler) Cleanup(sarama.ConsumerGroupSession) error {
	h.logger.Info("Consumer group session ended")
	return nil
}

// ConsumeClaim processes messages from a topic partition
func (h *MessageHandler) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for message := range claim.Messages() {
		if err := h.processMessage(message); err != nil {
			h.logger.Error("Failed to process message",
				zap.String("topic", message.Topic),
				zap.Int32("partition", message.Partition),
				zap.Int64("offset", message.Offset),
				zap.Error(err),
			)
			// Increment error counter
			if h.metrics != nil {
				h.metrics.IncrementErrors()
			}
			// Continue processing other messages
			continue
		}

		// Increment success counter
		if h.metrics != nil {
			h.metrics.IncrementProcessed()
		}

		// Mark message as processed
		session.MarkMessage(message, "")
	}

	return nil
}

// processMessage handles a single Kafka message
func (h *MessageHandler) processMessage(message *sarama.ConsumerMessage) error {
	// Parse CDC event
	var event models.CDCEvent
	if err := json.Unmarshal(message.Value, &event); err != nil {
		return fmt.Errorf("failed to unmarshal CDC event: %w", err)
	}

	correlationID := fmt.Sprintf("%s-%d-%d", message.Topic, message.Partition, message.Offset)
	logger := h.logger.With(
		zap.String("correlation_id", correlationID),
		zap.String("topic", message.Topic),
		zap.String("operation", event.Payload.Op),
	)

	// Route message based on topic
	index, docID, doc, err := h.transformer.Transform(message.Topic, &event)
	if err != nil {
		return fmt.Errorf("failed to transform event: %w", err)
	}

	// Handle different operations
	switch event.Payload.Op {
	case "c", "r", "u": // create, read (snapshot), update
		if err := h.indexer.Index(index, docID, doc); err != nil {
			return fmt.Errorf("failed to index document: %w", err)
		}
		logger.Info("Document indexed",
			zap.String("index", index),
			zap.String("doc_id", docID),
		)

	case "d": // delete
		if err := h.indexer.Delete(index, docID); err != nil {
			return fmt.Errorf("failed to delete document: %w", err)
		}
		logger.Info("Document deleted",
			zap.String("index", index),
			zap.String("doc_id", docID),
		)

	default:
		return fmt.Errorf("unknown operation: %s", event.Payload.Op)
	}

	return nil
}

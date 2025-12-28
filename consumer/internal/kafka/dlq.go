package kafka

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/IBM/sarama"
	"go.uber.org/zap"
)

// DLQProducer handles publishing failed events to dead letter queue
type DLQProducer struct {
	producer sarama.SyncProducer
	logger   *zap.Logger
}

// DLQMessage represents a message in the dead letter queue
type DLQMessage struct {
	OriginalTopic     string                 `json:"original_topic"`
	OriginalPartition int32                  `json:"original_partition"`
	OriginalOffset    int64                  `json:"original_offset"`
	OriginalKey       string                 `json:"original_key,omitempty"`
	OriginalValue     json.RawMessage        `json:"original_value"`
	ErrorContext      *ErrorContext          `json:"error_context"`
	Timestamp         time.Time              `json:"timestamp"`
}

// ErrorContext contains error details for debugging
type ErrorContext struct {
	ErrorMessage string            `json:"error_message"`
	ErrorType    string            `json:"error_type"`
	AttemptCount int               `json:"attempt_count"`
	LastAttempt  time.Time         `json:"last_attempt"`
	Metadata     map[string]string `json:"metadata,omitempty"`
}

// NewDLQProducer creates a new dead letter queue producer
func NewDLQProducer(brokers []string, logger *zap.Logger) (*DLQProducer, error) {
	config := sarama.NewConfig()
	config.Producer.RequiredAcks = sarama.WaitForAll
	config.Producer.Retry.Max = 3
	config.Producer.Return.Successes = true

	producer, err := sarama.NewSyncProducer(brokers, config)
	if err != nil {
		return nil, fmt.Errorf("failed to create DLQ producer: %w", err)
	}

	return &DLQProducer{
		producer: producer,
		logger:   logger,
	}, nil
}

// PublishToDLQ publishes a failed message to the dead letter queue
func (d *DLQProducer) PublishToDLQ(
	originalTopic string,
	originalPartition int32,
	originalOffset int64,
	originalKey []byte,
	originalValue []byte,
	errorMsg string,
	attemptCount int,
) error {
	dlqTopic := fmt.Sprintf("%s.dlq", originalTopic)

	dlqMessage := DLQMessage{
		OriginalTopic:     originalTopic,
		OriginalPartition: originalPartition,
		OriginalOffset:    originalOffset,
		OriginalKey:       string(originalKey),
		OriginalValue:     originalValue,
		ErrorContext: &ErrorContext{
			ErrorMessage: errorMsg,
			ErrorType:    "processing_error",
			AttemptCount: attemptCount,
			LastAttempt:  time.Now(),
			Metadata: map[string]string{
				"consumer_group": "cdc-consumer-group",
			},
		},
		Timestamp: time.Now(),
	}

	messageBytes, err := json.Marshal(dlqMessage)
	if err != nil {
		return fmt.Errorf("failed to marshal DLQ message: %w", err)
	}

	msg := &sarama.ProducerMessage{
		Topic: dlqTopic,
		Value: sarama.ByteEncoder(messageBytes),
		Key:   sarama.ByteEncoder(originalKey),
	}

	partition, offset, err := d.producer.SendMessage(msg)
	if err != nil {
		return fmt.Errorf("failed to send message to DLQ: %w", err)
	}

	d.logger.Info("Message sent to DLQ",
		zap.String("dlq_topic", dlqTopic),
		zap.Int32("partition", partition),
		zap.Int64("offset", offset),
		zap.String("original_topic", originalTopic),
		zap.Int32("original_partition", originalPartition),
		zap.Int64("original_offset", originalOffset),
		zap.String("error", errorMsg),
	)

	return nil
}

// Close closes the DLQ producer
func (d *DLQProducer) Close() error {
	return d.producer.Close()
}

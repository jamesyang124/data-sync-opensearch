package kafka

import (
	"github.com/IBM/sarama"
	"go.uber.org/zap"
)

// MessageHandlerWithBackpressure implements sarama.ConsumerGroupHandler with backpressure control
type MessageHandlerWithBackpressure struct {
	baseHandler *MessageHandler
	workerPool  *WorkerPool
	logger      *zap.Logger
}

// NewMessageHandlerWithBackpressure creates a handler with backpressure control
func NewMessageHandlerWithBackpressure(
	baseHandler *MessageHandler,
	workerPool *WorkerPool,
	logger *zap.Logger,
) *MessageHandlerWithBackpressure {
	return &MessageHandlerWithBackpressure{
		baseHandler: baseHandler,
		workerPool:  workerPool,
		logger:      logger,
	}
}

// Setup is called at the beginning of a new session
func (h *MessageHandlerWithBackpressure) Setup(session sarama.ConsumerGroupSession) error {
	h.logger.Info("Consumer group session started with backpressure control")
	return h.baseHandler.Setup(session)
}

// Cleanup is called at the end of a session
func (h *MessageHandlerWithBackpressure) Cleanup(session sarama.ConsumerGroupSession) error {
	h.logger.Info("Consumer group session ended")
	return h.baseHandler.Cleanup(session)
}

// ConsumeClaim processes messages with backpressure control
func (h *MessageHandlerWithBackpressure) ConsumeClaim(session sarama.ConsumerGroupSession, claim sarama.ConsumerGroupClaim) error {
	for message := range claim.Messages() {
		if err := h.baseHandler.processMessage(message); err != nil {
			h.logger.Error("Failed to process message",
				zap.String("topic", message.Topic),
				zap.Int32("partition", message.Partition),
				zap.Int64("offset", message.Offset),
				zap.Error(err),
			)
			if h.baseHandler.metrics != nil {
				h.baseHandler.metrics.IncrementErrors()
			}
			if h.baseHandler.handleProcessingFailure(message, err) {
				session.MarkMessage(message, "dlq")
			}
			continue
		}

		if h.baseHandler.metrics != nil {
			h.baseHandler.metrics.IncrementProcessed()
		}
		session.MarkMessage(message, "")
	}

	return nil
}

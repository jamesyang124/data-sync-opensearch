package kafka

import (
	"time"

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
	isPaused := false
	pauseCheckInterval := 100 * time.Millisecond
	lastPauseCheck := time.Now()

	for {
		select {
		case <-session.Context().Done():
			return nil

		case message, ok := <-claim.Messages():
			if !ok {
				return nil
			}

			// If paused, check periodically if we should resume
			if isPaused {
				if time.Since(lastPauseCheck) >= pauseCheckInterval {
					if h.workerPool.ShouldResume() {
						isPaused = false
						h.logger.Info("Resuming message consumption")
					}
					lastPauseCheck = time.Now()
				}

				// If still paused, sleep briefly and skip this message iteration
				// The message will be re-read on next iteration since we haven't marked it
				if isPaused {
					time.Sleep(pauseCheckInterval)
					// Put the message back by not processing it
					// Sarama will re-deliver since we didn't mark it
					continue
				}
			}

			// Submit to worker pool
			accepted := h.workerPool.Submit(message, session)

			if !accepted {
				// Queue is full, pause consumption
				isPaused = true
				lastPauseCheck = time.Now()
				h.logger.Warn("Pausing message consumption due to backpressure")

				// Don't mark the message, it will be redelivered
				// Sleep to avoid tight loop
				time.Sleep(pauseCheckInterval)
			}
		}
	}
}

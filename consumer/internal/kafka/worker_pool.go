package kafka

import (
	"context"
	"time"

	"github.com/IBM/sarama"
	"go.uber.org/zap"
)

// WorkItem represents a message to be processed by a worker
type WorkItem struct {
	Message *sarama.ConsumerMessage
	Session sarama.ConsumerGroupSession
}

// WorkerPool manages a pool of workers with backpressure control
type WorkerPool struct {
	workerCount     int
	workQueue       chan *WorkItem
	handler         *MessageHandler
	logger          *zap.Logger
	metrics         BackpressureMetrics
	pauseThreshold  float64
	resumeThreshold float64
	ctx             context.Context
	cancel          context.CancelFunc
}

// BackpressureMetrics interface for tracking backpressure state
type BackpressureMetrics interface {
	IncrementQueueDepth()
	DecrementQueueDepth()
	GetQueueUtilization() float64
	SetPaused(paused bool)
}

// NewWorkerPool creates a new worker pool
func NewWorkerPool(
	workerCount int,
	queueSize int,
	handler *MessageHandler,
	metrics BackpressureMetrics,
	pauseThreshold float64,
	resumeThreshold float64,
	logger *zap.Logger,
) *WorkerPool {
	ctx, cancel := context.WithCancel(context.Background())

	return &WorkerPool{
		workerCount:     workerCount,
		workQueue:       make(chan *WorkItem, queueSize),
		handler:         handler,
		logger:          logger,
		metrics:         metrics,
		pauseThreshold:  pauseThreshold,
		resumeThreshold: resumeThreshold,
		ctx:             ctx,
		cancel:          cancel,
	}
}

// Start starts all workers in the pool
func (wp *WorkerPool) Start() {
	for i := 0; i < wp.workerCount; i++ {
		go wp.worker(i)
	}
	wp.logger.Info("Worker pool started", zap.Int("worker_count", wp.workerCount))
}

// Stop stops all workers gracefully
func (wp *WorkerPool) Stop() {
	wp.cancel()
	close(wp.workQueue)
	wp.logger.Info("Worker pool stopped")
}

// Submit submits a work item to the queue with backpressure control
// Returns true if accepted, false if should pause consumption
func (wp *WorkerPool) Submit(message *sarama.ConsumerMessage, session sarama.ConsumerGroupSession) bool {
	select {
	case <-wp.ctx.Done():
		return false
	case wp.workQueue <- &WorkItem{Message: message, Session: session}:
		wp.metrics.IncrementQueueDepth()

		// Check if we should signal backpressure
		utilization := wp.metrics.GetQueueUtilization()
		if utilization >= wp.pauseThreshold {
			wp.logger.Warn("Queue utilization high, signaling backpressure",
				zap.Float64("utilization", utilization),
				zap.Float64("pause_threshold", wp.pauseThreshold),
			)
			wp.metrics.SetPaused(true)
			return false // Signal to pause consumption
		}
		return true
	}
}

// ShouldResume checks if consumption should resume
func (wp *WorkerPool) ShouldResume() bool {
	utilization := wp.metrics.GetQueueUtilization()
	if utilization <= wp.resumeThreshold {
		wp.metrics.SetPaused(false)
		wp.logger.Info("Queue utilization low, resuming consumption",
			zap.Float64("utilization", utilization),
			zap.Float64("resume_threshold", wp.resumeThreshold),
		)
		return true
	}
	return false
}

// worker processes items from the work queue
func (wp *WorkerPool) worker(id int) {
	wp.logger.Debug("Worker started", zap.Int("worker_id", id))

	for {
		select {
		case <-wp.ctx.Done():
			wp.logger.Debug("Worker stopped", zap.Int("worker_id", id))
			return

		case item, ok := <-wp.workQueue:
			if !ok {
				wp.logger.Debug("Worker queue closed", zap.Int("worker_id", id))
				return
			}

			// Process the message
			startTime := time.Now()
			if err := wp.handler.processMessage(item.Message); err != nil {
				wp.logger.Error("Worker failed to process message",
					zap.Int("worker_id", id),
					zap.String("topic", item.Message.Topic),
					zap.Int32("partition", item.Message.Partition),
					zap.Int64("offset", item.Message.Offset),
					zap.Error(err),
				)
				if wp.handler.metrics != nil {
					wp.handler.metrics.IncrementErrors()
				}
				if wp.handler.handleProcessingFailure(item.Message, err) {
					item.Session.MarkMessage(item.Message, "dlq")
				}
			} else {
				// Mark message as processed on success
				if wp.handler.metrics != nil {
					wp.handler.metrics.IncrementProcessed()
				}
				item.Session.MarkMessage(item.Message, "")
			}

			// Decrement queue depth after processing
			wp.metrics.DecrementQueueDepth()

			wp.logger.Debug("Worker processed message",
				zap.Int("worker_id", id),
				zap.Duration("duration", time.Since(startTime)),
			)
		}
	}
}

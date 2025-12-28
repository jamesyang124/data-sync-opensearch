package health

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync/atomic"
	"time"

	"go.uber.org/zap"
)

// Server provides health check and metrics HTTP endpoints
type Server struct {
	server          *http.Server
	logger          *zap.Logger
	metrics         *Metrics
	kafkaConnected  atomic.Bool
	osConnected     atomic.Bool
}

// Metrics tracks consumer performance metrics
type Metrics struct {
	ProcessedCount  atomic.Int64
	ErrorCount      atomic.Int64
	LastProcessedAt atomic.Value // stores time.Time
	StartTime       time.Time

	// Backpressure metrics
	QueueDepth      atomic.Int64 // Current number of items in worker queue
	QueueCapacity   int          // Maximum queue capacity
	IsPaused        atomic.Bool  // Whether consumption is currently paused
	PauseCount      atomic.Int64 // Number of times consumption has been paused
}

// NewServer creates a new health check server
func NewServer(port string, logger *zap.Logger) *Server {
	metrics := &Metrics{
		StartTime: time.Now(),
	}
	metrics.LastProcessedAt.Store(time.Time{})

	s := &Server{
		logger:  logger,
		metrics: metrics,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", s.healthHandler)
	mux.HandleFunc("/metrics", s.metricsHandler)

	s.server = &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}

	return s
}

// Start starts the HTTP server
func (s *Server) Start() error {
	s.logger.Info("Starting health server", zap.String("addr", s.server.Addr))
	return s.server.ListenAndServe()
}

// Shutdown gracefully shuts down the server
func (s *Server) Shutdown(ctx context.Context) error {
	return s.server.Shutdown(ctx)
}

// GetMetrics returns the metrics instance
func (s *Server) GetMetrics() *Metrics {
	return s.metrics
}

// SetKafkaConnected updates Kafka connection status
func (s *Server) SetKafkaConnected(connected bool) {
	s.kafkaConnected.Store(connected)
}

// SetOpenSearchConnected updates OpenSearch connection status
func (s *Server) SetOpenSearchConnected(connected bool) {
	s.osConnected.Store(connected)
}

// healthHandler handles /health endpoint
func (s *Server) healthHandler(w http.ResponseWriter, r *http.Request) {
	kafkaOK := s.kafkaConnected.Load()
	osOK := s.osConnected.Load()

	status := "healthy"
	statusCode := http.StatusOK

	if !kafkaOK || !osOK {
		status = "degraded"
		statusCode = http.StatusServiceUnavailable
	}

	response := map[string]interface{}{
		"status": status,
		"checks": map[string]interface{}{
			"kafka": map[string]interface{}{
				"connected": kafkaOK,
			},
			"opensearch": map[string]interface{}{
				"connected": osOK,
			},
		},
		"uptime": time.Since(s.metrics.StartTime).String(),
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(statusCode)
	json.NewEncoder(w).Encode(response)
}

// metricsHandler handles /metrics endpoint
func (s *Server) metricsHandler(w http.ResponseWriter, r *http.Request) {
	processed := s.metrics.ProcessedCount.Load()
	errors := s.metrics.ErrorCount.Load()
	uptime := time.Since(s.metrics.StartTime)

	var processingRate float64
	if uptime.Seconds() > 0 {
		processingRate = float64(processed) / uptime.Seconds()
	}

	lastProcessed := s.metrics.LastProcessedAt.Load().(time.Time)
	var lastProcessedStr string
	if !lastProcessed.IsZero() {
		lastProcessedStr = lastProcessed.Format(time.RFC3339)
	}

	// Backpressure metrics
	queueDepth := s.metrics.QueueDepth.Load()
	queueCapacity := s.metrics.QueueCapacity
	var queueUtilization float64
	if queueCapacity > 0 {
		queueUtilization = (float64(queueDepth) / float64(queueCapacity)) * 100.0
	}
	isPaused := s.metrics.IsPaused.Load()
	pauseCount := s.metrics.PauseCount.Load()

	response := map[string]interface{}{
		"processing": map[string]interface{}{
			"total_processed": processed,
			"error_count":     errors,
			"success_rate":    calculateSuccessRate(processed, errors),
			"processing_rate": fmt.Sprintf("%.2f events/sec", processingRate),
			"last_processed":  lastProcessedStr,
		},
		"backpressure": map[string]interface{}{
			"queue_depth":       queueDepth,
			"queue_capacity":    queueCapacity,
			"queue_utilization": fmt.Sprintf("%.1f%%", queueUtilization),
			"is_paused":         isPaused,
			"pause_count":       pauseCount,
		},
		"runtime": map[string]interface{}{
			"uptime_seconds": uptime.Seconds(),
			"start_time":     s.metrics.StartTime.Format(time.RFC3339),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// IncrementProcessed increments the processed counter
func (m *Metrics) IncrementProcessed() {
	m.ProcessedCount.Add(1)
	m.LastProcessedAt.Store(time.Now())
}

// IncrementErrors increments the error counter
func (m *Metrics) IncrementErrors() {
	m.ErrorCount.Add(1)
}

// IncrementQueueDepth increments the queue depth counter
func (m *Metrics) IncrementQueueDepth() {
	m.QueueDepth.Add(1)
}

// DecrementQueueDepth decrements the queue depth counter
func (m *Metrics) DecrementQueueDepth() {
	m.QueueDepth.Add(-1)
}

// SetPaused sets the pause state
func (m *Metrics) SetPaused(paused bool) {
	wasPaused := m.IsPaused.Swap(paused)
	if paused && !wasPaused {
		// Transitioned from running to paused
		m.PauseCount.Add(1)
	}
}

// GetQueueUtilization returns the queue utilization as a percentage (0.0-1.0)
func (m *Metrics) GetQueueUtilization() float64 {
	if m.QueueCapacity == 0 {
		return 0.0
	}
	return float64(m.QueueDepth.Load()) / float64(m.QueueCapacity)
}

// calculateSuccessRate calculates the success rate percentage
func calculateSuccessRate(processed, errors int64) float64 {
	if processed == 0 {
		return 100.0
	}
	successes := processed - errors
	return (float64(successes) / float64(processed)) * 100.0
}

package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/murcurial/data-sync-opensearch/consumer/internal/config"
	"github.com/murcurial/data-sync-opensearch/consumer/internal/health"
	"github.com/murcurial/data-sync-opensearch/consumer/internal/kafka"
	"github.com/murcurial/data-sync-opensearch/consumer/internal/logger"
	"github.com/murcurial/data-sync-opensearch/consumer/internal/opensearch"
	"github.com/murcurial/data-sync-opensearch/consumer/internal/transform"
	"go.uber.org/zap"
)

func main() {
	// Initialize logger
	if err := logger.Init(); err != nil {
		panic("Failed to initialize logger: " + err.Error())
	}
	defer logger.Sync()

	logger.Log.Info("Starting CDC Consumer Application")

	// Load configuration
	cfg := config.Load()
	logger.Log.Info("Configuration loaded",
		zap.Strings("kafka_brokers", cfg.KafkaBrokers),
		zap.String("consumer_group", cfg.ConsumerGroup),
		zap.String("opensearch_url", cfg.OpenSearchURL),
		zap.Int("worker_count", cfg.WorkerCount),
		zap.Int("queue_size", cfg.QueueSize),
		zap.Float64("pause_threshold", cfg.PauseThreshold),
		zap.Float64("resume_threshold", cfg.ResumeThreshold),
	)

	// Initialize health server
	healthServer := health.NewServer(cfg.HealthPort, logger.Log)
	metrics := healthServer.GetMetrics()

	// Set queue capacity for backpressure metrics
	metrics.QueueCapacity = cfg.QueueSize

	// Start health server in background
	go func() {
		if err := healthServer.Start(); err != nil && err != http.ErrServerClosed {
			logger.Log.Error("Health server error", zap.Error(err))
		}
	}()

	// Initialize OpenSearch client
	osClient, err := opensearch.NewClient(cfg.OpenSearchURL, logger.Log)
	if err != nil {
		logger.Log.Fatal("Failed to initialize OpenSearch client", zap.Error(err))
	}
	healthServer.SetOpenSearchConnected(true)

	// Initialize indexer
	indexer := opensearch.NewIndexer(osClient)

	// Initialize transformer
	transformer := transform.NewTransformer()

	// Initialize base Kafka message handler
	baseHandler := kafka.NewMessageHandler(logger.Log, transformer, indexer, metrics)

	// Initialize worker pool with backpressure control
	workerPool := kafka.NewWorkerPool(
		cfg.WorkerCount,
		cfg.QueueSize,
		baseHandler,
		metrics,
		cfg.PauseThreshold,
		cfg.ResumeThreshold,
		logger.Log,
	)

	// Start worker pool
	workerPool.Start()

	// Initialize backpressure-aware message handler
	handler := kafka.NewMessageHandlerWithBackpressure(baseHandler, workerPool, logger.Log)

	// Initialize Kafka consumer
	consumer, err := kafka.NewConsumer(
		cfg.KafkaBrokers,
		cfg.ConsumerGroup,
		cfg.Topics,
		handler,
		logger.Log,
	)
	if err != nil {
		logger.Log.Fatal("Failed to initialize Kafka consumer", zap.Error(err))
	}
	defer consumer.Close()
	healthServer.SetKafkaConnected(true)

	// Setup graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Start consumer in background
	go func() {
		if err := consumer.Start(ctx); err != nil {
			logger.Log.Error("Consumer error", zap.Error(err))
			cancel()
		}
	}()

	logger.Log.Info("Consumer application started successfully")

	// Signal handling for graceful shutdown
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)

	// Wait for shutdown signal or context cancellation
	select {
	case sig := <-sigChan:
		logger.Log.Info("Received shutdown signal", zap.String("signal", sig.String()))
	case <-ctx.Done():
		logger.Log.Info("Context cancelled")
	}

	// Graceful shutdown
	logger.Log.Info("Initiating graceful shutdown...")
	cancel()

	// Stop worker pool to prevent new message processing
	workerPool.Stop()

	// Shutdown health server
	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()
	if err := healthServer.Shutdown(shutdownCtx); err != nil {
		logger.Log.Warn("Health server shutdown error", zap.Error(err))
	}

	// Give time for in-flight messages to complete
	shutdownTimeout := 30 * time.Second
	shutdownTimer := time.NewTimer(shutdownTimeout)
	<-shutdownTimer.C

	logger.Log.Info("Consumer application stopped")
}

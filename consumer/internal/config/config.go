package config

import (
	"os"
	"strconv"
	"strings"
)

// Config holds all application configuration
type Config struct {
	// Kafka configuration
	KafkaBrokers   []string
	ConsumerGroup  string
	Topics         []string

	// OpenSearch configuration
	OpenSearchURL  string

	// Consumer configuration
	BatchSize      int
	MaxRetries     int
	WorkerCount    int

	// Backpressure configuration
	QueueSize          int     // Worker queue buffer size
	PauseThreshold     float64 // Pause consumption when queue is X% full (0.0-1.0)
	ResumeThreshold    float64 // Resume consumption when queue drops to X% full (0.0-1.0)

	// Health server configuration
	HealthPort     string
}

// Load reads configuration from environment variables
func Load() *Config {
	return &Config{
		KafkaBrokers:   strings.Split(getEnv("KAFKA_BROKERS", "localhost:9092"), ","),
		ConsumerGroup:  getEnv("CONSUMER_GROUP", "cdc-consumer-group"),
		Topics: []string{
			"dbserver.public.videos",
			"dbserver.public.users",
			"dbserver.public.comments",
		},
		OpenSearchURL:   getEnv("OPENSEARCH_URL", "http://localhost:9200"),
		BatchSize:       getEnvInt("BATCH_SIZE", 100),
		MaxRetries:      getEnvInt("MAX_RETRIES", 3),
		WorkerCount:     getEnvInt("WORKER_COUNT", 10),
		QueueSize:       getEnvInt("QUEUE_SIZE", 1000),
		PauseThreshold:  getEnvFloat64("PAUSE_THRESHOLD", 0.8),   // Pause at 80% full
		ResumeThreshold: getEnvFloat64("RESUME_THRESHOLD", 0.4),  // Resume at 40% full
		HealthPort:      getEnv("HEALTH_PORT", "8080"),
	}
}

// getEnv retrieves environment variable or returns default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt retrieves integer environment variable or returns default value
func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if intValue, err := strconv.Atoi(value); err == nil {
			return intValue
		}
	}
	return defaultValue
}

// getEnvFloat64 retrieves float64 environment variable or returns default value
func getEnvFloat64(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if floatValue, err := strconv.ParseFloat(value, 64); err == nil {
			return floatValue
		}
	}
	return defaultValue
}

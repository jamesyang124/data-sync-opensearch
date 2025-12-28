package config

import (
	"fmt"
	"os"
	"strconv"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Metrics  MetricsConfig
	LogLevel string
}

// ServerConfig holds HTTP server configuration
type ServerConfig struct {
	Port int
}

// DatabaseConfig holds PostgreSQL configuration
type DatabaseConfig struct {
	Host     string
	Port     int
	User     string
	Password string
	DBName   string
	SSLMode  string
}

// MetricsConfig holds metrics configuration
type MetricsConfig struct {
	Port int
}

// Load loads configuration from environment variables
func Load() (*Config, error) {
	serverPort, err := getEnvInt("PRODUCER_PORT", 8080)
	if err != nil {
		return nil, fmt.Errorf("invalid PRODUCER_PORT: %w", err)
	}

	metricsPort, err := getEnvInt("PRODUCER_METRICS_PORT", 9090)
	if err != nil {
		return nil, fmt.Errorf("invalid PRODUCER_METRICS_PORT: %w", err)
	}

	dbPort, err := getEnvInt("PRODUCER_DB_PORT", 5432)
	if err != nil {
		return nil, fmt.Errorf("invalid PRODUCER_DB_PORT: %w", err)
	}

	return &Config{
		Server: ServerConfig{
			Port: serverPort,
		},
		Database: DatabaseConfig{
			Host:     getEnvString("PRODUCER_DB_HOST", "localhost"),
			Port:     dbPort,
			User:     getEnvString("PRODUCER_DB_USER", "postgres"),
			Password: getEnvString("PRODUCER_DB_PASSWORD", "postgres"),
			DBName:   getEnvString("PRODUCER_DB_NAME", "opensearch_demo"),
			SSLMode:  getEnvString("PRODUCER_DB_SSLMODE", "disable"),
		},
		Metrics: MetricsConfig{
			Port: metricsPort,
		},
		LogLevel: getEnvString("PRODUCER_LOG_LEVEL", "info"),
	}, nil
}

func getEnvString(key, defaultValue string) string {
	if value, exists := os.LookupEnv(key); exists {
		return value
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) (int, error) {
	if value, exists := os.LookupEnv(key); exists {
		intValue, err := strconv.Atoi(value)
		if err != nil {
			return 0, err
		}
		return intValue, nil
	}
	return defaultValue, nil
}

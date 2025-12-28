package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Log *zap.Logger

// Init initializes the global logger with structured JSON output
func Init() error {
	config := zap.NewProductionConfig()
	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder

	logger, err := config.Build()
	if err != nil {
		return err
	}

	Log = logger
	return nil
}

// WithCorrelationID creates a logger with correlation ID field
func WithCorrelationID(correlationID string) *zap.Logger {
	if Log == nil {
		// Fallback to no-op logger if not initialized
		return zap.NewNop()
	}
	return Log.With(zap.String("correlation_id", correlationID))
}

// Sync flushes any buffered log entries
func Sync() error {
	if Log != nil {
		return Log.Sync()
	}
	return nil
}

package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

// Init initializes the logger
func Init(level string) (*zap.Logger, error) {
	var config zap.Config

	if level == "debug" {
		config = zap.NewDevelopmentConfig()
	} else {
		config = zap.NewProductionConfig()
	}

	// Parse log level
	logLevel, err := zapcore.ParseLevel(level)
	if err == nil {
		config.Level = zap.NewAtomicLevelAt(logLevel)
	}

	config.EncoderConfig.TimeKey = "timestamp"
	config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder

	logger, err := config.Build()
	if err != nil {
		return nil, err
	}

	return logger, nil
}

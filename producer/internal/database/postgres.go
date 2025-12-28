package database

import (
	"context"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/murcurial/data-sync-opensearch/producer/internal/config"
	"go.uber.org/zap"
)

// Database wraps the pgx connection pool
type Database struct {
	Pool   *pgxpool.Pool
	logger *zap.Logger
}

// New creates a new database connection pool
func New(ctx context.Context, cfg config.DatabaseConfig, logger *zap.Logger) (*Database, error) {
	connString := fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		cfg.User, cfg.Password, cfg.Host, cfg.Port, cfg.DBName, cfg.SSLMode,
	)

	pgConfig, err := pgxpool.ParseConfig(connString)
	if err != nil {
		return nil, fmt.Errorf("failed to parse connection string: %w", err)
	}

	// Configure pool settings
	pgConfig.MaxConns = 25
	pgConfig.MinConns = 2
	pgConfig.MaxConnLifetime = time.Hour
	pgConfig.MaxConnIdleTime = 30 * time.Minute

	pool, err := pgxpool.NewWithConfig(ctx, pgConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to create connection pool: %w", err)
	}

	// Verify connection
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("Connected to PostgreSQL", 
		zap.String("host", cfg.Host), 
		zap.String("db", cfg.DBName),
	)

	return &Database{
		Pool:   pool,
		logger: logger,
	}, nil
}

// Close closes the database connection pool
func (db *Database) Close() {
	if db.Pool != nil {
		db.Pool.Close()
		db.logger.Info("Database connection pool closed")
	}
}

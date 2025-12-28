package api

import (
	"encoding/json"
	"net/http"
	"runtime"
	"time"

	"go.uber.org/zap"
)

var startTime = time.Now()

// Metrics handles /metrics endpoint
func (s *Server) Metrics(w http.ResponseWriter, r *http.Request) {
	var dbStats map[string]interface{}
	
	if s.db != nil && s.db.Pool != nil {
		stats := s.db.Pool.Stat()
		dbStats = map[string]interface{}{
			"pool_total_conns": stats.TotalConns(),
			"pool_idle_conns":  stats.IdleConns(),
			"pool_acquired_conns": stats.AcquiredConns(),
		}
	}

	response := map[string]interface{}{
		"http": map[string]interface{}{
			"requests_total": 0, // Placeholder, usually requires middleware to track
		},
		"db": dbStats,
		"runtime": map[string]interface{}{
			"uptime_seconds": time.Since(startTime).Seconds(),
			"goroutines":     runtime.NumGoroutine(),
		},
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		s.logger.Error("Failed to encode metrics response", zap.Error(err))
	}
}

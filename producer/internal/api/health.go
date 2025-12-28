package api

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"go.uber.org/zap"
)

// HealthCheck handles /health endpoint
func (s *Server) HealthCheck(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	dbConnected := true
	
	// Perform a quick ping to DB
	if s.db != nil && s.db.Pool != nil {
		pingCtx, cancel := context.WithTimeout(ctx, 1*time.Second)
		defer cancel()
		if err := s.db.Pool.Ping(pingCtx); err != nil {
			dbConnected = false
			s.logger.Error("Database health check failed", zap.Error(err))
		}
	} else {
		dbConnected = false
	}

	response := map[string]interface{}{
		"status":        "up",
		"db_connection": dbConnected,
	}

	status := http.StatusOK
	if !dbConnected {
		response["status"] = "degraded"
		status = http.StatusServiceUnavailable
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(response); err != nil {
		s.logger.Error("Failed to encode health response", zap.Error(err))
	}
}
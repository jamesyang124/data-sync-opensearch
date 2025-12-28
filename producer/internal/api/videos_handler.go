package api

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
	"go.uber.org/zap"
)

// CreateVideo handles POST /videos
func (s *Server) CreateVideo(w http.ResponseWriter, r *http.Request) {
	var video models.Video
	if err := json.NewDecoder(r.Body).Decode(&video); err != nil {
		s.respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := s.db.CreateVideo(r.Context(), &video); err != nil {
		if strings.Contains(err.Error(), "foreign key constraint") {
			s.respondWithError(w, http.StatusConflict, "User does not exist")
			return
		}
		s.logger.Error("Failed to create video", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	s.respondWithJSON(w, http.StatusCreated, video)
}

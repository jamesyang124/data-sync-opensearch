package api

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
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

// UpdateVideo handles PUT /videos/{id}
func (s *Server) UpdateVideo(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	var video models.Video
	if err := json.NewDecoder(r.Body).Decode(&video); err != nil {
		s.respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	video.VideoID = idStr

	if err := s.db.UpdateVideo(r.Context(), &video); err != nil {
		if strings.Contains(err.Error(), "video not found") {
			s.respondWithError(w, http.StatusNotFound, "Video not found")
			return
		}
		if strings.Contains(err.Error(), "duplicate key") {
			s.respondWithError(w, http.StatusConflict, "Video already exists")
			return
		}
		s.logger.Error("Failed to update video", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	s.respondWithJSON(w, http.StatusOK, video)
}

// DeleteVideo handles DELETE /videos/{id}
func (s *Server) DeleteVideo(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	if err := s.db.DeleteVideo(r.Context(), idStr); err != nil {
		if strings.Contains(err.Error(), "video not found") {
			s.respondWithError(w, http.StatusNotFound, "Video not found")
			return
		}
		s.logger.Error("Failed to delete video", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

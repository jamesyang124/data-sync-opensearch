package api

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
	"go.uber.org/zap"
)

// CreateComment handles POST /comments.
func (s *Server) CreateComment(w http.ResponseWriter, r *http.Request) {
	var comment models.Comment
	if err := json.NewDecoder(r.Body).Decode(&comment); err != nil {
		s.respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := s.db.CreateComment(r.Context(), &comment); err != nil {
		if strings.Contains(err.Error(), "foreign key") {
			s.respondWithError(w, http.StatusConflict, "Video or channel does not exist")
			return
		}
		if strings.Contains(err.Error(), "duplicate key") {
			s.respondWithError(w, http.StatusConflict, "Comment already exists")
			return
		}
		s.logger.Error("Failed to create comment", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	s.respondWithJSON(w, http.StatusCreated, comment)
}

// UpdateComment handles PUT /comments/{id}.
func (s *Server) UpdateComment(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	var comment models.Comment
	if err := json.NewDecoder(r.Body).Decode(&comment); err != nil {
		s.respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	comment.CommentID = idStr

	if err := s.db.UpdateComment(r.Context(), &comment); err != nil {
		if strings.Contains(err.Error(), "comment not found") {
			s.respondWithError(w, http.StatusNotFound, "Comment not found")
			return
		}
		if strings.Contains(err.Error(), "foreign key") {
			s.respondWithError(w, http.StatusConflict, "Video or channel does not exist")
			return
		}
		if strings.Contains(err.Error(), "duplicate key") {
			s.respondWithError(w, http.StatusConflict, "Comment already exists")
			return
		}
		s.logger.Error("Failed to update comment", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	s.respondWithJSON(w, http.StatusOK, comment)
}

// DeleteComment handles DELETE /comments/{id}.
func (s *Server) DeleteComment(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	if err := s.db.DeleteComment(r.Context(), idStr); err != nil {
		if strings.Contains(err.Error(), "comment not found") {
			s.respondWithError(w, http.StatusNotFound, "Comment not found")
			return
		}
		s.logger.Error("Failed to delete comment", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

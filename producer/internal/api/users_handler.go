package api

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/go-chi/chi/v5"
	"github.com/murcurial/data-sync-opensearch/producer/pkg/models"
	"go.uber.org/zap"
)

// CreateUser handles POST /users
func (s *Server) CreateUser(w http.ResponseWriter, r *http.Request) {
	var user models.User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		s.respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	if err := s.db.CreateUser(r.Context(), &user); err != nil {
		if strings.Contains(err.Error(), "duplicate key") {
			s.respondWithError(w, http.StatusConflict, "User already exists")
			return
		}
		s.logger.Error("Failed to create user", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	s.respondWithJSON(w, http.StatusCreated, user)
}

// UpdateUser handles PUT /users/{id}
func (s *Server) UpdateUser(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	var user models.User
	if err := json.NewDecoder(r.Body).Decode(&user); err != nil {
		s.respondWithError(w, http.StatusBadRequest, "Invalid request body")
		return
	}
	user.ChannelID = idStr

	if err := s.db.UpdateUser(r.Context(), &user); err != nil {
		if strings.Contains(err.Error(), "user not found") {
			s.respondWithError(w, http.StatusNotFound, "User not found")
			return
		}
		if strings.Contains(err.Error(), "duplicate key") {
			s.respondWithError(w, http.StatusConflict, "Channel ID conflict")
			return
		}
		s.logger.Error("Failed to update user", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	s.respondWithJSON(w, http.StatusOK, user)
}

// DeleteUser handles DELETE /users/{id}
func (s *Server) DeleteUser(w http.ResponseWriter, r *http.Request) {
	idStr := chi.URLParam(r, "id")

	if err := s.db.DeleteUser(r.Context(), idStr); err != nil {
		if strings.Contains(err.Error(), "user not found") {
			s.respondWithError(w, http.StatusNotFound, "User not found")
			return
		}
		s.logger.Error("Failed to delete user", zap.Error(err))
		s.respondWithError(w, http.StatusInternalServerError, "Internal server error")
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

func (s *Server) respondWithError(w http.ResponseWriter, code int, message string) {
	s.respondWithJSON(w, code, map[string]string{"error": message})
}

func (s *Server) respondWithJSON(w http.ResponseWriter, code int, payload interface{}) {
	response, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	w.Write(response)
}

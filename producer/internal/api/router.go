package api

import (
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/murcurial/data-sync-opensearch/producer/internal/database"
	"go.uber.org/zap"
)

// Server holds API server dependencies
type Server struct {
	Router *chi.Mux
	db     *database.Database
	logger *zap.Logger
}

// NewServer creates a new API server
func NewServer(db *database.Database, logger *zap.Logger) *Server {
	r := chi.NewRouter()

	// Middleware
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	
	// Custom logger middleware wrapper could be added here to use Zap

	s := &Server{
		Router: r,
		db:     db,
		logger: logger,
	}

	s.routes()
	
	return s
}

func (s *Server) routes() {
	s.Router.Get("/health", s.HealthCheck)
	s.Router.Get("/metrics", s.Metrics)
	
	s.Router.Route("/api/v1", func(r chi.Router) {
		r.Route("/users", func(r chi.Router) {
			r.Post("/", s.CreateUser)
			r.Put("/{id}", s.UpdateUser)
			r.Delete("/{id}", s.DeleteUser)
		})
		
		r.Route("/videos", func(r chi.Router) {
			r.Post("/", s.CreateVideo)
		})
	})
}

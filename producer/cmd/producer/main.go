package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/murcurial/data-sync-opensearch/producer/internal/api"
	"github.com/murcurial/data-sync-opensearch/producer/internal/config"
	"github.com/murcurial/data-sync-opensearch/producer/internal/database"
	"github.com/murcurial/data-sync-opensearch/producer/internal/logger"
	"github.com/spf13/cobra"
	"go.uber.org/zap"
)

var (
	cfgFile string
)

func main() {
	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

var rootCmd = &cobra.Command{
	Use:   "producer",
	Short: "Test Data Service for CDC Pipeline",
	Long: `A high-performance REST API service for generating test data 
and triggering CDC events in PostgreSQL.`,
}

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Starts the HTTP API server",
	Run: func(cmd *cobra.Command, args []string) {
		cfg, err := config.Load()
		if err != nil {
			fmt.Printf("Failed to load config: %v\n", err)
			os.Exit(1)
		}

		log, err := logger.Init(cfg.LogLevel)
		if err != nil {
			fmt.Printf("Failed to init logger: %v\n", err)
			os.Exit(1)
		}
		defer log.Sync()

		ctx := context.Background()

		// Initialize Database
		db, err := database.New(ctx, cfg.Database, log)
		if err != nil {
			log.Fatal("Failed to initialize database", zap.Error(err))
		}
		defer db.Close()

		// Initialize API Server
		apiServer := api.NewServer(db, log)

		srv := &http.Server{
			Addr:    fmt.Sprintf(":%d", cfg.Server.Port),
			Handler: apiServer.Router,
		}

		// Start Server
		go func() {
			log.Info("Starting HTTP server", zap.Int("port", cfg.Server.Port))
			if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
				log.Fatal("HTTP server failed", zap.Error(err))
			}
		}()

		// Graceful Shutdown
		stop := make(chan os.Signal, 1)
		signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
		<-stop

		log.Info("Shutting down server...")

		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()

		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Error("Server forced to shutdown", zap.Error(err))
		}

		log.Info("Server exited")
	},
}

func init() {
	rootCmd.PersistentFlags().StringVar(&cfgFile, "config", "", "config file (default is $HOME/.producer.yaml)")
	
	rootCmd.AddCommand(serveCmd)
	rootCmd.AddCommand(versionCmd)
	
	serveCmd.Flags().Int("port", 8080, "Port to listen on")
	serveCmd.Flags().Int("metrics-port", 9090, "Port for metrics")
}

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the version number",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Producer Service v1.0.0")
	},
}
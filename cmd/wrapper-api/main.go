package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"swaap/internal/config"
	"swaap/internal/database"
	"swaap/internal/handler"
	"swaap/internal/middleware"
)

func main() {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: cfg.LogLevel,
	}))

	// Initialize PostgreSQL
	db, err := database.Open(database.Config{
		Host:     cfg.DBHost,
		Port:     cfg.DBPort,
		User:     cfg.DBUser,
		Password: cfg.DBPass,
		Name:     cfg.DBName,
		SSLMode:  cfg.DBSSLMode,
	}, logger)
	if err != nil {
		logger.Error("failed to connect to database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	h := handler.New(logger, db)

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte(`{"ok":true,"data":{"status":"up"}}`))
	})

	// Existing SmartOne proxy routes
	mux.HandleFunc("/api/login", h.HandleLogin)
	mux.HandleFunc("/api/menu", h.HandleMenu)
	mux.HandleFunc("/api/jadwal", h.HandleJadwal)
	mux.HandleFunc("/api/presensi", h.HandlePresensi)
	mux.HandleFunc("/api/attend", h.HandleAttend)

	// Aspirasi & Aduan routes
	mux.HandleFunc("/api/aspirasi/submit", h.HandleAspirasiSubmit)
	mux.HandleFunc("/api/aspirasi/list", h.HandleAspirasiList)
	mux.HandleFunc("/api/aspirasi/my", h.HandleAspirasiMy)
	mux.HandleFunc("/api/aspirasi/delete", h.HandleAspirasiDelete)
	mux.HandleFunc("/api/aspirasi/admin/list", h.HandleAspirasiAdminList)
	mux.HandleFunc("/api/aspirasi/admin/update", h.HandleAspirasiAdminUpdate)

	// Admin routes
	mux.HandleFunc("/api/admin/check", h.HandleAdminCheck)
	mux.HandleFunc("/api/admin/add", h.HandleAdminAdd)

	// Apply middleware chain: Recovery (outermost) → Logging → CORS (innermost)
	wrapped := middleware.Chain(mux,
		middleware.Recovery(logger),
		middleware.Logging(logger),
		middleware.CORS(cfg.CORSOrigins),
	)

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           wrapped,
		ReadHeaderTimeout: cfg.ReadTimeout,
		WriteTimeout:      cfg.WriteTimeout,
	}

	// Graceful shutdown on SIGINT/SIGTERM
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	go func() {
		logger.Info("wrapper api starting", "port", cfg.Port, "log_level", cfg.LogLevel.String())
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server error", "error", err)
			os.Exit(1)
		}
	}()

	<-ctx.Done()
	logger.Info("shutting down gracefully...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		logger.Error("shutdown error", "error", err)
	}

	logger.Info("server stopped")
}

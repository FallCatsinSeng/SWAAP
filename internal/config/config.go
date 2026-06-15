// Package config provides centralized configuration loaded from environment variables.
package config

import (
	"log/slog"
	"os"
	"strconv"
	"strings"
	"time"
)

// Config holds all application configuration.
type Config struct {
	Port         string
	LogLevel     slog.Level
	CORSOrigins  []string
	ReadTimeout  time.Duration
	WriteTimeout time.Duration
	// Database
	DBHost    string
	DBPort    string
	DBUser    string
	DBPass    string
	DBName    string
	DBSSLMode string
}

// Load reads configuration from environment variables with sensible defaults.
func Load() Config {
	return Config{
		Port:         envOr("PORT", "8081"),
		LogLevel:     parseLogLevel(envOr("LOG_LEVEL", "info")),
		CORSOrigins:  strings.Split(envOr("CORS_ORIGINS", "*"), ","),
		ReadTimeout:  parseDuration("READ_TIMEOUT", 15*time.Second),
		WriteTimeout: parseDuration("WRITE_TIMEOUT", 30*time.Second),
		// Database defaults match docker-compose service name "postgres"
		DBHost:    envOr("DB_HOST", "postgres"),
		DBPort:    envOr("DB_PORT", "5432"),
		DBUser:    envOr("DB_USER", "swaap"),
		DBPass:    envOr("DB_PASS", "swaap"),
		DBName:    envOr("DB_NAME", "swaap"),
		DBSSLMode: envOr("DB_SSLMODE", "disable"),
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func parseLogLevel(s string) slog.Level {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func parseDuration(key string, fallback time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return fallback
	}
	// Try parsing as seconds first (e.g. "15")
	if secs, err := strconv.Atoi(v); err == nil {
		return time.Duration(secs) * time.Second
	}
	// Try parsing as duration string (e.g. "15s", "1m")
	if d, err := time.ParseDuration(v); err == nil {
		return d
	}
	return fallback
}

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
}

// Load reads configuration from environment variables with sensible defaults.
func Load() Config {
	return Config{
		Port:         envOr("PORT", "8081"),
		LogLevel:     parseLogLevel(envOr("LOG_LEVEL", "info")),
		CORSOrigins:  strings.Split(envOr("CORS_ORIGINS", "*"), ","),
		ReadTimeout:  parseDuration("READ_TIMEOUT", 15*time.Second),
		WriteTimeout: parseDuration("WRITE_TIMEOUT", 30*time.Second),
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

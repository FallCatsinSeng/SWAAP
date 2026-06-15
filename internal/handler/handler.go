// Package handler provides HTTP handlers for the wrapper API.
package handler

import (
	"encoding/json"
	"log/slog"
	"net/http"

	"swaap/internal/database"
	"swaap/internal/middleware"
	"swaap/internal/smartone"
)

// Envelope is the standard API response wrapper.
type Envelope struct {
	OK        bool   `json:"ok"`
	Data      any    `json:"data,omitempty"`
	Error     string `json:"error,omitempty"`
	RequestID string `json:"request_id,omitempty"`
}

// Handler holds shared dependencies for all HTTP handlers.
type Handler struct {
	Logger *slog.Logger
	DB     *database.DB
}

// New creates a new Handler with the given logger and optional database.
func New(logger *slog.Logger, db *database.DB) *Handler {
	return &Handler{Logger: logger, DB: db}
}

// writeJSON encodes v as JSON and writes it to w with the given status code.
func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// writeError writes an error response with request ID.
func writeError(w http.ResponseWriter, r *http.Request, status int, msg string) {
	writeJSON(w, status, Envelope{
		OK:        false,
		Error:     msg,
		RequestID: middleware.RequestIDFromContext(r.Context()),
	})
}

// writeSuccess writes a success response with request ID.
func writeSuccess(w http.ResponseWriter, r *http.Request, data any) {
	writeJSON(w, http.StatusOK, Envelope{
		OK:        true,
		Data:      data,
		RequestID: middleware.RequestIDFromContext(r.Context()),
	})
}

// decodeBody decodes the JSON request body into dst.
func decodeBody(r *http.Request, dst any) error {
	return json.NewDecoder(r.Body).Decode(dst)
}

// newClient creates a smartone client from base URL and headers.
func newClient(baseURL string, headers map[string]string, logger *slog.Logger) (*smartone.Client, error) {
	return smartone.NewClient(baseURL, headers, smartone.WithLogger(slogAdapter{logger}))
}

// requirePOST checks that the request method is POST.
// Returns true if the request should continue, false if it was handled.
func requirePOST(w http.ResponseWriter, r *http.Request) bool {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return false
	}
	if r.Method != http.MethodPost {
		writeError(w, r, http.StatusMethodNotAllowed, "method not allowed")
		return false
	}
	return true
}

// slogAdapter adapts *slog.Logger to the smartone.Logger interface.
type slogAdapter struct {
	l *slog.Logger
}

func (a slogAdapter) Debug(msg string, args ...any) { a.l.Debug(msg, args...) }
func (a slogAdapter) Info(msg string, args ...any)  { a.l.Info(msg, args...) }
func (a slogAdapter) Warn(msg string, args ...any)  { a.l.Warn(msg, args...) }
func (a slogAdapter) Error(msg string, args ...any) { a.l.Error(msg, args...) }

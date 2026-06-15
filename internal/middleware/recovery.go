package middleware

import (
	"encoding/json"
	"log/slog"
	"net/http"
	"runtime/debug"
)

// Recovery returns middleware that catches panics and returns a 500 error
// instead of crashing the server.
func Recovery(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if rec := recover(); rec != nil {
					reqID := RequestIDFromContext(r.Context())
					logger.Error("panic recovered",
						slog.Any("error", rec),
						slog.String("stack", string(debug.Stack())),
						slog.String("request_id", reqID),
						slog.String("path", r.URL.Path),
					)

					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusInternalServerError)
					_ = json.NewEncoder(w).Encode(map[string]any{
						"ok":         false,
						"error":      "internal server error",
						"request_id": reqID,
					})
				}
			}()
			next.ServeHTTP(w, r)
		})
	}
}

// Chain applies middleware in the given order (first wraps outermost).
func Chain(h http.Handler, middlewares ...func(http.Handler) http.Handler) http.Handler {
	for i := len(middlewares) - 1; i >= 0; i-- {
		h = middlewares[i](h)
	}
	return h
}

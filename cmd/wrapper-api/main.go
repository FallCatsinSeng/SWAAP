package main

import (
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"time"

	"swaap/legacy"
)

type envelope struct {
	OK    bool        `json:"ok"`
	Data  interface{} `json:"data,omitempty"`
	Error string      `json:"error,omitempty"`
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8081"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, envelope{OK: true, Data: map[string]string{"status": "up"}})
	})
	mux.HandleFunc("/api/login", handleLogin)
	mux.HandleFunc("/api/menu", handleMenu)
	mux.HandleFunc("/api/jadwal", handleJadwal)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           withCORS(mux),
		ReadHeaderTimeout: 10 * time.Second,
	}

	log.Printf("wrapper api listening on http://127.0.0.1:%s\n", port)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatal(err)
	}
}

func handleLogin(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, envelope{OK: false, Error: "method not allowed"})
		return
	}

	var in legacy.LoginInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeJSON(w, http.StatusBadRequest, envelope{OK: false, Error: "invalid JSON body"})
		return
	}

	client, err := legacy.NewClient(in.BaseURL, in.Headers)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, envelope{OK: false, Error: err.Error()})
		return
	}

	res, err := client.Login(r.Context(), in)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, envelope{OK: false, Error: err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, envelope{OK: true, Data: res})
}

func handleMenu(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, envelope{OK: false, Error: "method not allowed"})
		return
	}

	var in legacy.MenuInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeJSON(w, http.StatusBadRequest, envelope{OK: false, Error: "invalid JSON body"})
		return
	}

	client, err := legacy.NewClient(in.BaseURL, in.Headers)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, envelope{OK: false, Error: err.Error()})
		return
	}

	if in.Ulang == 0 {
		in.Ulang = 1
	}

	res, err := client.GetMenu(r.Context(), in)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, envelope{OK: false, Error: err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, envelope{OK: true, Data: res})
}

func handleJadwal(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodPost {
		writeJSON(w, http.StatusMethodNotAllowed, envelope{OK: false, Error: "method not allowed"})
		return
	}

	var in legacy.JadwalInput
	if err := json.NewDecoder(r.Body).Decode(&in); err != nil {
		writeJSON(w, http.StatusBadRequest, envelope{OK: false, Error: "invalid JSON body"})
		return
	}

	client, err := legacy.NewClient(in.BaseURL, in.Headers)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, envelope{OK: false, Error: err.Error()})
		return
	}

	in.SkipBootstrap = true

	res, err := client.GetJadwal(r.Context(), in)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, envelope{OK: false, Error: err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, envelope{OK: true, Data: res})
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		next.ServeHTTP(w, r)
	})
}

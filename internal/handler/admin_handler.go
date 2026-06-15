package handler

import (
	"net/http"
	"strings"
)

// HandleAdminCheck handles POST /api/admin/check — check if NIM is admin
func (h *Handler) HandleAdminCheck(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in struct {
		NIM string `json:"nim"`
	}
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	writeSuccess(w, r, map[string]any{
		"is_admin": h.isAdmin(in.NIM),
	})
}

// HandleAdminAdd handles POST /api/admin/add — admin adds another admin by NIM
func (h *Handler) HandleAdminAdd(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in struct {
		AdminNIM string `json:"admin_nim"` // requester
		NewNIM   string `json:"new_nim"`   // new admin to add
		NewNama  string `json:"new_nama"`  // optional name
	}
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	// Only existing admin can add new admin
	if !h.isAdmin(in.AdminNIM) {
		writeError(w, r, http.StatusForbidden, "bukan admin")
		return
	}

	if strings.TrimSpace(in.NewNIM) == "" {
		writeError(w, r, http.StatusBadRequest, "NIM baru wajib diisi")
		return
	}

	nama := strings.TrimSpace(in.NewNama)
	if nama == "" {
		nama = "Admin"
	}

	_, err := h.DB.Exec(
		`INSERT INTO admin (nim, nama) VALUES ($1, $2) ON CONFLICT (nim) DO NOTHING`,
		strings.TrimSpace(in.NewNIM), nama,
	)
	if err != nil {
		h.Logger.Error("failed to add admin", "error", err)
		writeError(w, r, http.StatusInternalServerError, "gagal menambahkan admin")
		return
	}

	writeSuccess(w, r, map[string]any{
		"message": "Admin berhasil ditambahkan",
		"nim":     in.NewNIM,
	})
}

// isAdmin checks if a NIM exists in the admin table.
func (h *Handler) isAdmin(nim string) bool {
	if h.DB == nil || strings.TrimSpace(nim) == "" {
		return false
	}
	var exists bool
	err := h.DB.QueryRow(`SELECT EXISTS(SELECT 1 FROM admin WHERE nim = $1)`, strings.TrimSpace(nim)).Scan(&exists)
	if err != nil {
		h.Logger.Error("admin check failed", "error", err)
		return false
	}
	return exists
}

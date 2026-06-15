package handler

import (
	"net/http"
	"strconv"
	"strings"
	"time"
)

// --- Request/Response types ---

// AspirasiSubmitInput is the JSON body for submitting an aspirasi.
type AspirasiSubmitInput struct {
	NIM      string `json:"nim"`
	Nama     string `json:"nama"`
	Semester string `json:"semester"`
	Jurusan  string `json:"jurusan"`
	Sasaran  string `json:"sasaran"`
	Kritik   string `json:"kritik"`
	Saran    string `json:"saran"`
	IsAnonim bool   `json:"is_anonim"`
}

// AspirasiItem is a single aspirasi for API responses.
type AspirasiItem struct {
	ID        int       `json:"id"`
	NIM       string    `json:"nim,omitempty"`
	Nama      string    `json:"nama,omitempty"`
	Semester  string    `json:"semester,omitempty"`
	Jurusan   string    `json:"jurusan,omitempty"`
	Sasaran   string    `json:"sasaran"`
	Kritik    string    `json:"kritik"`
	Saran     string    `json:"saran"`
	IsAnonim   bool      `json:"is_anonim"`
	Status     string    `json:"status"`
	AdminReply string    `json:"admin_reply"`
	CreatedAt  time.Time `json:"created_at"`
}

// HandleAspirasiSubmit handles POST /api/aspirasi/submit
func (h *Handler) HandleAspirasiSubmit(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in AspirasiSubmitInput
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	// Validation
	if strings.TrimSpace(in.NIM) == "" || strings.TrimSpace(in.Nama) == "" {
		writeError(w, r, http.StatusBadRequest, "nim dan nama wajib diisi")
		return
	}
	if strings.TrimSpace(in.Sasaran) == "" {
		writeError(w, r, http.StatusBadRequest, "sasaran kritik wajib diisi")
		return
	}
	if strings.TrimSpace(in.Kritik) == "" {
		writeError(w, r, http.StatusBadRequest, "kritik wajib diisi")
		return
	}
	if strings.TrimSpace(in.Saran) == "" {
		writeError(w, r, http.StatusBadRequest, "saran wajib diisi")
		return
	}

	// If anonim, semester and jurusan should be provided
	if in.IsAnonim && (strings.TrimSpace(in.Semester) == "" || strings.TrimSpace(in.Jurusan) == "") {
		writeError(w, r, http.StatusBadRequest, "semester dan jurusan wajib diisi untuk mode anonim")
		return
	}

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	var id int
	err := h.DB.QueryRow(
		`INSERT INTO aspirasi (nim, nama, semester, jurusan, sasaran, kritik, saran, is_anonim)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		 RETURNING id`,
		in.NIM, in.Nama, in.Semester, in.Jurusan,
		strings.TrimSpace(in.Sasaran), strings.TrimSpace(in.Kritik),
		strings.TrimSpace(in.Saran), in.IsAnonim,
	).Scan(&id)
	if err != nil {
		h.Logger.Error("failed to insert aspirasi", "error", err.Error())
		writeError(w, r, http.StatusInternalServerError, "gagal menyimpan aspirasi")
		return
	}

	writeSuccess(w, r, map[string]any{
		"id":      id,
		"message": "Aspirasi berhasil dikirim!",
	})
}

// HandleAspirasiList handles GET /api/aspirasi/list — public feed
func (h *Handler) HandleAspirasiList(w http.ResponseWriter, r *http.Request) {
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if r.Method != http.MethodGet {
		writeError(w, r, http.StatusMethodNotAllowed, "method not allowed")
		return
	}

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	// Pagination
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit := 20
	offset := (page - 1) * limit

	rows, err := h.DB.Query(
		`SELECT id, nim, nama, semester, jurusan, sasaran, kritik, saran, is_anonim, status, admin_reply, created_at
		 FROM aspirasi
		 ORDER BY created_at DESC
		 LIMIT $1 OFFSET $2`,
		limit, offset,
	)
	if err != nil {
		h.Logger.Error("failed to query aspirasi", "error", err)
		writeError(w, r, http.StatusInternalServerError, "gagal memuat aspirasi")
		return
	}
	defer rows.Close()

	items := make([]AspirasiItem, 0)
	for rows.Next() {
		var a AspirasiItem
		if err := rows.Scan(&a.ID, &a.NIM, &a.Nama, &a.Semester, &a.Jurusan,
			&a.Sasaran, &a.Kritik, &a.Saran, &a.IsAnonim, &a.Status, &a.AdminReply, &a.CreatedAt); err != nil {
			continue
		}
		// For public view: hide identity if anonim
		if a.IsAnonim {
			a.NIM = ""
			a.Nama = "Anonim"
		}
		items = append(items, a)
	}

	// Total count
	var total int
	_ = h.DB.QueryRow(`SELECT COUNT(*) FROM aspirasi`).Scan(&total)

	writeSuccess(w, r, map[string]any{
		"items": items,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

// HandleAspirasiMy handles POST /api/aspirasi/my — user's own submissions
func (h *Handler) HandleAspirasiMy(w http.ResponseWriter, r *http.Request) {
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

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	rows, err := h.DB.Query(
		`SELECT id, nim, nama, semester, jurusan, sasaran, kritik, saran, is_anonim, status, admin_reply, created_at
		 FROM aspirasi WHERE nim = $1
		 ORDER BY created_at DESC`,
		in.NIM,
	)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "gagal memuat aspirasi")
		return
	}
	defer rows.Close()

	items := make([]AspirasiItem, 0)
	for rows.Next() {
		var a AspirasiItem
		if err := rows.Scan(&a.ID, &a.NIM, &a.Nama, &a.Semester, &a.Jurusan,
			&a.Sasaran, &a.Kritik, &a.Saran, &a.IsAnonim, &a.Status, &a.AdminReply, &a.CreatedAt); err != nil {
			continue
		}
		items = append(items, a)
	}

	writeSuccess(w, r, map[string]any{"items": items})
}

// HandleAspirasiAdminList handles POST /api/aspirasi/admin/list — admin sees all with identity
func (h *Handler) HandleAspirasiAdminList(w http.ResponseWriter, r *http.Request) {
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

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	// Verify admin
	if !h.isAdmin(in.NIM) {
		writeError(w, r, http.StatusForbidden, "bukan admin")
		return
	}

	// Pagination
	page, _ := strconv.Atoi(r.URL.Query().Get("page"))
	if page < 1 {
		page = 1
	}
	limit := 50
	offset := (page - 1) * limit

	rows, err := h.DB.Query(
		`SELECT id, nim, nama, semester, jurusan, sasaran, kritik, saran, is_anonim, status, admin_reply, created_at
		 FROM aspirasi
		 ORDER BY created_at DESC
		 LIMIT $1 OFFSET $2`,
		limit, offset,
	)
	if err != nil {
		writeError(w, r, http.StatusInternalServerError, "gagal memuat aspirasi")
		return
	}
	defer rows.Close()

	items := make([]AspirasiItem, 0)
	for rows.Next() {
		var a AspirasiItem
		if err := rows.Scan(&a.ID, &a.NIM, &a.Nama, &a.Semester, &a.Jurusan,
			&a.Sasaran, &a.Kritik, &a.Saran, &a.IsAnonim, &a.Status, &a.AdminReply, &a.CreatedAt); err != nil {
			continue
		}
		// Admin sees everything — no masking
		items = append(items, a)
	}

	var total int
	_ = h.DB.QueryRow(`SELECT COUNT(*) FROM aspirasi`).Scan(&total)

	writeSuccess(w, r, map[string]any{
		"items": items,
		"total": total,
		"page":  page,
		"limit": limit,
	})
}

// HandleAspirasiAdminUpdate handles POST /api/aspirasi/admin/update
func (h *Handler) HandleAspirasiAdminUpdate(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in struct {
		NIM        string `json:"nim"`
		AspirasiID int    `json:"id"`
		Status     string `json:"status"`
		AdminReply string `json:"admin_reply"`
	}
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	// Verify admin
	if !h.isAdmin(in.NIM) {
		writeError(w, r, http.StatusForbidden, "bukan admin")
		return
	}

	_, err := h.DB.Exec(
		`UPDATE aspirasi SET status = $1, admin_reply = $2, updated_at = NOW() WHERE id = $3`,
		in.Status, in.AdminReply, in.AspirasiID,
	)
	if err != nil {
		h.Logger.Error("failed to update aspirasi", "error", err.Error())
		writeError(w, r, http.StatusInternalServerError, "gagal update aspirasi")
		return
	}

	writeSuccess(w, r, map[string]any{"message": "Aspirasi berhasil diupdate!"})
}

// HandleAspirasiDelete handles POST /api/aspirasi/delete
func (h *Handler) HandleAspirasiDelete(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in struct {
		NIM        string `json:"nim"`
		AspirasiID int    `json:"id"`
	}
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	if h.DB == nil {
		writeError(w, r, http.StatusInternalServerError, "database not available")
		return
	}

	// Verify it belongs to the user and is still pending
	res, err := h.DB.Exec(
		`DELETE FROM aspirasi WHERE id = $1 AND nim = $2 AND status = 'pending'`,
		in.AspirasiID, in.NIM,
	)
	if err != nil {
		h.Logger.Error("failed to delete aspirasi", "error", err.Error())
		writeError(w, r, http.StatusInternalServerError, "gagal menghapus aspirasi")
		return
	}

	rowsAffected, _ := res.RowsAffected()
	if rowsAffected == 0 {
		writeError(w, r, http.StatusForbidden, "aspirasi tidak dapat dihapus (sudah diproses atau bukan milik Anda)")
		return
	}

	writeSuccess(w, r, map[string]any{"message": "Aspirasi berhasil dihapus!"})
}

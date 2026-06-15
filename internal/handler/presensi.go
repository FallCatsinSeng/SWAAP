package handler

import (
	"net/http"

	"swaap/internal/smartone"
)

// HandlePresensi handles POST /api/presensi
func (h *Handler) HandlePresensi(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in smartone.PresensiInput
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	client, err := newClient(in.BaseURL, in.Headers, h.Logger)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, err.Error())
		return
	}

	res, err := client.ListPresensi(r.Context(), in)
	if err != nil {
		writeError(w, r, http.StatusBadGateway, err.Error())
		return
	}

	writeSuccess(w, r, res)
}

// HandleAttend handles POST /api/attend
func (h *Handler) HandleAttend(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in smartone.AttendInput
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	client, err := newClient(in.BaseURL, in.Headers, h.Logger)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, err.Error())
		return
	}

	res, err := client.SubmitAttend(r.Context(), in)
	if err != nil {
		writeError(w, r, http.StatusBadGateway, err.Error())
		return
	}

	writeSuccess(w, r, res)
}

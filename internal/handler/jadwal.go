package handler

import (
	"net/http"

	"swaap/internal/smartone"
)

// HandleMenu handles POST /api/menu
func (h *Handler) HandleMenu(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in smartone.MenuInput
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	client, err := newClient(in.BaseURL, in.Headers, h.Logger)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, err.Error())
		return
	}

	if in.Ulang == 0 {
		in.Ulang = 1
	}

	res, err := client.GetMenu(r.Context(), in)
	if err != nil {
		writeError(w, r, http.StatusBadGateway, err.Error())
		return
	}

	writeSuccess(w, r, res)
}

// HandleJadwal handles POST /api/jadwal
func (h *Handler) HandleJadwal(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in smartone.JadwalInput
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	client, err := newClient(in.BaseURL, in.Headers, h.Logger)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, err.Error())
		return
	}

	in.SkipBootstrap = true

	res, err := client.GetJadwal(r.Context(), in)
	if err != nil {
		writeError(w, r, http.StatusBadGateway, err.Error())
		return
	}

	writeSuccess(w, r, res)
}

package handler

import (
	"net/http"

	"swaap/internal/smartone"
)

// HandleLogin handles POST /api/login
func (h *Handler) HandleLogin(w http.ResponseWriter, r *http.Request) {
	if !requirePOST(w, r) {
		return
	}

	var in smartone.LoginInput
	if err := decodeBody(r, &in); err != nil {
		writeError(w, r, http.StatusBadRequest, "invalid JSON body")
		return
	}

	client, err := newClient(in.BaseURL, in.Headers, h.Logger)
	if err != nil {
		writeError(w, r, http.StatusBadRequest, err.Error())
		return
	}

	res, err := client.Login(r.Context(), in)
	if err != nil {
		writeError(w, r, http.StatusBadGateway, err.Error())
		return
	}

	writeSuccess(w, r, res)
}

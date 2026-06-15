package smartone

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
)

// Login authenticates against the SmartOne portal.
func (c *Client) Login(ctx context.Context, in LoginInput) (*LoginResult, error) {
	if strings.TrimSpace(in.Username) == "" || strings.TrimSpace(in.Password) == "" {
		return nil, errors.New("username and password are required")
	}

	loginPath := withDefaultPath(in.LoginPath, defaultLoginPath)
	refererPath := withDefaultPath(in.RefererPath, defaultReferer)

	if !in.SkipWarmup {
		warmupChain := []string{
			"/swu.php",
			"/my_school.php?ada=2&sof=0&ol=0&hp=1&template=0",
			"/my_school_ok.php?benarinput=0&ada=2&sof=0&ol=0&hp=1&template=0",
			"/my_school_run.php?ada=2&sof=0&ol=0&hp=1&template=0",
			"/smart_school_biasa_2019.php",
		}
		for _, path := range warmupChain {
			c.logger.Debug("warmup step", "path", path)
			if err := c.warmup(ctx, path, in.Headers, in.UserAgent, in.AcceptLanguage); err != nil {
				c.logger.Warn("warmup step failed", "path", path, "error", err)
			}
		}
		sessID := c.currentPHPSESSID()
		c.logger.Debug("warmup complete", "phpsessid", sessID)
		if sessID == "" {
			return nil, fmt.Errorf("session initialization failed: no PHPSESSID obtained after visiting warmup chain")
		}
	}

	form := url.Values{}
	form.Set("mac_addr", in.MacAddr)
	form.Set("username", in.Username)
	form.Set("password", in.Password)

	c.logger.Debug("login POST", "path", loginPath)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+loginPath, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("build login request: %w", err)
	}
	c.applyHeaders(req, in.Headers, in.UserAgent, in.AcceptLanguage)
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req.Header.Set("Origin", c.baseURL)
	req.Header.Set("Referer", c.baseURL+refererPath)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("send login request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return nil, fmt.Errorf("read login response: %w", err)
	}

	bodyStr := string(body)
	c.logger.Debug("login response", "status", resp.StatusCode, "body_len", len(body))

	if strings.Contains(bodyStr, "tidakterdaftar") {
		return nil, errors.New("login ditolak oleh server (tidakterdaftar). Cek username/password.")
	}
	if strings.Contains(bodyStr, "salahdevice") {
		return nil, errors.New("login ditolak oleh server (salahdevice). Server menolak device ini.")
	}

	phpsessid := c.findPHPSESSID(resp)
	if phpsessid == "" {
		phpsessid = c.currentPHPSESSID()
	}
	if phpsessid == "" {
		return nil, errors.New("login response received but PHPSESSID not found")
	}

	pfx := phpsessid
	if len(pfx) > 8 {
		pfx = pfx[:8]
	}
	c.logger.Info("login success", "phpsessid_prefix", pfx)

	return &LoginResult{
		StatusCode:   resp.StatusCode,
		PHPSESSID:    phpsessid,
		SetCookie:    resp.Header.Values("Set-Cookie"),
		CookieHeader: "PHPSESSID=" + phpsessid,
		BodyPreview:  trimPreview(bodyStr, 700),
	}, nil
}

// GetMenu fetches the menu page.
func (c *Client) GetMenu(ctx context.Context, in MenuInput) (*MenuResult, error) {
	menuPath := withDefaultPath(in.MenuPath, defaultMenuPath)
	q := url.Values{}
	q.Set("ulang", fmt.Sprintf("%d", in.Ulang))
	q.Set("awal", fmt.Sprintf("%d", in.Awal))

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+menuPath+"?"+q.Encode(), nil)
	if err != nil {
		return nil, fmt.Errorf("build menu request: %w", err)
	}
	c.applyHeaders(req, in.Headers, "", "")
	if strings.TrimSpace(in.PHPSESSID) != "" {
		req.AddCookie(&http.Cookie{Name: "PHPSESSID", Value: in.PHPSESSID})
	}

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("send menu request: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(io.LimitReader(resp.Body, 2<<20))
	if err != nil {
		return nil, fmt.Errorf("read menu response: %w", err)
	}

	return &MenuResult{StatusCode: resp.StatusCode, Body: string(body)}, nil
}

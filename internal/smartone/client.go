// Package smartone provides a client for interacting with the SmartOne academic portal.
package smartone

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
	"time"
)

const (
	DefaultBaseURL          = "https://smartone.smart-service.co.id"
	defaultLoginPath        = "/login_proses.php"
	defaultWarmupPath       = "/my_school_run.php?ada=2"
	fallbackWarmup          = "/my_school.php?ada=2"
	defaultReferer          = "/smart_school_biasa_2019.php"
	defaultMenuPath         = "/my_aplikasi_menu.php"
	defaultJadwalPath       = "/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa_view.php"
	defaultJadwalRef        = "/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa.php?jenis=MHS&param_menu=&ujian=0&ekstra=0"
	defaultSubMenuPath      = "/my_aplikasi_sub_menu.php?asal=S&id=8"
	defaultSiswaProgramPath = "/me_sub_menu_program_siswa.php"
	defaultSiswaProgramID   = 232
)

// Logger defines the interface for structured logging used by the client.
// This avoids a hard dependency on any specific logging package.
type Logger interface {
	Debug(msg string, args ...any)
	Info(msg string, args ...any)
	Warn(msg string, args ...any)
	Error(msg string, args ...any)
}

// nopLogger discards all log output.
type nopLogger struct{}

func (nopLogger) Debug(string, ...any) {}
func (nopLogger) Info(string, ...any)  {}
func (nopLogger) Warn(string, ...any)  {}
func (nopLogger) Error(string, ...any) {}

// Option configures a Client.
type Option func(*Client)

// WithLogger sets the logger for the client.
func WithLogger(l Logger) Option {
	return func(c *Client) {
		if l != nil {
			c.logger = l
		}
	}
}

// WithTimeout sets the HTTP client timeout.
func WithTimeout(d time.Duration) Option {
	return func(c *Client) {
		c.httpClient.Timeout = d
	}
}

// Client interacts with the SmartOne academic portal.
// The baseURL is immutable after construction to avoid race conditions.
type Client struct {
	baseURL        string // immutable after NewClient
	httpClient     *http.Client
	defaultHeaders map[string]string
	logger         Logger
}

// NewClient creates a new SmartOne client.
// The baseURL is fixed for the lifetime of the client.
func NewClient(baseURL string, defaultHeaders map[string]string, opts ...Option) (*Client, error) {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = DefaultBaseURL
	}
	if _, err := url.ParseRequestURI(baseURL); err != nil {
		return nil, fmt.Errorf("invalid base_url: %w", err)
	}

	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, fmt.Errorf("create cookie jar: %w", err)
	}

	if defaultHeaders == nil {
		defaultHeaders = map[string]string{}
	}
	if defaultHeaders["Accept"] == "" {
		defaultHeaders["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
	}
	if defaultHeaders["Content-Type"] == "" {
		defaultHeaders["Content-Type"] = "application/x-www-form-urlencoded"
	}

	c := &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Jar:     jar,
		},
		defaultHeaders: defaultHeaders,
		logger:         nopLogger{},
	}

	for _, opt := range opts {
		opt(c)
	}

	return c, nil
}

// BaseURL returns the client's base URL (read-only).
func (c *Client) BaseURL() string {
	return c.baseURL
}

// --- Internal helpers ---

func (c *Client) warmup(ctx context.Context, warmupPath string, headers map[string]string, userAgent, acceptLanguage string) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+warmupPath, nil)
	if err != nil {
		return fmt.Errorf("build warmup request: %w", err)
	}
	c.applyHeaders(req, headers, userAgent, acceptLanguage)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("send warmup request: %w", err)
	}
	defer resp.Body.Close()

	_, _ = io.Copy(io.Discard, io.LimitReader(resp.Body, 1<<20))
	return nil
}

func (c *Client) applyHeaders(req *http.Request, dynamic map[string]string, userAgent, acceptLanguage string) {
	for k, v := range c.defaultHeaders {
		req.Header.Set(k, v)
	}
	for k, v := range dynamic {
		req.Header.Set(k, v)
	}
	if strings.TrimSpace(userAgent) != "" {
		req.Header.Set("User-Agent", userAgent)
	} else if req.Header.Get("User-Agent") == "" {
		req.Header.Set("User-Agent", "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36")
	}
	if strings.TrimSpace(acceptLanguage) != "" {
		req.Header.Set("Accept-Language", acceptLanguage)
	} else if req.Header.Get("Accept-Language") == "" {
		req.Header.Set("Accept-Language", "en-US,en;q=0.9")
	}
}

func (c *Client) applyLegacyNavigateHeaders(req *http.Request) {
	defaults := map[string]string{
		"Upgrade-Insecure-Requests": "1",
		"Sec-Fetch-Site":            "same-origin",
		"Sec-Fetch-Mode":            "navigate",
		"Sec-Fetch-Dest":            "document",
		"Sec-Ch-Ua":                 `"Google Chrome";v="143", "Chromium";v="143", "Not A(Brand";v="24"`,
		"Sec-Ch-Ua-Mobile":          "?1",
		"Sec-Ch-Ua-Platform":        `"Android"`,
		"Priority":                  "u=0, i",
	}
	for k, v := range defaults {
		if req.Header.Get(k) == "" {
			req.Header.Set(k, v)
		}
	}
}

func (c *Client) findPHPSESSID(resp *http.Response) string {
	for _, ck := range resp.Cookies() {
		if strings.EqualFold(ck.Name, "PHPSESSID") {
			return ck.Value
		}
	}

	if v := c.currentPHPSESSID(); v != "" {
		return v
	}

	if resp.Request != nil && resp.Request.URL != nil {
		for _, ck := range c.httpClient.Jar.Cookies(resp.Request.URL) {
			if strings.EqualFold(ck.Name, "PHPSESSID") {
				return ck.Value
			}
		}
	}

	return ""
}

func (c *Client) currentPHPSESSID() string {
	baseURL, err := url.Parse(c.baseURL)
	if err != nil {
		return ""
	}
	for _, ck := range c.httpClient.Jar.Cookies(baseURL) {
		if strings.EqualFold(ck.Name, "PHPSESSID") {
			return ck.Value
		}
	}
	return ""
}

func (c *Client) seedSessionCookie(phpsessid string) {
	phpsessid = strings.TrimSpace(phpsessid)
	if phpsessid == "" || c.httpClient == nil || c.httpClient.Jar == nil {
		return
	}
	baseURL, err := url.Parse(c.baseURL)
	if err != nil {
		return
	}
	c.httpClient.Jar.SetCookies(baseURL, []*http.Cookie{{
		Name:  "PHPSESSID",
		Value: phpsessid,
		Path:  "/",
	}})
}

func (c *Client) addSessionCookie(req *http.Request, phpsessid string) {
	if phpsessid == "" {
		phpsessid = c.currentPHPSESSID()
	}
	if phpsessid != "" {
		req.Header.Set("Cookie", "PHPSESSID="+phpsessid+"; u=0,1")
	} else {
		req.Header.Set("Cookie", "u=0,1")
	}
}

func (c *Client) resolveReferer(input, fallback string) string {
	input = strings.TrimSpace(input)
	if input == "" {
		input = fallback
	}
	l := strings.ToLower(input)
	if strings.HasPrefix(l, "http://") || strings.HasPrefix(l, "https://") {
		return input
	}
	return c.baseURL + withDefaultPath(input, fallback)
}

// fetchHTMLPage fetches an HTML page, following up to 3 client-side redirects.
func (c *Client) fetchHTMLPage(
	ctx context.Context,
	targetURL string,
	referer string,
	phpsessid string,
	headers map[string]string,
) (*fetchHTMLResult, error) {
	currentURL := strings.TrimSpace(targetURL)
	currentReferer := strings.TrimSpace(referer)
	if currentURL == "" {
		return nil, errors.New("empty target URL")
	}
	result := &fetchHTMLResult{
		RedirectChain: []string{currentURL},
	}

	for hop := 0; hop < 3; hop++ {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, currentURL, nil)
		if err != nil {
			return nil, fmt.Errorf("build request for %s: %w", currentURL, err)
		}
		c.applyHeaders(req, headers, "", "")
		c.applyLegacyNavigateHeaders(req)
		if currentReferer != "" {
			req.Header.Set("Referer", currentReferer)
		}
		c.addSessionCookie(req, phpsessid)

		resp, err := c.httpClient.Do(req)
		if err != nil {
			return nil, fmt.Errorf("send request to %s: %w", currentURL, err)
		}

		bodyBytes, err := io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			return nil, fmt.Errorf("read response from %s: %w", currentURL, err)
		}

		result.StatusCode = resp.StatusCode
		result.Body = string(bodyBytes)
		result.FinalURL = currentURL
		result.RequestReferer = currentReferer
		result.ResponseHeaders = flattenResponseHeaders(resp.Header)
		result.ResponseRaw = formatRawHTTPResponse(resp, result.Body)

		nextURL := resolveRelativeURL(currentURL, extractClientRedirectURL(result.Body))
		if nextURL == "" || nextURL == currentURL {
			return result, nil
		}
		currentReferer = currentURL
		currentURL = nextURL
		result.RedirectChain = append(result.RedirectChain, currentURL)
	}

	return result, nil
}

// --- Utility functions ---

func withDefaultPath(path, fallback string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return fallback
	}
	if !strings.HasPrefix(path, "/") {
		return "/" + path
	}
	return path
}

func trimPreview(s string, max int) string {
	s = strings.TrimSpace(s)
	if len(s) <= max {
		return s
	}
	return s[:max] + "..."
}

func isAbsoluteHTTPURL(raw string) bool {
	l := strings.ToLower(strings.TrimSpace(raw))
	return strings.HasPrefix(l, "http://") || strings.HasPrefix(l, "https://")
}

func resolveRelativeURL(baseRaw, refRaw string) string {
	refRaw = strings.TrimSpace(refRaw)
	if refRaw == "" {
		return ""
	}
	if isAbsoluteHTTPURL(refRaw) {
		return refRaw
	}
	baseURL, err := url.Parse(baseRaw)
	if err != nil {
		return ""
	}
	refURL, err := url.Parse(refRaw)
	if err != nil {
		return ""
	}
	return baseURL.ResolveReference(refURL).String()
}

func extractQuery(raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return ""
	}
	return u.RawQuery
}

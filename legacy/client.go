package legacy

import (
	"context"
	"errors"
	"fmt"
	"html"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	defaultBaseURL          = "https://smartone.smart-service.co.id"
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

type Client struct {
	baseURL        string
	httpClient     *http.Client
	defaultHeaders map[string]string
}

type LoginInput struct {
	Username       string            `json:"username"`
	Password       string            `json:"password"`
	MacAddr        string            `json:"mac_addr"`
	BaseURL        string            `json:"base_url"`
	LoginPath      string            `json:"login_path"`
	WarmupPath     string            `json:"warmup_path"`
	RefererPath    string            `json:"referer_path"`
	Headers        map[string]string `json:"headers"`
	SkipWarmup     bool              `json:"skip_warmup"`
	AcceptLanguage string            `json:"accept_language"`
	UserAgent      string            `json:"user_agent"`
}

type LoginResult struct {
	StatusCode   int      `json:"status_code"`
	PHPSESSID    string   `json:"phpsessid"`
	SetCookie    []string `json:"set_cookie"`
	CookieHeader string   `json:"cookie_header"`
	BodyPreview  string   `json:"body_preview"`
}

type MenuInput struct {
	PHPSESSID string            `json:"phpsessid"`
	BaseURL   string            `json:"base_url"`
	MenuPath  string            `json:"menu_path"`
	Ulang     int               `json:"ulang"`
	Awal      int               `json:"awal"`
	Headers   map[string]string `json:"headers"`
}

type MenuResult struct {
	StatusCode int    `json:"status_code"`
	Body       string `json:"body"`
}

type JadwalInput struct {
	PHPSESSID        string            `json:"phpsessid"`
	BaseURL          string            `json:"base_url"`
	Path             string            `json:"path"`
	RefererPath      string            `json:"referer_path"`
	Headers          map[string]string `json:"headers"`
	DebugFullHTML    bool              `json:"debug_full_html"`
	SkipBootstrap    bool              `json:"skip_bootstrap"`
	SubMenuPath      string            `json:"sub_menu_path"`
	SiswaProgramPath string            `json:"siswa_program_path"`
	SiswaProgramID   int               `json:"siswa_program_id"`
}

type JadwalItem struct {
	RowID      int    `json:"row_id"`
	Meeting    string `json:"meeting"`
	Date       string `json:"date"`
	Time       string `json:"time"`
	Room       string `json:"room"`
	Method     string `json:"method"`
	CourseName string `json:"course_name"`
	Lecturer   string `json:"lecturer"`
}

type JadwalResult struct {
	StatusCode   int          `json:"status_code"`
	Body         string       `json:"body"`
	Items        []JadwalItem `json:"items"`
	BodyPreview  string       `json:"body_preview"`
	BootstrapURL string       `json:"bootstrap_url,omitempty"`
	SourceURL    string       `json:"source_url,omitempty"`
	Debug        JadwalDebug  `json:"debug"`
}

type JadwalDebug struct {
	ViewhisCount      int                    `json:"viewhis_count"`
	CourseHeaderCount int                    `json:"course_header_count"`
	MethodInputCount  int                    `json:"method_input_count"`
	HasJadwalKuliah   bool                   `json:"has_jadwal_kuliah"`
	DuplicateCount    int                    `json:"duplicate_count"`
	Candidates        []JadwalCandidateDebug `json:"candidates,omitempty"`
}

type JadwalCandidateDebug struct {
	URL               string   `json:"url"`
	FinalURL          string   `json:"final_url,omitempty"`
	RedirectChain     []string `json:"redirect_chain,omitempty"`
	RequestReferer    string   `json:"request_referer,omitempty"`
	BodyLength        int      `json:"body_len"`
	StatusCode        int      `json:"status_code"`
	ResponseHeaders   []string `json:"response_headers,omitempty"`
	ResponseRaw       string   `json:"response_raw,omitempty"`
	ViewhisCount      int      `json:"viewhis_count"`
	CourseHeaderCount int      `json:"course_header_count"`
	MethodInputCount  int      `json:"method_input_count"`
	HasJadwalKuliah   bool     `json:"has_jadwal_kuliah"`
	ItemCount         int      `json:"item_count"`
	DuplicateCount    int      `json:"duplicate_count"`
	FetchError        string   `json:"fetch_error,omitempty"`
	BodyRaw           string   `json:"body_raw,omitempty"`
}

type fetchHTMLResult struct {
	StatusCode      int
	Body            string
	FinalURL        string
	RequestReferer  string
	ResponseHeaders []string
	RedirectChain   []string
	ResponseRaw     string
}

// ── Presensi (Attendance) types ──

type PresensiInput struct {
	PHPSESSID string            `json:"phpsessid"`
	BaseURL   string            `json:"base_url"`
	Headers   map[string]string `json:"headers"`
}

type PresensiCourse struct {
	IDKrs           int    `json:"id_krs"`
	YangKe          int    `json:"yang_ke"`
	IDJadwal        int    `json:"id_jadwal"`
	NamaMK          string `json:"nama_mk"`
	Perkuliahan     string `json:"perkuliahan"`
	KetPerkuliahan  string `json:"ket_perkuliahan"`
	Hibrid          int    `json:"hibrid"`
	Tanggal         string `json:"tanggal"`
	Jam             string `json:"jam"`
	Hadir           bool   `json:"hadir"`
}

type PresensiResult struct {
	StatusCode int              `json:"status_code"`
	Courses    []PresensiCourse `json:"courses"`
	Message    string           `json:"message,omitempty"`
}

type AttendInput struct {
	PHPSESSID      string            `json:"phpsessid"`
	BaseURL        string            `json:"base_url"`
	IDKrs          int               `json:"id_krs"`
	YangKe         int               `json:"yang_ke"`
	IDJadwal       int               `json:"id_jadwal"`
	NamaMK         string            `json:"nama_mk"`
	Perkuliahan    string            `json:"perkuliahan"`
	KetPerkuliahan string            `json:"ket_perkuliahan"`
	Hibrid         int               `json:"hibrid"`
	Headers        map[string]string `json:"headers"`
}

type AttendResult struct {
	Success    bool   `json:"success"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

func NewClient(baseURL string, defaultHeaders map[string]string) (*Client, error) {
	if strings.TrimSpace(baseURL) == "" {
		baseURL = defaultBaseURL
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

	return &Client{
		baseURL: strings.TrimRight(baseURL, "/"),
		httpClient: &http.Client{
			Timeout: 30 * time.Second,
			Jar:     jar,
		},
		defaultHeaders: defaultHeaders,
	}, nil
}

func (c *Client) Login(ctx context.Context, in LoginInput) (*LoginResult, error) {
	if strings.TrimSpace(in.Username) == "" || strings.TrimSpace(in.Password) == "" {
		return nil, errors.New("username and password are required")
	}

	if strings.TrimSpace(in.BaseURL) != "" {
		c.baseURL = strings.TrimRight(in.BaseURL, "/")
	}
	loginPath := withDefaultPath(in.LoginPath, defaultLoginPath)
	refererPath := withDefaultPath(in.RefererPath, defaultReferer)

	// ── Multi-step session initialization (simulates browser flow) ──
	if !in.SkipWarmup {
		// The PHP server requires visiting these pages IN ORDER to populate
		// $_SESSION variables needed by login_proses.php. Each page uses
		// session_start() and writes different session vars. Skipping any
		// step leaves critical session data empty (sm_id_sekolah, smx_db, etc.).
		warmupChain := []string{
			"/swu.php",
			"/my_school.php?ada=2&sof=0&ol=0&hp=1&template=0",
			"/my_school_ok.php?benarinput=0&ada=2&sof=0&ol=0&hp=1&template=0",
			"/my_school_run.php?ada=2&sof=0&ol=0&hp=1&template=0",
			"/smart_school_biasa_2019.php",
		}

		for _, path := range warmupChain {
			fmt.Printf("[warmup] GET %s\n", path)
			if err := c.warmup(ctx, path, in.Headers, in.UserAgent, in.AcceptLanguage); err != nil {
				fmt.Printf("[warmup]   error: %v\n", err)
			}
		}

		sessID := c.currentPHPSESSID()
		fmt.Printf("[warmup] PHPSESSID after chain: %s\n", sessID)
		if sessID == "" {
			return nil, fmt.Errorf("session initialization failed: no PHPSESSID obtained after visiting warmup chain")
		}
	}

	// ── Build login POST request ──
	form := url.Values{}
	form.Set("mac_addr", in.MacAddr)
	form.Set("username", in.Username)
	form.Set("password", in.Password)
	encoded := form.Encode()
	fmt.Printf("[login] POST %s  body=%s\n", loginPath, encoded)

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+loginPath, strings.NewReader(encoded))
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

	finalPath := ""
	if resp.Request != nil && resp.Request.URL != nil {
		finalPath = resp.Request.URL.Path
	}

	bodyStr := string(body)
	fmt.Printf("[login] status=%d finalPath=%s bodyLen=%d\n", resp.StatusCode, finalPath, len(body))
	fmt.Printf("[login] body preview: %.500s\n", bodyStr)

	if strings.Contains(bodyStr, "tidakterdaftar") {
		return nil, fmt.Errorf("login ditolak oleh server (tidakterdaftar). Cek username/password.")
	}
	if strings.Contains(bodyStr, "salahdevice") {
		return nil, fmt.Errorf("login ditolak oleh server (salahdevice). Server menolak device ini.")
	}

	phpsessid := c.findPHPSESSID(resp)
	if phpsessid == "" {
		// Fallback: use the PHPSESSID from the cookie jar
		phpsessid = c.currentPHPSESSID()
	}
	if phpsessid == "" {
		return nil, errors.New("login response received but PHPSESSID not found")
	}

	fmt.Printf("[login] SUCCESS phpsessid=%s\n", phpsessid)

	return &LoginResult{
		StatusCode:   resp.StatusCode,
		PHPSESSID:    phpsessid,
		SetCookie:    resp.Header.Values("Set-Cookie"),
		CookieHeader: "PHPSESSID=" + phpsessid,
		BodyPreview:  trimPreview(bodyStr, 700),
	}, nil
}

func (c *Client) GetMenu(ctx context.Context, in MenuInput) (*MenuResult, error) {
	if strings.TrimSpace(in.BaseURL) != "" {
		c.baseURL = strings.TrimRight(in.BaseURL, "/")
	}
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

	return &MenuResult{
		StatusCode: resp.StatusCode,
		Body:       string(body),
	}, nil
}

func (c *Client) GetJadwal(ctx context.Context, in JadwalInput) (*JadwalResult, error) {
	if strings.TrimSpace(in.BaseURL) != "" {
		c.baseURL = strings.TrimRight(in.BaseURL, "/")
	}
	c.httpClient.Jar = nil
	path := withDefaultPath(in.Path, defaultJadwalPath)
	referer := c.resolveReferer(in.RefererPath, defaultJadwalRef)

	bootstrapURL := ""
	if !in.SkipBootstrap {
		var err error
		bootstrapURL, err = c.bootstrapJadwalContext(ctx, in)
		if err != nil {
			return nil, err
		}
		if bootstrapURL != "" {
			referer = bootstrapURL
		}
	}

	preReq, err := http.NewRequestWithContext(ctx, http.MethodGet, referer, nil)
	if err == nil {
		c.applyHeaders(preReq, in.Headers, "", "")
		c.applyLegacyNavigateHeaders(preReq)
		c.addSessionCookie(preReq, in.PHPSESSID)
		if preResp, err := c.httpClient.Do(preReq); err == nil {
			fmt.Printf("--- Preflight to %s returned %d ---\n", referer, preResp.StatusCode)
			bodyBytes, _ := io.ReadAll(preResp.Body)
			fmt.Printf("--- PREFLIGHT HTML SNIPPET ---\n%s\n------------------------\n", string(bodyBytes))
			preResp.Body.Close()
		} else {
			fmt.Printf("--- Preflight ERROR: %v ---\n", err)
		}
	}

	candidates := c.buildJadwalCandidates(path, bootstrapURL)
	candidateDebug := make([]JadwalCandidateDebug, 0, len(candidates))
	var best *JadwalResult
	bestScore := -1
	for _, target := range candidates {
		fetched, err := c.fetchHTMLPage(ctx, target, referer, in.PHPSESSID, in.Headers)
		if err != nil {
			candidateDebug = append(candidateDebug, JadwalCandidateDebug{
				URL:        target,
				FetchError: err.Error(),
			})
			continue
		}

		status := fetched.StatusCode
		body := fetched.Body
		rawItems := parseJadwalHTML(body)
		items, duplicateCount := dedupeJadwalItems(rawItems)
		debug := analyzeJadwalHTML(body)
		debug.DuplicateCount = duplicateCount
		cand := JadwalCandidateDebug{
			URL:               target,
			FinalURL:          fetched.FinalURL,
			RedirectChain:     append([]string(nil), fetched.RedirectChain...),
			RequestReferer:    fetched.RequestReferer,
			BodyLength:        len(body),
			StatusCode:        status,
			ResponseHeaders:   append([]string(nil), fetched.ResponseHeaders...),
			ViewhisCount:      debug.ViewhisCount,
			CourseHeaderCount: debug.CourseHeaderCount,
			MethodInputCount:  debug.MethodInputCount,
			HasJadwalKuliah:   debug.HasJadwalKuliah,
			ItemCount:         len(items),
			DuplicateCount:    duplicateCount,
		}
		if in.DebugFullHTML {
			cand.BodyRaw = body
			cand.ResponseRaw = fetched.ResponseRaw
		}
		candidateDebug = append(candidateDebug, cand)
		debug.Candidates = append([]JadwalCandidateDebug(nil), candidateDebug...)
		result := &JadwalResult{
			StatusCode:   status,
			Body:         body,
			Items:        items,
			BodyPreview:  trimPreview(body, 700),
			BootstrapURL: bootstrapURL,
			SourceURL:    target,
			Debug:        debug,
		}

		if len(items) > 0 {
			return result, nil
		}

		score := debug.ViewhisCount + (debug.CourseHeaderCount * 5) + (debug.MethodInputCount * 5)
		if score > bestScore {
			bestScore = score
			best = result
		}
	}

	if best != nil {
		best.Debug.Candidates = append([]JadwalCandidateDebug(nil), candidateDebug...)
		return best, nil
	}
	return nil, errors.New("failed fetching jadwal from all candidates")
}

func (c *Client) bootstrapJadwalContext(ctx context.Context, in JadwalInput) (string, error) {
	c.bootstrapMenuPages(ctx, in.Headers, in.PHPSESSID)

	subMenuPath := withDefaultPath(in.SubMenuPath, defaultSubMenuPath)
	menu0URL := c.baseURL + "/my_aplikasi_menu_0.php?ulang=1"
	subReq, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+subMenuPath, nil)
	if err != nil {
		return "", fmt.Errorf("build jadwal submenu request: %w", err)
	}
	c.applyHeaders(subReq, in.Headers, "", "")
	c.applyLegacyNavigateHeaders(subReq)
	c.addSessionCookie(subReq, in.PHPSESSID)
	subReq.Header.Set("Referer", menu0URL)
	subResp, err := c.httpClient.Do(subReq)
	if err != nil {
		return "", fmt.Errorf("send jadwal submenu request: %w", err)
	}
	defer subResp.Body.Close()
	subMenuBody, err := io.ReadAll(io.LimitReader(subResp.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("read jadwal submenu response: %w", err)
	}

	siswaProgramPath := withDefaultPath(in.SiswaProgramPath, defaultSiswaProgramPath)
	idCandidates := make([]int, 0, 6)
	addID := func(v int) {
		if v <= 0 {
			return
		}
		for _, id := range idCandidates {
			if id == v {
				return
			}
		}
		idCandidates = append(idCandidates, v)
	}
	addID(in.SiswaProgramID)
	for _, v := range extractSiswaProgramIDs(string(subMenuBody)) {
		addID(v)
	}
	addID(defaultSiswaProgramID)

	var bootstrapURL string
	for _, id := range idCandidates {
		bootstrapURL, err = c.requestBootstrapURL(ctx, siswaProgramPath, subMenuPath, id, in.PHPSESSID, in.Headers)
		if err != nil {
			continue
		}
		if bootstrapURL != "" {
			break
		}
	}

	if isAbsoluteHTTPURL(bootstrapURL) {
		preReq, err := http.NewRequestWithContext(ctx, http.MethodGet, bootstrapURL, nil)
		if err == nil {
			c.applyHeaders(preReq, in.Headers, "", "")
			c.applyLegacyNavigateHeaders(preReq)
			c.addSessionCookie(preReq, in.PHPSESSID)
			preReq.Header.Set("Referer", c.baseURL+subMenuPath)
			if preResp, err := c.httpClient.Do(preReq); err == nil {
				_, _ = io.Copy(io.Discard, io.LimitReader(preResp.Body, 1<<20))
				preResp.Body.Close()
			}
		}
	}

	return bootstrapURL, nil
}

func (c *Client) requestBootstrapURL(
	ctx context.Context,
	siswaProgramPath string,
	subMenuPath string,
	id int,
	phpsessid string,
	headers map[string]string,
) (string, error) {
	form := url.Values{}
	form.Set("id", strconv.Itoa(id))

	postReq, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+siswaProgramPath, strings.NewReader(form.Encode()))
	if err != nil {
		return "", fmt.Errorf("build jadwal bootstrap post request: %w", err)
	}
	c.applyHeaders(postReq, headers, "", "")
	c.addSessionCookie(postReq, phpsessid)
	postReq.Header.Set("Content-Type", "application/x-www-form-urlencoded; charset=UTF-8")
	postReq.Header.Set("X-Requested-With", "XMLHttpRequest")
	postReq.Header.Set("Origin", c.baseURL)
	postReq.Header.Set("Referer", c.baseURL+subMenuPath)

	postResp, err := c.httpClient.Do(postReq)
	if err != nil {
		return "", fmt.Errorf("send jadwal bootstrap post request: %w", err)
	}
	defer postResp.Body.Close()

	b, err := io.ReadAll(io.LimitReader(postResp.Body, 1<<20))
	if err != nil {
		return "", fmt.Errorf("read jadwal bootstrap response: %w", err)
	}
	return c.normalizeBootstrapURL(strings.TrimSpace(string(b))), nil
}

func (c *Client) bootstrapMenuPages(ctx context.Context, headers map[string]string, phpsessid string) {
	menuURL := c.baseURL + defaultMenuPath + "?ulang=1"
	subMenuURL := c.baseURL + defaultSubMenuPath
	req1, err := http.NewRequestWithContext(ctx, http.MethodGet, menuURL, nil)
	if err == nil {
		c.applyHeaders(req1, headers, "", "")
		c.applyLegacyNavigateHeaders(req1)
		c.addSessionCookie(req1, phpsessid)
		req1.Header.Set("Referer", subMenuURL)
		if resp1, err := c.httpClient.Do(req1); err == nil {
			_, _ = io.Copy(io.Discard, io.LimitReader(resp1.Body, 1<<20))
			resp1.Body.Close()
		}
	}

	req2, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+"/my_aplikasi_menu_0.php?ulang=1", nil)
	if err == nil {
		c.applyHeaders(req2, headers, "", "")
		c.applyLegacyNavigateHeaders(req2)
		c.addSessionCookie(req2, phpsessid)
		req2.Header.Set("Referer", menuURL)
		if resp2, err := c.httpClient.Do(req2); err == nil {
			_, _ = io.Copy(io.Discard, io.LimitReader(resp2.Body, 1<<20))
			resp2.Body.Close()
		}
	}
}

func (c *Client) normalizeBootstrapURL(raw string) string {
	raw = strings.TrimSpace(strings.Trim(raw, "\"'`"))
	if raw == "" {
		return ""
	}

	l := strings.ToLower(raw)
	if strings.HasPrefix(l, "http://") || strings.HasPrefix(l, "https://") {
		return raw
	}

	// Some legacy responses return only query (e.g. "/?jenis=MHS..."), use known jadwal referer.
	if strings.HasPrefix(raw, "/?") || strings.HasPrefix(raw, "?") {
		return c.baseURL + defaultJadwalRef
	}

	if strings.Contains(raw, "jadwal_ujian_siswa.php?") {
		if strings.HasPrefix(raw, "/") {
			return c.baseURL + raw
		}
		if !strings.Contains(raw, "/") {
			return c.baseURL + "/modul_siswa/jadwal_ujian_siswa/" + raw
		}
	}

	base, berr := url.Parse(c.baseURL + "/")
	ref, rerr := url.Parse(raw)
	if berr == nil && rerr == nil {
		return base.ResolveReference(ref).String()
	}

	if strings.HasPrefix(raw, "/") {
		return c.baseURL + raw
	}
	return c.baseURL + "/" + strings.TrimLeft(raw, "/")
}

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

func (c *Client) buildJadwalCandidates(path string, bootstrapURL string) []string {
	seen := map[string]bool{}
	add := func(out *[]string, u string) {
		u = strings.TrimSpace(u)
		if u == "" || seen[u] {
			return
		}
		seen[u] = true
		*out = append(*out, u)
	}

	out := make([]string, 0, 4)
	add(&out, c.baseURL+path)
	add(&out, bootstrapURL)

	if q := extractQuery(bootstrapURL); q != "" {
		sep := "?"
		if strings.Contains(path, "?") {
			sep = "&"
		}
		add(&out, c.baseURL+path+sep+q)
	}

	if strings.Contains(bootstrapURL, "jadwal_ujian_siswa.php") {
		add(&out, strings.Replace(bootstrapURL, "jadwal_ujian_siswa.php", "jadwal_ujian_siswa_view.php", 1))
	}

	return out
}

func extractQuery(raw string) string {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return ""
	}
	return u.RawQuery
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

func extractSiswaProgramIDs(body string) []int {
	seen := map[int]struct{}{}
	ids := make([]int, 0, 4)
	for _, m := range reRunIntSiswa.FindAllStringSubmatch(body, -1) {
		id, err := strconv.Atoi(m[1])
		if err != nil || id <= 0 {
			continue
		}
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		ids = append(ids, id)
	}
	return ids
}

func extractClientRedirectURL(body string) string {
	for _, re := range reClientRedirects {
		m := re.FindStringSubmatch(body)
		if len(m) >= 2 {
			return strings.TrimSpace(m[1])
		}
	}
	return ""
}

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
	if req.Header.Get("Upgrade-Insecure-Requests") == "" {
		req.Header.Set("Upgrade-Insecure-Requests", "1")
	}
	if req.Header.Get("Sec-Fetch-Site") == "" {
		req.Header.Set("Sec-Fetch-Site", "same-origin")
	}
	if req.Header.Get("Sec-Fetch-Mode") == "" {
		req.Header.Set("Sec-Fetch-Mode", "navigate")
	}
	if req.Header.Get("Sec-Fetch-Dest") == "" {
		req.Header.Set("Sec-Fetch-Dest", "document")
	}
	if req.Header.Get("Sec-Ch-Ua") == "" {
		req.Header.Set("Sec-Ch-Ua", `"Google Chrome";v="143", "Chromium";v="143", "Not A(Brand";v="24"`)
	}
	if req.Header.Get("Sec-Ch-Ua-Mobile") == "" {
		req.Header.Set("Sec-Ch-Ua-Mobile", "?1")
	}
	if req.Header.Get("Sec-Ch-Ua-Platform") == "" {
		req.Header.Set("Sec-Ch-Ua-Platform", `"Android"`)
	}
	if req.Header.Get("Priority") == "" {
		req.Header.Set("Priority", "u=0, i")
	}
}

func flattenResponseHeaders(h http.Header) []string {
	if len(h) == 0 {
		return nil
	}
	keys := make([]string, 0, len(h))
	for k := range h {
		keys = append(keys, k)
	}
	sort.Strings(keys)

	out := make([]string, 0, len(h))
	for _, k := range keys {
		for _, v := range h.Values(k) {
			out = append(out, k+": "+v)
		}
	}
	return out
}

func formatRawHTTPResponse(resp *http.Response, body string) string {
	if resp == nil {
		return body
	}
	proto := resp.Proto
	if proto == "" {
		proto = "HTTP/1.1"
	}
	var b strings.Builder
	b.WriteString(proto)
	b.WriteString(" ")
	b.WriteString(resp.Status)
	b.WriteString("\n")
	for _, line := range flattenResponseHeaders(resp.Header) {
		b.WriteString(line)
		b.WriteString("\n")
	}
	b.WriteString("\n")
	b.WriteString(body)
	return b.String()
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

func (c *Client) resolveWarmupCandidates(input string) []string {
	if strings.TrimSpace(input) != "" {
		return []string{withDefaultPath(input, defaultWarmupPath)}
	}
	return []string{
		defaultWarmupPath,
		fallbackWarmup,
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

// ── Presensi (Attendance) ──

var (
	reSoalOnclick         = regexp.MustCompile(`(?is)onclick\s*=\s*["']?soal\((\d+)\)["']?`)
	reHiddenValByID       = regexp.MustCompile(`(?is)id=["']([^"']+)["']\s+value=["']([^"']*)["']`)
	reBoxMenuContent      = regexp.MustCompile(`(?is)<div\s+class=["']box_menu["'][^>]*>(.*?)</div>`)
	reBoxMenuSudahAbsen   = regexp.MustCompile(`(?is)<div\s+class=["']box_menu_sudah_absen["'][^>]*>(.*?)</div>`)
	reHiddenValInBlock    = regexp.MustCompile(`(?is)id=["']([^"']+)["']\s+value=["']([^"']*)["']`)
)

func (c *Client) ListPresensi(ctx context.Context, in PresensiInput) (*PresensiResult, error) {
	if strings.TrimSpace(in.BaseURL) != "" {
		c.baseURL = strings.TrimRight(in.BaseURL, "/")
	}
	c.seedSessionCookie(in.PHPSESSID)

	// Step 1: GET ujian_online_reguler.php to set session vars (sp_ujian=0, etc.)
	initURL := c.baseURL + "/modul_siswa/ujian_online_reguler/ujian_online_reguler.php?ujian=0&ekstra=0&param_menu="
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, initURL, nil)
	if err != nil {
		return nil, fmt.Errorf("build presensi init request: %w", err)
	}
	c.applyHeaders(req, in.Headers, "", "")
	c.addSessionCookie(req, in.PHPSESSID)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("presensi init request: %w", err)
	}
	io.ReadAll(resp.Body)
	resp.Body.Close()

	// Step 2: GET ujian_online_reguler_view.php to list active courses
	viewURL := c.baseURL + "/modul_siswa/ujian_online_reguler/ujian_online_reguler_view.php"
	req2, err := http.NewRequestWithContext(ctx, http.MethodGet, viewURL, nil)
	if err != nil {
		return nil, fmt.Errorf("build presensi view request: %w", err)
	}
	c.applyHeaders(req2, in.Headers, "", "")
	c.addSessionCookie(req2, in.PHPSESSID)
	resp2, err := c.httpClient.Do(req2)
	if err != nil {
		return nil, fmt.Errorf("presensi view request: %w", err)
	}
	bodyBytes, _ := io.ReadAll(resp2.Body)
	resp2.Body.Close()
	body := string(bodyBytes)

	fmt.Printf("[presensi] view status=%d bodyLen=%d\n", resp2.StatusCode, len(body))

	courses := parsePresensiHTML(body)
	msg := ""
	if len(courses) == 0 {
		if strings.Contains(body, "Tidak dalam Masa") {
			msg = "Tidak dalam masa perkuliahan aktif."
		} else if strings.Contains(body, "Tidak Boleh Presensi") {
			msg = "Anda tidak diperbolehkan presensi saat ini."
		} else {
			msg = "Tidak ada mata kuliah aktif saat ini (cek jadwal jam kuliah)."
		}
	}

	return &PresensiResult{
		StatusCode: resp2.StatusCode,
		Courses:    courses,
		Message:    msg,
	}, nil
}

func parsePresensiHTML(body string) []PresensiCourse {
	// Build map of all hidden input values by ID (used for both belum & sudah hadir)
	hiddenVals := map[string]string{}
	for _, m := range reHiddenValByID.FindAllStringSubmatch(body, -1) {
		hiddenVals[m[1]] = m[2]
	}

	courses := make([]PresensiCourse, 0)
	seen := map[int]bool{}

	// Find courses that are NOT yet attended (have onclick="soal(ID)")
	for _, m := range reSoalOnclick.FindAllStringSubmatch(body, -1) {
		idKrs, _ := strconv.Atoi(m[1])
		if idKrs <= 0 || seen[idKrs] {
			continue
		}
		seen[idKrs] = true

		idStr := strconv.Itoa(idKrs)
		yangKe, _ := strconv.Atoi(hiddenVals["yangke_"+idStr])
		idJadwal, _ := strconv.Atoi(hiddenVals["id_jadwal_"+idStr])
		hibrid, _ := strconv.Atoi(hiddenVals["hibrid_"+idStr])

		courses = append(courses, PresensiCourse{
			IDKrs:          idKrs,
			YangKe:         yangKe,
			IDJadwal:       idJadwal,
			NamaMK:         cleanHTMLText(hiddenVals["nm_mk_"+idStr]),
			Perkuliahan:    hiddenVals["perkuliahan_"+idStr],
			KetPerkuliahan: hiddenVals["ket_perkuliahan_"+idStr],
			Hibrid:         hibrid,
			Hadir:          false,
		})
	}

	// Find courses that are ALREADY attended (box_menu_sudah_absen — no onclick soal)
	// The hidden inputs for these are still present in the page even without the onclick.
	// We detect them by looking for the sudah_absen div near their hidden inputs.
	reBlockWithHidden := regexp.MustCompile(`(?is)(<input[^>]+id=["']perkuliahan_(\d+)["'][^>]*>.*?box_menu_sudah_absen)`)
	for _, m := range reBlockWithHidden.FindAllStringSubmatch(body, -1) {
		idKrs, _ := strconv.Atoi(m[2])
		if idKrs <= 0 || seen[idKrs] {
			continue
		}
		seen[idKrs] = true

		idStr := strconv.Itoa(idKrs)
		yangKe, _ := strconv.Atoi(hiddenVals["yangke_"+idStr])
		idJadwal, _ := strconv.Atoi(hiddenVals["id_jadwal_"+idStr])
		hibrid, _ := strconv.Atoi(hiddenVals["hibrid_"+idStr])

		courses = append(courses, PresensiCourse{
			IDKrs:          idKrs,
			YangKe:         yangKe,
			IDJadwal:       idJadwal,
			NamaMK:         cleanHTMLText(hiddenVals["nm_mk_"+idStr]),
			Perkuliahan:    hiddenVals["perkuliahan_"+idStr],
			KetPerkuliahan: hiddenVals["ket_perkuliahan_"+idStr],
			Hibrid:         hibrid,
			Hadir:          true,
		})
	}

	if len(courses) == 0 {
		return nil
	}
	return courses
}

func (c *Client) SubmitAttend(ctx context.Context, in AttendInput) (*AttendResult, error) {
	if strings.TrimSpace(in.BaseURL) != "" {
		c.baseURL = strings.TrimRight(in.BaseURL, "/")
	}
	c.seedSessionCookie(in.PHPSESSID)

	// Step 1: GET ujian_online_reguler.php to ensure sp_ujian session var is set
	initURL := c.baseURL + "/modul_siswa/ujian_online_reguler/ujian_online_reguler.php?ujian=0&ekstra=0&param_menu="
	reqInit, _ := http.NewRequestWithContext(ctx, http.MethodGet, initURL, nil)
	c.applyHeaders(reqInit, in.Headers, "", "")
	c.addSessionCookie(reqInit, in.PHPSESSID)
	respInit, err := c.httpClient.Do(reqInit)
	if err != nil {
		return nil, fmt.Errorf("attend init: %w", err)
	}
	io.ReadAll(respInit.Body)
	respInit.Body.Close()

	// Step 2: POST to daftar_soal_ujian.php to set session vars (sid_krs, syangke, etc.)
	soalURL := c.baseURL + "/modul_siswa/ujian_online_reguler/daftar_soal_ujian.php"
	form := url.Values{}
	form.Set("id_krs", strconv.Itoa(in.IDKrs))
	form.Set("yangke", strconv.Itoa(in.YangKe))
	form.Set("id_jadwal", strconv.Itoa(in.IDJadwal))
	form.Set("mk", in.NamaMK)
	form.Set("perkuliahan", in.Perkuliahan)
	form.Set("ket_perkuliahan", in.KetPerkuliahan)
	form.Set("hibrid", strconv.Itoa(in.Hibrid))

	reqSoal, _ := http.NewRequestWithContext(ctx, http.MethodPost, soalURL, strings.NewReader(form.Encode()))
	reqSoal.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	c.applyHeaders(reqSoal, in.Headers, "", "")
	c.addSessionCookie(reqSoal, in.PHPSESSID)
	respSoal, err := c.httpClient.Do(reqSoal)
	if err != nil {
		return nil, fmt.Errorf("attend set session: %w", err)
	}
	io.ReadAll(respSoal.Body)
	respSoal.Body.Close()
	fmt.Printf("[attend] daftar_soal status=%d\n", respSoal.StatusCode)

	// Step 3: POST to simpan_jawabanhadir.php to submit attendance
	hadirURL := c.baseURL + "/modul_siswa/ujian_online_reguler/simpan_jawabanhadir.php"
	hadirForm := url.Values{}
	hadirForm.Set("ttd_mhs", "")
	hadirForm.Set("bs_clear_mhs", "0")

	reqHadir, _ := http.NewRequestWithContext(ctx, http.MethodPost, hadirURL, strings.NewReader(hadirForm.Encode()))
	reqHadir.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	c.applyHeaders(reqHadir, in.Headers, "", "")
	c.addSessionCookie(reqHadir, in.PHPSESSID)
	reqHadir.Header.Set("Referer", soalURL)

	respHadir, err := c.httpClient.Do(reqHadir)
	if err != nil {
		return nil, fmt.Errorf("attend submit: %w", err)
	}
	hadirBody, _ := io.ReadAll(respHadir.Body)
	respHadir.Body.Close()

	hadirStr := strings.TrimSpace(string(hadirBody))
	fmt.Printf("[attend] simpan_jawabanhadir status=%d body=%s\n", respHadir.StatusCode, hadirStr)

	success := strings.Contains(strings.ToLower(hadirStr), "presensi kehadiran diterima")
	msg := hadirStr
	if success {
		msg = "Presensi kehadiran diterima untuk " + in.NamaMK
	}

	return &AttendResult{
		Success:    success,
		Message:    msg,
		StatusCode: respHadir.StatusCode,
	}, nil
}

var (
	reCourseHeader    = regexp.MustCompile(`(?is)<td[^>]*colspan=["']?4["']?[^>]*>\s*(?:<i[^>]*>.*?</i>\s*&nbsp;?)?\s*([^<|]+?)\s*\|\s*([^<]+?)</td>`)
	reEntryRow        = regexp.MustCompile(`(?is)onclick\s*=\s*["']?viewhis\((\d+)\)\s*;?["']?[^>]*>.*?<i[^>]*>\s*([0-9]+)\.\s*</i>\s*&nbsp;?\s*([^<]+)</a>.*?<label[^>]*>\s*([^<]+)\s*</label>.*?<p[^>]*>\s*([^<]+)\s*</p>`)
	reViewhisClick    = regexp.MustCompile(`(?is)onclick\s*=\s*["']?viewhis\((\d+)\)\s*;?["']?`)
	reMethodByID      = regexp.MustCompile(`(?is)id=["']xket_perkuliahan_(\d+)["']\s+value=["']([^"']*)["']`)
	reRunIntSiswa     = regexp.MustCompile(`(?is)run_int_siswa\((\d+)\)`)
	reTagStripper     = regexp.MustCompile(`(?is)<[^>]+>`)
	reClientRedirects = []*regexp.Regexp{
		// Follow only immediate script redirects, not redirects inside function definitions.
		regexp.MustCompile(`(?is)<script[^>]*>\s*(?:window\.)?location\.replace\(['"]([^'"]+)['"]\)\s*;?\s*</script>`),
		regexp.MustCompile(`(?is)<script[^>]*>\s*window\.location\.href\s*=\s*['"]([^'"]+)['"]\s*;?\s*</script>`),
		regexp.MustCompile(`(?is)<script[^>]*>\s*window\.location\s*=\s*['"]([^'"]+)['"]\s*;?\s*</script>`),
	}
)

type jadwalToken struct {
	pos int
	typ string
	v1  string
	v2  string
}

func parseJadwalHTML(body string) []JadwalItem {
	methodByRow := map[int]string{}
	for _, m := range reMethodByID.FindAllStringSubmatch(body, -1) {
		id, _ := strconv.Atoi(m[1])
		methodByRow[id] = cleanHTMLText(m[2])
	}

	tokens := make([]jadwalToken, 0, 128)
	for _, idx := range reCourseHeader.FindAllStringSubmatchIndex(body, -1) {
		tokens = append(tokens, jadwalToken{
			pos: idx[0],
			typ: "course",
			v1:  cleanHTMLText(body[idx[2]:idx[3]]),
			v2:  cleanHTMLText(body[idx[4]:idx[5]]),
		})
	}
	for _, idx := range reEntryRow.FindAllStringSubmatchIndex(body, -1) {
		tokens = append(tokens, jadwalToken{
			pos: idx[0],
			typ: "entry",
			v1:  body[idx[0]:idx[1]],
		})
	}
	sort.Slice(tokens, func(i, j int) bool { return tokens[i].pos < tokens[j].pos })

	items := make([]JadwalItem, 0, 128)
	currentCourse := ""
	currentLecturer := ""
	for _, t := range tokens {
		if t.typ == "course" {
			currentCourse = t.v1
			currentLecturer = t.v2
			continue
		}
		m := reEntryRow.FindStringSubmatch(t.v1)
		if len(m) != 6 {
			continue
		}
		rowID, _ := strconv.Atoi(m[1])
		items = append(items, JadwalItem{
			RowID:      rowID,
			Meeting:    cleanHTMLText(m[2]),
			Date:       cleanHTMLText(m[3]),
			Time:       cleanHTMLText(m[4]),
			Room:       cleanHTMLText(m[5]),
			Method:     methodByRow[rowID],
			CourseName: currentCourse,
			Lecturer:   currentLecturer,
		})
	}

	return items
}

func dedupeJadwalItems(items []JadwalItem) ([]JadwalItem, int) {
	if len(items) < 2 {
		return items, 0
	}

	out := make([]JadwalItem, 0, len(items))
	seen := make(map[string]struct{}, len(items))
	duplicateCount := 0

	for _, item := range items {
		key := strings.ToLower(strings.Join([]string{
			item.Meeting,
			item.Date,
			item.Time,
			item.Room,
			item.Method,
			item.CourseName,
			item.Lecturer,
		}, "|"))
		if _, exists := seen[key]; exists {
			duplicateCount++
			continue
		}
		seen[key] = struct{}{}
		out = append(out, item)
	}

	return out, duplicateCount
}

func cleanHTMLText(v string) string {
	v = strings.ReplaceAll(v, "&nbsp;", " ")
	v = html.UnescapeString(v)
	v = reTagStripper.ReplaceAllString(v, "")
	return strings.Join(strings.Fields(strings.TrimSpace(v)), " ")
}

func analyzeJadwalHTML(body string) JadwalDebug {
	return JadwalDebug{
		ViewhisCount:      len(reViewhisClick.FindAllStringIndex(body, -1)),
		CourseHeaderCount: len(reCourseHeader.FindAllStringIndex(body, -1)),
		MethodInputCount:  len(reMethodByID.FindAllStringIndex(body, -1)),
		HasJadwalKuliah:   strings.Contains(strings.ToLower(body), strings.ToLower("Jadwal Kuliah")),
	}
}

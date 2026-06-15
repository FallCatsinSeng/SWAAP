package smartone

import (
	"context"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

// GetJadwal fetches the schedule from the portal.
func (c *Client) GetJadwal(ctx context.Context, in JadwalInput) (*JadwalResult, error) {
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

	// Preflight request
	preReq, err := http.NewRequestWithContext(ctx, http.MethodGet, referer, nil)
	if err == nil {
		c.applyHeaders(preReq, in.Headers, "", "")
		c.applyLegacyNavigateHeaders(preReq)
		c.addSessionCookie(preReq, in.PHPSESSID)
		if preResp, err := c.httpClient.Do(preReq); err == nil {
			c.logger.Debug("jadwal preflight", "url", referer, "status", preResp.StatusCode)
			_, _ = io.Copy(io.Discard, io.LimitReader(preResp.Body, 1<<20))
			preResp.Body.Close()
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
			StatusCode:        fetched.StatusCode,
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
			StatusCode:   fetched.StatusCode,
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
	siswaProgramPath, subMenuPath string,
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

func (c *Client) buildJadwalCandidates(path, bootstrapURL string) []string {
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

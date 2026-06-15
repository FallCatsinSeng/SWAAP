package smartone

import (
	"net/http"
	"sort"
	"strings"
)

// --- Login types ---

// LoginInput holds the parameters for a login request.
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

// LoginResult holds the result of a login attempt.
type LoginResult struct {
	StatusCode   int      `json:"status_code"`
	PHPSESSID    string   `json:"phpsessid"`
	SetCookie    []string `json:"set_cookie"`
	CookieHeader string   `json:"cookie_header"`
	BodyPreview  string   `json:"body_preview"`
}

// --- Menu types ---

// MenuInput holds the parameters for fetching the menu page.
type MenuInput struct {
	PHPSESSID string            `json:"phpsessid"`
	BaseURL   string            `json:"base_url"`
	MenuPath  string            `json:"menu_path"`
	Ulang     int               `json:"ulang"`
	Awal      int               `json:"awal"`
	Headers   map[string]string `json:"headers"`
}

// MenuResult holds the result of a menu fetch.
type MenuResult struct {
	StatusCode int    `json:"status_code"`
	Body       string `json:"body"`
}

// --- Jadwal types ---

// JadwalInput holds the parameters for fetching the schedule.
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

// JadwalItem represents a single schedule entry.
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

// JadwalResult holds the result of a schedule fetch.
type JadwalResult struct {
	StatusCode   int          `json:"status_code"`
	Body         string       `json:"body"`
	Items        []JadwalItem `json:"items"`
	BodyPreview  string       `json:"body_preview"`
	BootstrapURL string       `json:"bootstrap_url,omitempty"`
	SourceURL    string       `json:"source_url,omitempty"`
	Debug        JadwalDebug  `json:"debug"`
}

// JadwalDebug holds debug information about the jadwal fetch.
type JadwalDebug struct {
	ViewhisCount      int                    `json:"viewhis_count"`
	CourseHeaderCount int                    `json:"course_header_count"`
	MethodInputCount  int                    `json:"method_input_count"`
	HasJadwalKuliah   bool                   `json:"has_jadwal_kuliah"`
	DuplicateCount    int                    `json:"duplicate_count"`
	Candidates        []JadwalCandidateDebug `json:"candidates,omitempty"`
}

// JadwalCandidateDebug holds debug info for a single candidate URL.
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

// fetchHTMLResult holds the result of fetching an HTML page.
type fetchHTMLResult struct {
	StatusCode      int
	Body            string
	FinalURL        string
	RequestReferer  string
	ResponseHeaders []string
	RedirectChain   []string
	ResponseRaw     string
}

// --- Presensi (Attendance) types ---

// PresensiInput holds the parameters for listing attendance.
type PresensiInput struct {
	PHPSESSID string            `json:"phpsessid"`
	BaseURL   string            `json:"base_url"`
	Headers   map[string]string `json:"headers"`
}

// PresensiCourse represents an active attendance entry for a course.
type PresensiCourse struct {
	IDKrs          int    `json:"id_krs"`
	YangKe         int    `json:"yang_ke"`
	IDJadwal       int    `json:"id_jadwal"`
	NamaMK         string `json:"nama_mk"`
	Perkuliahan    string `json:"perkuliahan"`
	KetPerkuliahan string `json:"ket_perkuliahan"`
	Hibrid         int    `json:"hibrid"`
	Tanggal        string `json:"tanggal"`
	Jam            string `json:"jam"`
	Hadir          bool   `json:"hadir"`
}

// PresensiResult holds the result of a presensi fetch.
type PresensiResult struct {
	StatusCode int              `json:"status_code"`
	Courses    []PresensiCourse `json:"courses"`
	Message    string           `json:"message,omitempty"`
	Nama       string           `json:"nama,omitempty"`
	NIM        string           `json:"nim,omitempty"`
}

// AttendInput holds the parameters for submitting attendance.
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

// AttendResult holds the result of an attendance submission.
type AttendResult struct {
	Success    bool   `json:"success"`
	Message    string `json:"message"`
	StatusCode int    `json:"status_code"`
}

// --- Internal helper types ---

// jadwalToken is used internally for parsing jadwal HTML.
type jadwalToken struct {
	pos int
	typ string
	v1  string
	v2  string
}

// --- Response formatting helpers ---

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

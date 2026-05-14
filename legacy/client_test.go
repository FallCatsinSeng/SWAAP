package legacy

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func TestLoginExtractsPHPSESSIDFromWarmupCookieJar(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/warmup", func(w http.ResponseWriter, r *http.Request) {
		http.SetCookie(w, &http.Cookie{Name: "PHPSESSID", Value: "from-warmup", Path: "/"})
		_, _ = w.Write([]byte("warmup"))
	})
	mux.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		if got := r.Form.Get("username"); got != "demo" {
			t.Fatalf("username mismatch: %s", got)
		}
		if got := r.Form.Get("password"); got != "secret" {
			t.Fatalf("password mismatch: %s", got)
		}
		_, _ = w.Write([]byte("<script>location.replace('my_aplikasi_menu_0.php?ulang=1')</script>"))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	res, err := client.Login(context.Background(), LoginInput{
		Username:   "demo",
		Password:   "secret",
		LoginPath:  "/login",
		WarmupPath: "/warmup",
	})
	if err != nil {
		t.Fatalf("login error: %v", err)
	}

	if res.PHPSESSID != "from-warmup" {
		t.Fatalf("unexpected PHPSESSID: %s", res.PHPSESSID)
	}
	if !strings.Contains(res.CookieHeader, "PHPSESSID=from-warmup") {
		t.Fatalf("cookie header mismatch: %s", res.CookieHeader)
	}
}

func TestLoginWarmupFallbackStillGetsSession(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/swu.php", func(w http.ResponseWriter, r *http.Request) {
		http.NotFound(w, r)
	})
	mux.HandleFunc("/smart_school_biasa_2019.php", func(w http.ResponseWriter, r *http.Request) {
		http.SetCookie(w, &http.Cookie{Name: "PHPSESSID", Value: "from-fallback", Path: "/"})
		_, _ = w.Write([]byte("fallback warmup"))
	})
	mux.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	res, err := client.Login(context.Background(), LoginInput{
		Username:  "demo",
		Password:  "secret",
		LoginPath: "/login",
	})
	if err != nil {
		t.Fatalf("login error: %v", err)
	}
	if res.PHPSESSID != "from-fallback" {
		t.Fatalf("unexpected PHPSESSID: %s", res.PHPSESSID)
	}
}

func TestLoginFailsWhenSessionCookieUnavailable(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/warmup", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("warmup"))
	})
	mux.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	_, err = client.Login(context.Background(), LoginInput{
		Username:   "demo",
		Password:   "secret",
		LoginPath:  "/login",
		WarmupPath: "/warmup",
	})
	if err == nil {
		t.Fatal("expected error but got nil")
	}
	if !strings.Contains(err.Error(), "PHPSESSID not found") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestParseJadwalHTML(t *testing.T) {
	body := `
<td style="background-color:green;color:yellow;text-align:center;" colspan="4">
  <i style="font-size:10px;">#2</i>&nbspMETODOLOGI PENELITIAN | LUTVI RIYANDARI, S.Pd, M.Si
</td>
<input type="hidden" id="xket_perkuliahan_1" value="Luring"/>
<tr style="vertical-align:top;">
  <td style="width:250px;vertical-align:top">
    <a href="#" onclick=viewhis(1)>&nbsp<i style="font-size:10px;color:blue;">1.</i>&nbsp23-02-2026</a>
  </td>
  <td style="width:150px;vertical-align:top">
    <label class="form-control">08.30 - 09.30 WIB</label>
  </td>
  <td style="vertical-align:top">
    <p class="form-control">KB.R.2.1</p>
  </td>
</tr>`

	items := parseJadwalHTML(body)
	if len(items) != 1 {
		t.Fatalf("expected 1 item, got %d", len(items))
	}
	got := items[0]
	if got.RowID != 1 || got.Meeting != "1" || got.Date != "23-02-2026" {
		t.Fatalf("unexpected identity fields: %+v", got)
	}
	if got.Method != "Luring" || got.Time != "08.30 - 09.30 WIB" || got.Room != "KB.R.2.1" {
		t.Fatalf("unexpected schedule detail: %+v", got)
	}
	if got.CourseName != "METODOLOGI PENELITIAN" || got.Lecturer != "LUTVI RIYANDARI, S.Pd, M.Si" {
		t.Fatalf("unexpected course detail: %+v", got)
	}
}

func TestGetJadwalReturnsParsedItems(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/jadwal", func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Referer"); got == "" {
			t.Fatalf("expected referer but empty")
		}
		cookie, err := r.Cookie("PHPSESSID")
		if err != nil {
			t.Fatalf("cookie not found: %v", err)
		}
		if cookie.Value != "sid123" {
			t.Fatalf("unexpected cookie value: %s", cookie.Value)
		}
		_, _ = w.Write([]byte(`
<td colspan="4"><i>#2</i>&nbspMETODOLOGI PENELITIAN | LUTVI RIYANDARI, S.Pd, M.Si</td>
<input type="hidden" id="xket_perkuliahan_1" value="Luring"/>
<a href="#" onclick=viewhis(1)>&nbsp<i>1.</i>&nbsp23-02-2026</a></td><td><label>08.30 - 09.30 WIB</label></td><td><p>KB.R.2.1</p>
`))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	res, err := client.GetJadwal(context.Background(), JadwalInput{
		PHPSESSID:     "sid123",
		Path:          "/jadwal",
		RefererPath:   "/ref",
		SkipBootstrap: true,
	})
	if err != nil {
		t.Fatalf("get jadwal error: %v", err)
	}
	if res.StatusCode != http.StatusOK {
		t.Fatalf("unexpected status code: %d", res.StatusCode)
	}
	if len(res.Items) != 1 {
		t.Fatalf("expected 1 parsed item, got %d", len(res.Items))
	}
}

func TestGetJadwalBootstrapFlow(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/my_aplikasi_sub_menu.php", func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("PHPSESSID")
		if err != nil || cookie.Value != "sid-bootstrap" {
			t.Fatalf("submenu cookie mismatch: %v value=%v", err, cookie)
		}
		_, _ = w.Write([]byte("submenu"))
	})
	mux.HandleFunc("/my_aplikasi_menu.php", func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("PHPSESSID")
		if err != nil || cookie.Value != "sid-bootstrap" {
			t.Fatalf("menu cookie mismatch: %v value=%v", err, cookie)
		}
		_, _ = w.Write([]byte("menu"))
	})
	mux.HandleFunc("/my_aplikasi_menu_0.php", func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("PHPSESSID")
		if err != nil || cookie.Value != "sid-bootstrap" {
			t.Fatalf("menu_0 cookie mismatch: %v value=%v", err, cookie)
		}
		_, _ = w.Write([]byte("menu0"))
	})
	mux.HandleFunc("/me_sub_menu_program_siswa.php", func(w http.ResponseWriter, r *http.Request) {
		if err := r.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		cookie, err := r.Cookie("PHPSESSID")
		if err != nil || cookie.Value != "sid-bootstrap" {
			t.Fatalf("program cookie mismatch: %v value=%v", err, cookie)
		}
		if r.Form.Get("id") != "232" {
			t.Fatalf("unexpected id: %s", r.Form.Get("id"))
		}
		_, _ = w.Write([]byte("http://example.test/bootstrap"))
	})
	mux.HandleFunc("/jadwal", func(w http.ResponseWriter, r *http.Request) {
		if got := r.Header.Get("Referer"); got != "http://example.test/bootstrap" {
			t.Fatalf("unexpected referer: %s", got)
		}
		_, _ = w.Write([]byte(`<td colspan="4">A | B</td>`))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	res, err := client.GetJadwal(context.Background(), JadwalInput{
		Path:      "/jadwal",
		PHPSESSID: "sid-bootstrap",
	})
	if err != nil {
		t.Fatalf("get jadwal error: %v", err)
	}
	if res.BootstrapURL != "http://example.test/bootstrap" {
		t.Fatalf("unexpected bootstrap url: %s", res.BootstrapURL)
	}
}

func TestGetJadwalDeduplicatesByScheduleFields(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/jadwal", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`
<td colspan="4"><i>#29</i>&nbspMOBILE PROGRAMMING LANJUT | SUNARYONO M.Kom</td>
<input type="hidden" id="xket_perkuliahan_1" value="Luring"/>
<a href="#" onclick=viewhis(1)>&nbsp<i>1.</i>&nbsp25-02-2026</a></td><td><label>10.00 - 12.00 WIB</label></td><td><p>KB.R.2.3</p>
<input type="hidden" id="xket_perkuliahan_2" value="Luring"/>
<a href="#" onclick=viewhis(2)>&nbsp<i>1.</i>&nbsp25-02-2026</a></td><td><label>10.00 - 12.00 WIB</label></td><td><p>KB.R.2.3</p>
`))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	res, err := client.GetJadwal(context.Background(), JadwalInput{
		Path:          "/jadwal",
		PHPSESSID:     "sid123",
		SkipBootstrap: true,
	})
	if err != nil {
		t.Fatalf("get jadwal error: %v", err)
	}
	if len(res.Items) != 1 {
		t.Fatalf("expected deduped 1 item, got %d", len(res.Items))
	}
	if res.Debug.DuplicateCount != 1 {
		t.Fatalf("expected duplicate_count=1, got %d", res.Debug.DuplicateCount)
	}
}

func TestGetJadwalDebugFullHTMLToggle(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/jadwal", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`
<td colspan="4"><i>#2</i>&nbspMETODOLOGI PENELITIAN | LUTVI RIYANDARI, S.Pd, M.Si</td>
<input type="hidden" id="xket_perkuliahan_1" value="Luring"/>
<a href="#" onclick=viewhis(1)>&nbsp<i>1.</i>&nbsp23-02-2026</a></td><td><label>08.30 - 09.30 WIB</label></td><td><p>KB.R.2.1</p>
`))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	resNoRaw, err := client.GetJadwal(context.Background(), JadwalInput{
		Path:          "/jadwal",
		PHPSESSID:     "sid123",
		SkipBootstrap: true,
	})
	if err != nil {
		t.Fatalf("get jadwal no raw error: %v", err)
	}
	if len(resNoRaw.Debug.Candidates) == 0 {
		t.Fatalf("expected candidates debug for no-raw mode")
	}
	if resNoRaw.Debug.Candidates[0].BodyRaw != "" {
		t.Fatalf("expected empty body_raw when debug_full_html disabled")
	}
	if resNoRaw.Debug.Candidates[0].ResponseRaw != "" {
		t.Fatalf("expected empty response_raw when debug_full_html disabled")
	}

	resRaw, err := client.GetJadwal(context.Background(), JadwalInput{
		Path:          "/jadwal",
		PHPSESSID:     "sid123",
		SkipBootstrap: true,
		DebugFullHTML: true,
	})
	if err != nil {
		t.Fatalf("get jadwal raw error: %v", err)
	}
	if len(resRaw.Debug.Candidates) == 0 {
		t.Fatalf("expected candidates debug for raw mode")
	}
	if !strings.Contains(resRaw.Debug.Candidates[0].BodyRaw, "onclick=viewhis(1)") {
		t.Fatalf("expected full body_raw when debug_full_html enabled")
	}
	if !strings.Contains(resRaw.Debug.Candidates[0].ResponseRaw, "HTTP/1.1 200 OK") ||
		!strings.Contains(resRaw.Debug.Candidates[0].ResponseRaw, "onclick=viewhis(1)") {
		t.Fatalf("expected full response_raw when debug_full_html enabled")
	}
	if resRaw.Debug.Candidates[0].BodyLength == 0 {
		t.Fatalf("expected body length debug")
	}
}

func TestParseRealJadwalSnapshot(t *testing.T) {
	raw, err := os.ReadFile("../scrap/jadwal.md")
	if err != nil {
		t.Fatalf("read snapshot: %v", err)
	}

	items := parseJadwalHTML(string(raw))
	if len(items) == 0 {
		t.Fatalf("expected parsed items from snapshot, got 0")
	}

	deduped, duplicates := dedupeJadwalItems(items)
	if len(deduped) == 0 {
		t.Fatalf("expected deduped items from snapshot, got 0")
	}
	if duplicates == 0 {
		t.Fatalf("expected duplicate entries in snapshot, got 0")
	}
}

func TestExtractSiswaProgramIDs(t *testing.T) {
	body := `
<a href="#" onclick="run_int_siswa(232)">Jadwal Kuliah</a>
<a href="#" onclick="run_int_siswa(245)">Jadwal UAS</a>
<a href="#" onclick="run_int_siswa(232)">Dupe</a>
`
	ids := extractSiswaProgramIDs(body)
	if len(ids) != 2 {
		t.Fatalf("unexpected ids len: %d (%v)", len(ids), ids)
	}
	if ids[0] != 232 || ids[1] != 245 {
		t.Fatalf("unexpected ids order/value: %v", ids)
	}
}

func TestFetchHTMLPageFollowsClientRedirect(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/from", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`<script>location.replace('/to')</script>`))
	})
	mux.HandleFunc("/to", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`<td colspan="4">A | B</td><a onclick=viewhis(1)>x</a>`))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	fetched, err := client.fetchHTMLPage(context.Background(), server.URL+"/from", server.URL+"/ref", "sid123", nil)
	if err != nil {
		t.Fatalf("fetch html page error: %v", err)
	}
	if fetched.StatusCode != http.StatusOK {
		t.Fatalf("unexpected status code: %d", fetched.StatusCode)
	}
	if !strings.Contains(fetched.Body, "viewhis(1)") {
		t.Fatalf("expected redirected body, got: %s", fetched.Body)
	}
	if fetched.FinalURL != server.URL+"/to" {
		t.Fatalf("unexpected final url: %s", fetched.FinalURL)
	}
	if len(fetched.RedirectChain) != 2 {
		t.Fatalf("unexpected redirect chain: %v", fetched.RedirectChain)
	}
}

func TestFetchHTMLPageIgnoresFunctionScopedRedirect(t *testing.T) {
	mux := http.NewServeMux()
	mux.HandleFunc("/from", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`
<html><head>
<script type="text/javascript">
function kembaliRow1() { location.replace('/menu'); }
</script>
</head><body>
<td colspan="4"><i>#2</i>&nbspMETODOLOGI PENELITIAN | LUTVI RIYANDARI, S.Pd, M.Si</td>
<input type="hidden" id="xket_perkuliahan_1" value="Luring"/>
<a href="#" onclick=viewhis(1)>&nbsp<i>1.</i>&nbsp23-02-2026</a></td><td><label>08.30 - 09.30 WIB</label></td><td><p>KB.R.2.1</p>
</body></html>
`))
	})
	mux.HandleFunc("/menu", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte(`MENU`))
	})
	server := httptest.NewServer(mux)
	defer server.Close()

	client, err := NewClient(server.URL, nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}

	fetched, err := client.fetchHTMLPage(context.Background(), server.URL+"/from", server.URL+"/ref", "sid123", nil)
	if err != nil {
		t.Fatalf("fetch html page error: %v", err)
	}
	if fetched.FinalURL != server.URL+"/from" {
		t.Fatalf("should not follow function-scoped redirect, final=%s chain=%v", fetched.FinalURL, fetched.RedirectChain)
	}
	if len(fetched.RedirectChain) != 1 {
		t.Fatalf("unexpected redirect chain: %v", fetched.RedirectChain)
	}
	if !strings.Contains(fetched.Body, "viewhis(1)") {
		t.Fatalf("expected jadwal body, got: %s", fetched.Body)
	}
}

func TestNormalizeBootstrapURLWithQueryOnly(t *testing.T) {
	client, err := NewClient("https://smartone.smart-service.co.id", nil)
	if err != nil {
		t.Fatalf("new client: %v", err)
	}
	got := client.normalizeBootstrapURL("/?jenis=MHS&param_menu=&ujian=&ekstra=")
	want := "https://smartone.smart-service.co.id" + defaultJadwalRef
	if got != want {
		t.Fatalf("unexpected normalized url: got=%s want=%s", got, want)
	}
}

package smartone

import (
	"html"
	"regexp"
	"sort"
	"strconv"
	"strings"
)

// Compiled regex patterns for HTML parsing.
var (
	reSoalOnclick       = regexp.MustCompile(`(?is)onclick\s*=\s*["']?soal\((\d+)\)["']?`)
	reHiddenValByID     = regexp.MustCompile(`(?is)id=["']([^"']+)["']\s+value=["']([^"']*)["']`)
	reBoxMenuContent    = regexp.MustCompile(`(?is)<div\s+class=["']box_menu["'][^>]*>(.*?)</div>`)
	reBoxMenuSudahAbsen = regexp.MustCompile(`(?is)<div\s+class=["']box_menu_sudah_absen["'][^>]*>(.*?)</div>`)
	reHiddenValInBlock  = regexp.MustCompile(`(?is)id=["']([^"']+)["']\s+value=["']([^"']*)["']`)

	reCourseHeader   = regexp.MustCompile(`(?is)<td[^>]*colspan=["']?4["']?[^>]*>\s*(?:<i[^>]*>.*?</i>\s*&nbsp;?)?\s*([^<|]+?)\s*\|\s*([^<]+?)</td>`)
	reEntryRow       = regexp.MustCompile(`(?is)onclick\s*=\s*["']?viewhis\((\d+)\)\s*;?["']?[^>]*>.*?<i[^>]*>\s*([0-9]+)\.\s*</i>\s*&nbsp;?\s*([^<]+)</a>.*?<label[^>]*>\s*([^<]+)\s*</label>.*?<p[^>]*>\s*([^<]+)\s*</p>`)
	reViewhisClick   = regexp.MustCompile(`(?is)onclick\s*=\s*["']?viewhis\((\d+)\)\s*;?["']?`)
	reMethodByID     = regexp.MustCompile(`(?is)id=["']xket_perkuliahan_(\d+)["']\s+value=["']([^"']*)["']`)
	reRunIntSiswa    = regexp.MustCompile(`(?is)run_int_siswa\((\d+)\)`)
	reTagStripper    = regexp.MustCompile(`(?is)<[^>]+>`)

	reClientRedirects = []*regexp.Regexp{
		// Follow only immediate script redirects, not redirects inside function definitions.
		regexp.MustCompile(`(?is)<script[^>]*>\s*(?:window\.)?location\.replace\(['"]([^'"]+)['"]\)\s*;?\s*</script>`),
		regexp.MustCompile(`(?is)<script[^>]*>\s*window\.location\.href\s*=\s*['"]([^'"]+)['"]\s*;?\s*</script>`),
		regexp.MustCompile(`(?is)<script[^>]*>\s*window\.location\s*=\s*['"]([^'"]+)['"]\s*;?\s*</script>`),
	}
)

// parseJadwalHTML extracts schedule items from the jadwal HTML body.
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

// dedupeJadwalItems removes duplicate schedule items based on content.
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

// analyzeJadwalHTML returns debug metrics about the jadwal HTML.
func analyzeJadwalHTML(body string) JadwalDebug {
	return JadwalDebug{
		ViewhisCount:      len(reViewhisClick.FindAllStringIndex(body, -1)),
		CourseHeaderCount: len(reCourseHeader.FindAllStringIndex(body, -1)),
		MethodInputCount:  len(reMethodByID.FindAllStringIndex(body, -1)),
		HasJadwalKuliah:   strings.Contains(strings.ToLower(body), strings.ToLower("Jadwal Kuliah")),
	}
}

// parsePresensiHTML extracts course attendance entries from the presensi HTML body.
func parsePresensiHTML(body string) []PresensiCourse {
	// Build map of all hidden input values by ID
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

	// Find courses that are ALREADY attended (box_menu_sudah_absen)
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

// parseNamaNIM extracts student name and NIM from the presensi HTML.
func parseNamaNIM(body string) (nama, nim string) {
	patterns := []*regexp.Regexp{
		// Pattern 1: matches directly from smain_judul structure
		regexp.MustCompile(`(?is)background-color:\s*lightgreen[^>]*>[\s\S]*?<[Bb][Rr]\s*/?>[\s\S]*?<[Bb][Rr]\s*/?>\s*([^|<\r\n]+?)\s*\|\s*([A-Z0-9]+)\s*<[Bb][Rr]`),
		// Pattern 2: simpler - find "SomeName | ALPHANUMCODE" anywhere in body
		regexp.MustCompile(`(?m)>\s*([A-Za-z][^|<\r\n]{3,50}?)\s*\|\s*([A-Z]{2,5}\d{6,12})\s*<`),
	}
	for _, re := range patterns {
		if m := re.FindStringSubmatch(body); len(m) == 3 {
			n := strings.TrimSpace(m[1])
			ni := strings.TrimSpace(m[2])
			if n != "" && ni != "" {
				return n, ni
			}
		}
	}
	return
}

// extractClientRedirectURL finds a client-side redirect URL in HTML body.
func extractClientRedirectURL(body string) string {
	for _, re := range reClientRedirects {
		m := re.FindStringSubmatch(body)
		if len(m) >= 2 {
			return strings.TrimSpace(m[1])
		}
	}
	return ""
}

// extractSiswaProgramIDs extracts unique program IDs from HTML body.
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

// cleanHTMLText strips HTML tags, unescapes entities, and normalizes whitespace.
func cleanHTMLText(v string) string {
	v = strings.ReplaceAll(v, "&nbsp;", " ")
	v = html.UnescapeString(v)
	v = reTagStripper.ReplaceAllString(v, "")
	return strings.Join(strings.Fields(strings.TrimSpace(v)), " ")
}

package smartone

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
)

// ListPresensi fetches active courses for attendance.
func (c *Client) ListPresensi(ctx context.Context, in PresensiInput) (*PresensiResult, error) {
	c.seedSessionCookie(in.PHPSESSID)

	// Step 1: GET ujian_online_reguler.php to set session vars AND extract student name/NIM
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
	initBodyBytes, _ := io.ReadAll(resp.Body)
	resp.Body.Close()

	initBodyStr := string(initBodyBytes)
	c.logger.Debug("presensi init", "body_len", len(initBodyStr))
	nama, nim := parseNamaNIM(initBodyStr)
	c.logger.Debug("presensi parsed identity", "nama", nama, "nim", nim)

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

	c.logger.Debug("presensi view", "status", resp2.StatusCode, "body_len", len(body))

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

	// Check attendance status for each active course
	for i, course := range courses {
		if course.Hadir {
			continue
		}
		attended := c.checkCourseAttended(ctx, course, in.PHPSESSID, in.Headers)
		if attended {
			courses[i].Hadir = true
			c.logger.Debug("course already attended", "course", course.NamaMK, "id_krs", course.IDKrs)
		}
	}

	return &PresensiResult{
		StatusCode: resp2.StatusCode,
		Courses:    courses,
		Message:    msg,
		Nama:       nama,
		NIM:        nim,
	}, nil
}

// checkCourseAttended POSTs to daftar_soal_ujian.php for a specific course
// and checks if the response indicates the student has already attended.
func (c *Client) checkCourseAttended(ctx context.Context, course PresensiCourse, phpsessid string, headers map[string]string) bool {
	soalURL := c.baseURL + "/modul_siswa/ujian_online_reguler/daftar_soal_ujian.php"
	form := url.Values{}
	form.Set("id_krs", strconv.Itoa(course.IDKrs))
	form.Set("yangke", strconv.Itoa(course.YangKe))
	form.Set("id_jadwal", strconv.Itoa(course.IDJadwal))
	form.Set("mk", course.NamaMK)
	form.Set("perkuliahan", course.Perkuliahan)
	form.Set("ket_perkuliahan", course.KetPerkuliahan)
	form.Set("hibrid", strconv.Itoa(course.Hibrid))

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, soalURL, strings.NewReader(form.Encode()))
	if err != nil {
		return false
	}
	req.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	c.applyHeaders(req, headers, "", "")
	c.addSessionCookie(req, phpsessid)

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return false
	}
	respBody, _ := io.ReadAll(resp.Body)
	resp.Body.Close()

	return strings.Contains(string(respBody), ">Anda Hadir<")
}

// SubmitAttend submits an attendance record for a course.
func (c *Client) SubmitAttend(ctx context.Context, in AttendInput) (*AttendResult, error) {
	c.seedSessionCookie(in.PHPSESSID)

	// Step 1: GET ujian_online_reguler.php to ensure sp_ujian session var is set
	initURL := c.baseURL + "/modul_siswa/ujian_online_reguler/ujian_online_reguler.php?ujian=0&ekstra=0&param_menu="
	reqInit, err := http.NewRequestWithContext(ctx, http.MethodGet, initURL, nil)
	if err != nil {
		return nil, fmt.Errorf("attend init: %w", err)
	}
	c.applyHeaders(reqInit, in.Headers, "", "")
	c.addSessionCookie(reqInit, in.PHPSESSID)
	respInit, err := c.httpClient.Do(reqInit)
	if err != nil {
		return nil, fmt.Errorf("attend init: %w", err)
	}
	_, _ = io.ReadAll(respInit.Body)
	respInit.Body.Close()

	// Step 2: POST to daftar_soal_ujian.php to set session vars
	soalURL := c.baseURL + "/modul_siswa/ujian_online_reguler/daftar_soal_ujian.php"
	form := url.Values{}
	form.Set("id_krs", strconv.Itoa(in.IDKrs))
	form.Set("yangke", strconv.Itoa(in.YangKe))
	form.Set("id_jadwal", strconv.Itoa(in.IDJadwal))
	form.Set("mk", in.NamaMK)
	form.Set("perkuliahan", in.Perkuliahan)
	form.Set("ket_perkuliahan", in.KetPerkuliahan)
	form.Set("hibrid", strconv.Itoa(in.Hibrid))

	reqSoal, err := http.NewRequestWithContext(ctx, http.MethodPost, soalURL, strings.NewReader(form.Encode()))
	if err != nil {
		return nil, fmt.Errorf("attend set session: %w", err)
	}
	reqSoal.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	c.applyHeaders(reqSoal, in.Headers, "", "")
	c.addSessionCookie(reqSoal, in.PHPSESSID)

	respSoal, err := c.httpClient.Do(reqSoal)
	if err != nil {
		return nil, fmt.Errorf("attend set session: %w", err)
	}
	soalBody, _ := io.ReadAll(respSoal.Body)
	respSoal.Body.Close()

	soalStr := string(soalBody)
	c.logger.Debug("attend daftar_soal", "status", respSoal.StatusCode, "body_len", len(soalStr))

	// Check if already attended
	if strings.Contains(soalStr, ">Anda Hadir<") {
		c.logger.Debug("attend skipped — already attended")
		return &AttendResult{
			Success:    true,
			Message:    "Sudah hadir untuk " + in.NamaMK,
			StatusCode: respSoal.StatusCode,
		}, nil
	}

	// Step 3: POST to simpan_jawabanhadir.php to submit attendance
	hadirURL := c.baseURL + "/modul_siswa/ujian_online_reguler/simpan_jawabanhadir.php"
	hadirForm := url.Values{}
	hadirForm.Set("ttd_mhs", "")
	hadirForm.Set("bs_clear_mhs", "0")

	reqHadir, err := http.NewRequestWithContext(ctx, http.MethodPost, hadirURL, strings.NewReader(hadirForm.Encode()))
	if err != nil {
		return nil, fmt.Errorf("attend submit: %w", err)
	}
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
	c.logger.Debug("attend submit", "status", respHadir.StatusCode, "body", hadirStr)

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

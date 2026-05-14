package main

import (
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"strings"
)

func main() {
	jar, _ := cookiejar.New(nil)
	client := &http.Client{Jar: jar}

	ua := "Mozilla/5.0 (Linux; Android 10; SM-G981B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/80.0.3987.162 Mobile Safari/537.36"

	// Step 1: Warmup - visit my_school_run.php to initialize PHP session
	fmt.Println("=== STEP 1: Warmup to my_school_run.php ===")
	warmupURL := "https://smartone.smart-service.co.id/my_school_run.php?ada=2&sof=0&ol=0&hp=1&template=0"
	req, _ := http.NewRequest("GET", warmupURL, nil)
	req.Header.Set("User-Agent", ua)
	resp, err := client.Do(req)
	if err != nil {
		fmt.Println("Warmup error:", err)
		return
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	resp.Body.Close()
	fmt.Printf("Warmup status: %d\n", resp.StatusCode)
	fmt.Printf("Warmup final URL: %s\n", resp.Request.URL.String())

	// Check cookies in jar
	u, _ := url.Parse("https://smartone.smart-service.co.id")
	cookies := jar.Cookies(u)
	fmt.Printf("Cookies after warmup: %v\n", cookies)
	phpsessid := ""
	for _, c := range cookies {
		if c.Name == "PHPSESSID" {
			phpsessid = c.Value
		}
	}
	fmt.Printf("PHPSESSID: %s\n", phpsessid)

	// Check if session was initialized (look for sm_id_sekolah related content)
	bodyStr := string(body)
	if strings.Contains(bodyStr, "login-box") || strings.Contains(bodyStr, "smart_school_biasa") {
		fmt.Println("Warmup HTML contains login form - session likely initialized!")
	}
	if strings.Contains(bodyStr, "salahdevice") {
		fmt.Println("WARNING: salahdevice detected! Device check failed!")
	}
	if strings.Contains(bodyStr, "logout.php") {
		fmt.Println("WARNING: logout redirect detected!")
	}
	// Print first 500 chars of warmup body
	preview := bodyStr
	if len(preview) > 800 {
		preview = preview[:800]
	}
	fmt.Printf("Warmup body preview:\n%s\n\n", preview)

	// Step 2: Visit smart_school_biasa_2019.php (the login page)
	fmt.Println("=== STEP 2: Visit login form page ===")
	loginPageURL := "https://smartone.smart-service.co.id/smart_school_biasa_2019.php"
	req2, _ := http.NewRequest("GET", loginPageURL, nil)
	req2.Header.Set("User-Agent", ua)
	resp2, err := client.Do(req2)
	if err != nil {
		fmt.Println("Login page error:", err)
		return
	}
	body2, _ := io.ReadAll(io.LimitReader(resp2.Body, 1<<20))
	resp2.Body.Close()
	fmt.Printf("Login page status: %d\n", resp2.StatusCode)
	body2Str := string(body2)
	if strings.Contains(body2Str, "mac_addr") {
		fmt.Println("Login page has mac_addr hidden field - GOOD!")
	}
	if strings.Contains(body2Str, "username") {
		fmt.Println("Login page has username field - GOOD!")
	}

	// Step 3: POST login
	fmt.Println("\n=== STEP 3: POST login ===")
	form := url.Values{}
	form.Set("mac_addr", "")
	form.Set("username", "STI202303534")
	form.Set("password", "smartone") // placeholder - won't work with wrong pwd
	
	loginURL := "https://smartone.smart-service.co.id/login_proses.php"
	req3, _ := http.NewRequest("POST", loginURL, strings.NewReader(form.Encode()))
	req3.Header.Set("User-Agent", ua)
	req3.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	req3.Header.Set("Origin", "https://smartone.smart-service.co.id")
	req3.Header.Set("Referer", "https://smartone.smart-service.co.id/smart_school_biasa_2019.php")
	
	resp3, err := client.Do(req3)
	if err != nil {
		fmt.Println("Login error:", err)
		return
	}
	body3, _ := io.ReadAll(io.LimitReader(resp3.Body, 1<<20))
	resp3.Body.Close()
	
	fmt.Printf("Login status: %d\n", resp3.StatusCode)
	fmt.Printf("Login final URL: %s\n", resp3.Request.URL.String())
	
	body3Str := string(body3)
	if strings.Contains(body3Str, "tidakterdaftar") {
		fmt.Println("RESULT: LOGIN FAILED - tidakterdaftar found")
	} else if strings.Contains(body3Str, "content-wrapper") {
		fmt.Println("RESULT: LOGIN SUCCEEDED - dashboard content found!")
	} else {
		fmt.Println("RESULT: UNKNOWN - checking body...")
	}
	
	preview3 := body3Str
	if len(preview3) > 1200 {
		preview3 = preview3[:1200]
	}
	fmt.Printf("Login body preview:\n%s\n", preview3)
}

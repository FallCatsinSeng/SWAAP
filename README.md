# SWAAP Legacy Wrapper (Go + Flutter)

Project ini berisi:
- Wrapper API berbasis Golang untuk login ke web legacy (`/login_proses.php`).
- Ekstraksi `PHPSESSID` dari response headers/cookie jar setelah login.
- Endpoint request lanjutan (`/my_aplikasi_menu.php` dan endpoint jadwal).
- Frontend Flutter dengan alur `Login -> Dashboard Jadwal`.

## 1) Jalankan Go Wrapper

```bash
go run ./cmd/wrapper-api
```

Server aktif di `http://127.0.0.1:8081` (default).

### Endpoint Login

`POST /api/login`

Contoh body:

```json
{
  "base_url": "https://smartone.smart-service.co.id",
  "warmup_path": "/swu.php",
  "referer_path": "/smart_school_biasa_2019.php",
  "username": "STI202303534",
  "password": "75998751",
  "mac_addr": "",
  "accept_language": "en-US,en;q=0.9",
  "user_agent": "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Mobile Safari/537.36"
}
```

Contoh response:

```json
{
  "ok": true,
  "data": {
    "status_code": 200,
    "phpsessid": "eb0t3gul8oa08344r6u5rbgck1",
    "set_cookie": [],
    "cookie_header": "PHPSESSID=eb0t3gul8oa08344r6u5rbgck1",
    "body_preview": "<!DOCTYPE html>..."
  }
}
```

### Endpoint Menu

`POST /api/menu`

```json
{
  "base_url": "https://smartone.smart-service.co.id",
  "phpsessid": "eb0t3gul8oa08344r6u5rbgck1",
  "ulang": 1,
  "awal": 0
}
```

### Endpoint Jadwal

`POST /api/jadwal`

```json
{
  "base_url": "https://smartone.smart-service.co.id",
  "phpsessid": "eb0t3gul8oa08344r6u5rbgck1",
  "path": "/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa_view.php",
  "referer_path": "/modul_siswa/jadwal_ujian_siswa/jadwal_ujian_siswa.php?jenis=MHS&param_menu=&ujian=0&ekstra=0",
  "skip_bootstrap": false,
  "sub_menu_path": "/my_aplikasi_sub_menu.php?asal=S&id=8",
  "siswa_program_path": "/me_sub_menu_program_siswa.php",
  "siswa_program_id": 232
}
```

Response mengembalikan `items` hasil parse HTML jadwal (mata kuliah, dosen, tanggal, jam, ruang, mode), plus `body_preview` dan `bootstrap_url` untuk debugging.

## 2) Pakai sebagai fungsi Go langsung

Contoh fungsi inti ada di [`legacy/client.go`](/media/maulana/01DC6F62F0730460/SWAAP/legacy/client.go).

Flow:
1. `NewClient(...)`
2. `client.Login(...)` -> ambil `result.PHPSESSID`
3. `client.GetMenu(...)` dengan `PHPSESSID`
4. `client.GetJadwal(...)` untuk ambil jadwal terstruktur

## 3) Jalankan Flutter FE

```bash
cd flutter_app
flutter pub get
flutter run
```

Default API URL otomatis:
- Web: `http://localhost:8081`
- Android emulator: `http://10.0.2.2:8081`

## 4) Data intercept tambahan yang mungkin dibutuhkan

Kalau login masih gagal di environment tertentu, biasanya perlu:
1. Raw request/response saat **GET halaman login awal** (yang pertama kali menghasilkan `Set-Cookie: PHPSESSID=...`).
2. Payload saat login gagal (supaya bisa dipakai deteksi sukses/gagal yang lebih akurat).
3. Header anti-bot/CSRF tambahan (kalau ada token tersembunyi di form).

Catatan: default warmup sekarang mencoba `/swu.php` (sesuai flow yang memberi `Set-Cookie: PHPSESSID`), lalu fallback ke `/smart_school_biasa_2019.php`.

## 5) Verifikasi lokal

```bash
go test ./...
```

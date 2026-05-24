# Materi Presentasi: Deploy SWAAP dari Nol hingga HTTPS Aktif

> Panduan lengkap deploy aplikasi SWAAP (Flutter Web + Go API) di VPS kosong,
> menggunakan Docker Compose + Let's Encrypt untuk HTTPS otomatis.

---

## Daftar Isi

1. [Arsitektur Sistem](#1-arsitektur-sistem)
2. [Prasyarat & Kebutuhan](#2-prasyarat--kebutuhan)
3. [Tahap 1 — Sewa & Akses VPS](#3-tahap-1--sewa--akses-vps)
4. [Tahap 2 — Install Docker](#4-tahap-2--install-docker)
5. [Tahap 3 — Setup Domain & DNS](#5-tahap-3--setup-domain--dns)
6. [Tahap 4 — Clone Repository](#6-tahap-4--clone-repository)
7. [Tahap 5 — Jalankan Script Deploy](#7-tahap-5--jalankan-script-deploy)
8. [Tahap 6 — Verifikasi](#8-tahap-6--verifikasi)
9. [Troubleshooting](#9-troubleshooting)
10. [Perintah Berguna](#10-perintah-berguna)
11. [Diagram Alur Deploy](#11-diagram-alur-deploy)

---

## 1. Arsitektur Sistem

```
┌─────────────────────────────────────────────────────────────────┐
│                          INTERNET                                │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │   Domain (DNS)      │
                    │  swaap.example.com  │
                    │  A → IP Server      │
                    └──────────┬──────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                         VPS / SERVER                              │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐  │
│  │              Docker Compose (demo)                          │  │
│  │                                                            │  │
│  │  ┌──────────────────┐     ┌─────────────────────────────┐ │  │
│  │  │  nginx-proxy     │     │  certbot                    │ │  │
│  │  │  Port 80 & 443   │     │  SSL Certificate Manager    │ │  │
│  │  │  HTTPS Terminate │     └─────────────────────────────┘ │  │
│  │  └────────┬─────────┘                                     │  │
│  │           │                                                │  │
│  │           ▼                                                │  │
│  │  ┌──────────────────┐                                     │  │
│  │  │  frontend        │                                     │  │
│  │  │  Flutter Web     │                                     │  │
│  │  │  (Nginx :8080)   │                                     │  │
│  │  │  + /api/ proxy ──┼──────────┐                          │  │
│  │  └──────────────────┘          │                          │  │
│  │                                ▼                          │  │
│  │                       ┌──────────────────┐                │  │
│  │                       │  backend         │                │  │
│  │                       │  Go Wrapper API  │                │  │
│  │                       │  (Port 8081)     │                │  │
│  │                       └──────────────────┘                │  │
│  └────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

### Alur Request

```
User Browser
    │
    ▼ HTTPS (port 443)
nginx-proxy (SSL termination)
    │
    ▼ HTTP (port 8080, internal)
frontend (Flutter Web + Nginx)
    │
    ├── Static files (HTML/JS/CSS) → langsung serve
    │
    └── /api/* requests
            │
            ▼ HTTP (port 8081, internal)
        backend (Go Wrapper API)
```

---

## 2. Prasyarat & Kebutuhan

### Hardware (VPS Minimum)

| Spesifikasi | Minimum | Rekomendasi |
|-------------|---------|-------------|
| CPU | 1 vCPU | 2 vCPU |
| RAM | 1 GB | 2 GB |
| Storage | 20 GB | 40 GB |
| OS | Ubuntu 22.04+ | Ubuntu 24.04 LTS |

### Software yang Akan Diinstall

| Software | Fungsi |
|----------|--------|
| Docker Engine | Container runtime |
| Docker Compose V2 | Orchestrasi multi-container |
| Git | Clone repository |

### Kebutuhan Lain

- **Domain** — bisa beli di Namecheap, Niagahoster, Cloudflare, dll
- **Akses SSH** ke server
- **Port 80 & 443** terbuka

---

## 3. Tahap 1 — Sewa & Akses VPS

### Pilihan Provider VPS Murah

| Provider | Harga Mulai | Catatan |
|----------|-------------|---------|
| DigitalOcean | $4/bulan | Stabil, banyak tutorial |
| Vultr | $3.50/bulan | Banyak lokasi |
| Hetzner | €3.79/bulan | Murah, server EU |
| IDCloudHost | Rp 50rb/bulan | Lokal Indonesia |
| Biznet Gio | Rp 55rb/bulan | Lokal Indonesia |

### Login ke Server

```bash
# Dari laptop/PC kamu
ssh root@IP_SERVER_KAMU

# Contoh:
ssh root@103.123.45.67
```

> **Tips:** Kalau pertama kali, ketik `yes` saat ditanya fingerprint.

### (Opsional) Buat User Non-Root

```bash
# Di server
adduser deploy
usermod -aG sudo deploy

# Logout, lalu login ulang sebagai user baru
ssh deploy@IP_SERVER_KAMU
```

---

## 4. Tahap 2 — Install Docker

### One-Liner Install Docker (Official Script)

```bash
# Install Docker Engine + Docker Compose
curl -fsSL https://get.docker.com | sh

# Tambahkan user ke group docker (supaya ga perlu sudo terus)
sudo usermod -aG docker $USER

# PENTING: Logout dan login ulang supaya group berlaku
exit
# lalu SSH lagi
```

### Verifikasi Instalasi

```bash
docker --version
# Output: Docker version 27.x.x, build xxxxxxx

docker compose version
# Output: Docker Compose version v2.x.x
```

> Kalau kedua command di atas muncul versinya, berarti **sukses**.

---

## 5. Tahap 3 — Setup Domain & DNS

### Langkah-Langkah

1. **Buka dashboard DNS** provider domain kamu (Cloudflare / Namecheap / dll)

2. **Tambahkan A Record:**

   | Type | Name | Value | TTL |
   |------|------|-------|-----|
   | A | swaap | IP_SERVER_KAMU | Auto / 300 |

   Contoh: Kalau domain kamu `example.com` dan mau subdomain `swaap.example.com`:
   - Name: `swaap`
   - Value: `103.123.45.67` (ganti dengan IP VPS kamu)

3. **Tunggu propagasi DNS** (~1-5 menit)

4. **Verifikasi dari terminal:**

```bash
# Dari laptop atau server
ping swaap.example.com

# Harus resolve ke IP server kamu
# PING swaap.example.com (103.123.45.67): 56 data bytes
```

> **PENTING untuk Cloudflare:** Kalau pakai Cloudflare DNS, set Proxy Status ke **DNS Only** (awan abu-abu), bukan Proxied (awan orange). Karena kita handle SSL sendiri.

---

## 6. Tahap 4 — Clone Repository

```bash
# Masuk ke home directory
cd ~

# Clone repository
git clone https://github.com/FallCatsinSeng/SWAAP.git

# Masuk ke folder project
cd SWAAP
```

### Struktur File yang Relevan

```
SWAAP/
├── deploy-demo.sh              ← Script utama (jalankan ini!)
├── docker-compose.demo.yml     ← Compose file alternatif (HTTPS)
├── Dockerfile.backend          ← Build Go API
├── flutter_app/
│   ├── Dockerfile              ← Build Flutter Web
│   └── nginx/nginx.conf        ← Internal nginx config
├── nginx-proxy/
│   ├── nginx.conf              ← Main nginx config
│   └── conf.d/
│       └── default.conf.template  ← Template HTTPS server block
└── cmd/wrapper-api/main.go     ← Source code Go API
```

---

## 7. Tahap 5 — Jalankan Script Deploy

### Buka Firewall (jika belum)

```bash
# UFW (Ubuntu default firewall)
sudo ufw allow 22/tcp    # SSH (jangan sampai ke-lock!)
sudo ufw allow 80/tcp    # HTTP (untuk SSL challenge)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
sudo ufw status
```

### Jalankan Script

```bash
chmod +x deploy-demo.sh
sudo ./deploy-demo.sh
```

### Yang Terjadi di Terminal

```
╔══════════════════════════════════════════════════════════════╗
║           SWAAP Demo Deployment (HTTPS + Domain)            ║
║           Tanpa Cloudflare — pakai Let's Encrypt            ║
╚══════════════════════════════════════════════════════════════╝

[1/6] Mengecek dependencies...
  ✓ Docker & Docker Compose tersedia

[2/6] Masukkan informasi deployment:

  Domain (contoh: swaap.example.com): swaap.example.com     ← KETIK DOMAIN
  Email untuk SSL (contoh: admin@example.com): you@mail.com  ← KETIK EMAIL

  ┌─────────────────────────────────────┐
  │  Domain : swaap.example.com         │
  │  Email  : you@mail.com              │
  └─────────────────────────────────────┘

  Lanjutkan? (y/n): y     ← KETIK y

[3/6] Membuat file .env ...
  ✓ .env berhasil dibuat

[4/6] Membuat konfigurasi Nginx ...
  ✓ Nginx config berhasil di-generate

[5/6] Meminta SSL certificate dari Let's Encrypt ...
  (Pastikan domain swaap.example.com sudah mengarah ke IP server ini!)

  ... Certbot requesting certificate ...
  Congratulations! Your certificate and chain have been saved.

  ✓ SSL certificate berhasil didapatkan!

[6/6] Building & starting semua container ...

  [+] Building frontend ...
  [+] Building backend ...
  [+] Running 4/4
   ✔ Container swaap-backend-1      Started
   ✔ Container swaap-frontend-1     Started
   ✔ Container swaap-nginx-proxy-1  Started
   ✔ Container swaap-certbot-1      Started

╔══════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT BERHASIL!                      ║
║                                                              ║
║  URL    : https://swaap.example.com                         ║
║  Health : https://swaap.example.com/health                  ║
║  API    : https://swaap.example.com/api/...                 ║
║                                                              ║
║  Logs   : docker compose -f docker-compose.demo.yml logs -f ║
║  Stop   : docker compose -f docker-compose.demo.yml down    ║
╚══════════════════════════════════════════════════════════════╝
```

### Estimasi Waktu

| Step | Durasi |
|------|--------|
| Certbot request SSL | 10-30 detik |
| Build Flutter Web (pertama kali) | 3-8 menit |
| Build Go API | 30-60 detik |
| Start containers | 5-10 detik |
| **Total** | **~5-10 menit** |

---

## 8. Tahap 6 — Verifikasi

### Dari Browser

Buka: `https://swaap.example.com`

- ✅ Harus muncul halaman Flutter Web
- ✅ Harus ada gembok hijau (HTTPS valid)
- ✅ Tidak ada warning "Not Secure"

### Cek Health Endpoint

```bash
curl https://swaap.example.com/health
```

Output yang benar:
```json
{"ok":true,"data":{"status":"up"}}
```

### Cek Container Status

```bash
docker compose -f docker-compose.demo.yml ps
```

Output:
```
NAME                    STATUS          PORTS
swaap-backend-1         Up (healthy)    8081/tcp
swaap-frontend-1        Up              8080/tcp
swaap-nginx-proxy-1     Up              0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

### Cek SSL Certificate

```bash
echo | openssl s_client -connect swaap.example.com:443 2>/dev/null | openssl x509 -noout -dates
```

Output:
```
notBefore=May 24 00:00:00 2026 GMT
notAfter=Aug 22 00:00:00 2026 GMT
```

---

## 9. Troubleshooting

### Problem: Certbot Gagal

```
Challenge failed for domain swaap.example.com
```

**Penyebab & Solusi:**

| Penyebab | Solusi |
|----------|--------|
| Domain belum point ke IP server | Cek DNS: `dig swaap.example.com +short` harus tampil IP server |
| Port 80 diblokir firewall | `sudo ufw allow 80/tcp` |
| Ada service lain di port 80 | `sudo lsof -i :80` lalu stop service tsb |
| DNS belum propagasi | Tunggu 5 menit, coba lagi |

### Problem: Flutter Build Error

```
Error: Could not find a file named "pubspec.yaml"
```

**Solusi:** Pastikan kamu di folder root SWAAP (yang ada `flutter_app/` di dalamnya).

### Problem: Backend Crash Loop

```bash
# Cek log backend
docker compose -f docker-compose.demo.yml logs backend
```

**Kalau error `go.mod: no such file`:** pastikan `go.mod` ada di root project.

### Problem: 502 Bad Gateway

**Penyebab:** Frontend belum bisa connect ke backend.

```bash
# Cek apakah backend running
docker compose -f docker-compose.demo.yml logs backend

# Restart semua
docker compose -f docker-compose.demo.yml restart
```

### Problem: HTTPS Redirect Loop

**Penyebab:** Cloudflare proxy masih aktif (awan orange).

**Solusi:** Set DNS record ke **DNS Only** (awan abu-abu) di Cloudflare dashboard.

---

## 10. Perintah Berguna

### Manajemen Container

```bash
# Lihat status semua container
docker compose -f docker-compose.demo.yml ps

# Lihat log (real-time)
docker compose -f docker-compose.demo.yml logs -f

# Lihat log service tertentu
docker compose -f docker-compose.demo.yml logs -f backend
docker compose -f docker-compose.demo.yml logs -f frontend
docker compose -f docker-compose.demo.yml logs -f nginx-proxy

# Restart semua
docker compose -f docker-compose.demo.yml restart

# Stop semua (container tetap ada)
docker compose -f docker-compose.demo.yml stop

# Stop & hapus semua container
docker compose -f docker-compose.demo.yml down

# Rebuild & jalankan ulang
docker compose -f docker-compose.demo.yml up --build -d
```

### SSL Certificate

```bash
# Renew certificate (manual)
docker run --rm \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    -p 80:80 \
    certbot/certbot renew

# Cek expiry date
echo | openssl s_client -connect swaap.example.com:443 2>/dev/null | openssl x509 -noout -dates
```

### Auto-Renew (Cron Job)

```bash
# Buka crontab
sudo crontab -e

# Tambahkan baris ini (renew setiap hari jam 3 pagi):
0 3 * * * cd /root/SWAAP && docker compose -f docker-compose.demo.yml stop nginx-proxy && docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" -v "$(pwd)/certbot/www:/var/www/certbot" -p 80:80 certbot/certbot renew && docker compose -f docker-compose.demo.yml start nginx-proxy
```

### Debugging

```bash
# Masuk ke dalam container
docker compose -f docker-compose.demo.yml exec frontend sh
docker compose -f docker-compose.demo.yml exec nginx-proxy sh

# Cek nginx config valid
docker compose -f docker-compose.demo.yml exec nginx-proxy nginx -t

# Cek disk usage
docker system df

# Bersihkan image/container lama
docker system prune -af
```

---

## 11. Diagram Alur Deploy

```
┌─────────────────────────────────────────────────────────┐
│                    ALUR DEPLOY                           │
└─────────────────────────────────────────────────────────┘

     ┌──────────────┐
     │  Sewa VPS    │  (DigitalOcean / Vultr / dll)
     └──────┬───────┘
            │
            ▼
     ┌──────────────┐
     │  SSH ke VPS  │  ssh root@IP
     └──────┬───────┘
            │
            ▼
     ┌──────────────────┐
     │  Install Docker  │  curl -fsSL https://get.docker.com | sh
     └──────┬───────────┘
            │
            ▼
     ┌──────────────────┐
     │  Setup DNS       │  A record → IP server
     │  (di provider    │
     │   domain)        │
     └──────┬───────────┘
            │
            ▼
     ┌──────────────────┐
     │  Buka Firewall   │  ufw allow 80,443/tcp
     └──────┬───────────┘
            │
            ▼
     ┌──────────────────┐
     │  Clone Repo      │  git clone ...
     └──────┬───────────┘
            │
            ▼
     ┌──────────────────┐
     │  Jalankan Script │  sudo ./deploy-demo.sh
     │                  │
     │  Input:          │
     │  - Domain        │
     │  - Email         │
     └──────┬───────────┘
            │
            │  Script otomatis:
            │  ├─ Generate .env
            │  ├─ Generate nginx config
            │  ├─ Request SSL (Certbot)
            │  └─ docker compose up --build
            │
            ▼
     ┌──────────────────┐
     │  ✅ SELESAI!     │
     │                  │
     │  https://domain  │
     │  langsung aktif  │
     └──────────────────┘
```

---

## Ringkasan: Semua Command dari Awal

Untuk yang mau **copy-paste dari nol**:

```bash
# === DI SERVER (setelah SSH) ===

# 1. Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
exit
# SSH lagi

# 2. Buka firewall
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable

# 3. Clone & deploy
git clone https://github.com/FallCatsinSeng/SWAAP.git
cd SWAAP
chmod +x deploy-demo.sh
sudo ./deploy-demo.sh

# 4. Jawab pertanyaan:
#    - Domain: swaap.example.com
#    - Email: you@mail.com
#    - Lanjutkan? y

# 5. Tunggu ~5-10 menit, selesai!
```

---

## Catatan Tambahan

### Perbedaan dengan Deployment Production (Cloudflare)

| Aspek | Demo (script ini) | Production (asli) |
|-------|-------------------|-------------------|
| SSL | Let's Encrypt (self-managed) | Cloudflare (managed) |
| Proxy | Nginx di VPS | Cloudflare CDN |
| DDoS Protection | Tidak ada | Cloudflare |
| DNS | Langsung ke IP | Cloudflare Proxy |
| Setup | 1 script | Dashboard Cloudflare + token |
| Cocok untuk | Demo / presentasi / dev | Production / live |

### Kapan Pakai Yang Mana?

- **Demo/presentasi** → pakai `deploy-demo.sh` (simpel, langsung jalan)
- **Production/live** → pakai `docker-compose.yml` + Cloudflare Tunnel (lebih aman, DDoS protection)

---

*Dibuat untuk materi presentasi deployment SWAAP.*
*File: `docs/MATERI-DEPLOY.md`*

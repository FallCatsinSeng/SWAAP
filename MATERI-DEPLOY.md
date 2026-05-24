# Materi Deploy SWAAP: Server Kosong → HTTPS Aktif (Full Manual)

> Panduan lengkap **seluruh perintah** deploy SWAAP di VPS kosong.
> Tanpa script `.sh` — semua diketik manual satu per satu di terminal.
> Cocok untuk materi presentasi supaya audience paham setiap prosesnya.

---

## Daftar Isi

1. [Arsitektur Sistem](#1-arsitektur-sistem)
2. [Yang Dibutuhkan](#2-yang-dibutuhkan)
3. [Tahap 1 — SSH ke Server](#3-tahap-1--ssh-ke-server)
4. [Tahap 2 — Update Sistem & Install Git](#4-tahap-2--update-sistem--install-git)
5. [Tahap 3 — Install Docker & Docker Compose](#5-tahap-3--install-docker--docker-compose)
6. [Tahap 4 — Buka Firewall](#6-tahap-4--buka-firewall)
7. [Tahap 5 — Setup Domain (DNS)](#7-tahap-5--setup-domain-dns)
8. [Tahap 6 — Clone Repository](#8-tahap-6--clone-repository)
9. [Tahap 7 — Buat File .env](#9-tahap-7--buat-file-env)
10. [Tahap 8 — Generate Nginx Config dari Template](#10-tahap-8--generate-nginx-config-dari-template)
11. [Tahap 9 — Request SSL Certificate (Certbot)](#11-tahap-9--request-ssl-certificate-certbot)
12. [Tahap 10 — Build & Jalankan Docker Compose](#12-tahap-10--build--jalankan-docker-compose)
13. [Tahap 11 — Verifikasi](#13-tahap-11--verifikasi)
14. [Tahap 12 — Auto-Renew SSL (Cron)](#14-tahap-12--auto-renew-ssl-cron)
15. [Troubleshooting](#15-troubleshooting)
16. [Perintah Manajemen](#16-perintah-manajemen)
17. [Diagram Arsitektur](#17-diagram-arsitektur)

---

## 1. Arsitektur Sistem

```
Internet
    │
    ▼ (port 443 HTTPS)
┌──────────────────────┐
│  nginx-proxy         │  ← SSL termination (Let's Encrypt cert)
│  (port 80 & 443)     │
└──────────┬───────────┘
           │ (internal port 8080)
           ▼
┌──────────────────────┐
│  frontend            │  ← Flutter Web (served by nginx-unprivileged)
│  (port 8080)         │  ← juga proxy /api/* ke backend
└──────────┬───────────┘
           │ (internal port 8081)
           ▼
┌──────────────────────┐
│  backend             │  ← Go Wrapper API
│  (port 8081)         │
└──────────────────────┘
```

---

## 2. Yang Dibutuhkan

| Item | Keterangan |
|------|-----------|
| VPS | Ubuntu 22.04+ (min 1 vCPU, 1GB RAM, 20GB disk) |
| Domain | Sudah dibeli (contoh: `swaap.example.com`) |
| Akses SSH | `ssh root@IP_SERVER` |
| Port 80 & 443 | Harus bisa diakses dari internet |

---

## 3. Tahap 1 — SSH ke Server

Dari laptop/PC kamu, buka terminal:

```bash
ssh root@IP_SERVER_KAMU
```

Contoh:
```bash
ssh root@103.123.45.67
```

> Kalau pertama kali, ketik `yes` saat ditanya fingerprint.

---

## 4. Tahap 2 — Update Sistem & Install Git

```bash
# Update package list
apt update

# Upgrade semua package ke versi terbaru
apt upgrade -y

# Install git
apt install -y git

# Verifikasi git terinstall
git --version
```

Output yang diharapkan:
```
git version 2.xx.x
```

---

## 5. Tahap 3 — Install Docker & Docker Compose

```bash
# Install Docker menggunakan official script
curl -fsSL https://get.docker.com | sh

# Verifikasi Docker
docker --version
```

Output:
```
Docker version 27.x.x, build xxxxxxx
```

```bash
# Verifikasi Docker Compose (sudah include di Docker Engine terbaru)
docker compose version
```

Output:
```
Docker Compose version v2.x.x
```

```bash
# (Opsional) Tambahkan user ke group docker supaya ga perlu sudo terus
# Kalau kamu login sebagai root, langkah ini tidak perlu
usermod -aG docker $USER
```

---

## 6. Tahap 4 — Buka Firewall

```bash
# Install UFW (kalau belum ada)
apt install -y ufw

# Allow SSH (PENTING! Jangan sampai ke-lock dari server sendiri)
ufw allow 22/tcp

# Allow HTTP (dibutuhkan Certbot untuk verifikasi domain)
ufw allow 80/tcp

# Allow HTTPS (traffic utama)
ufw allow 443/tcp

# Aktifkan firewall
ufw enable
```

Akan muncul:
```
Command may disrupt existing SSH connections. Proceed with operation (y|n)? y
Firewall is active and enabled on system startup
```

```bash
# Cek status
ufw status
```

Output:
```
Status: active

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW       Anywhere
80/tcp                     ALLOW       Anywhere
443/tcp                    ALLOW       Anywhere
```

---

## 7. Tahap 5 — Setup Domain (DNS)

**Ini dilakukan di browser, bukan di terminal.**

1. Login ke dashboard DNS provider (Cloudflare / Namecheap / Niagahoster / dll)
2. Tambahkan **A Record**:

| Type | Name | Value | TTL | Proxy |
|------|------|-------|-----|-------|
| A | `swaap` | `IP_SERVER_KAMU` | Auto | ❌ DNS Only (abu-abu) |

> **PENTING:** Kalau pakai Cloudflare, pastikan proxy status = **DNS Only** (awan abu-abu), BUKAN Proxied (awan orange). Karena kita handle SSL sendiri.

3. Kembali ke terminal, verifikasi DNS sudah propagasi:

```bash
# Install dig (kalau belum ada)
apt install -y dnsutils

# Cek apakah domain sudah resolve ke IP server
dig swaap.example.com +short
```

Output yang benar (harus muncul IP server kamu):
```
103.123.45.67
```

> Kalau belum muncul, tunggu 1-5 menit lalu coba lagi.

---

## 8. Tahap 6 — Clone Repository

```bash
# Masuk ke home directory
cd ~

# Clone repository SWAAP
git clone https://github.com/FallCatsinSeng/SWAAP.git

# Masuk ke folder project
cd SWAAP
```

Verifikasi isi folder:
```bash
ls -la
```

Yang penting harus ada:
```
docker-compose.demo.yml
Dockerfile.backend
flutter_app/
nginx-proxy/
```

---

## 9. Tahap 7 — Buat File .env

**Ganti `swaap.example.com` dengan domain kamu yang sebenarnya!**

```bash
cat > .env << 'EOF'
DOMAIN=swaap.example.com
CORS_ORIGIN=https://swaap.example.com
PORT=8081
EOF
```

Verifikasi:
```bash
cat .env
```

Output:
```
DOMAIN=swaap.example.com
CORS_ORIGIN=https://swaap.example.com
PORT=8081
```

---

## 10. Tahap 8 — Generate Nginx Config dari Template

```bash
# Buat folder yang dibutuhkan
mkdir -p nginx-proxy/conf.d
mkdir -p certbot/www
mkdir -p certbot/conf

# Set variable DOMAIN (ganti dengan domain kamu!)
export DOMAIN=swaap.example.com

# Generate nginx config dari template
envsubst '${DOMAIN}' < nginx-proxy/conf.d/default.conf.template > nginx-proxy/conf.d/default.conf
```

Verifikasi hasilnya:
```bash
cat nginx-proxy/conf.d/default.conf
```

Yang harus muncul (domain kamu sudah ter-substitusi):
```nginx
server {
    listen 80;
    server_name swaap.example.com;
    ...
}

server {
    listen 443 ssl;
    server_name swaap.example.com;
    ssl_certificate     /etc/letsencrypt/live/swaap.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/swaap.example.com/privkey.pem;
    ...
}
```

---

## 11. Tahap 9 — Request SSL Certificate (Certbot)

**Ini yang bikin HTTPS aktif.** Certbot akan verifikasi bahwa domain benar-benar mengarah ke server ini, lalu kasih sertifikat SSL gratis.

```bash
# Pastikan tidak ada yang pakai port 80
# (kalau ada error "port already in use", stop dulu service yang pakai port 80)

# Request SSL certificate via Certbot (Docker)
# GANTI email dan domain!
docker run --rm \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    -p 80:80 \
    certbot/certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email EMAILKAMU@gmail.com \
        -d swaap.example.com
```

> **GANTI:**
> - `EMAILKAMU@gmail.com` → email kamu (untuk notifikasi expiry)
> - `swaap.example.com` → domain kamu

Output yang sukses:
```
Requesting a certificate for swaap.example.com
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/swaap.example.com/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/swaap.example.com/privkey.pem
```

Verifikasi file certificate ada:
```bash
ls certbot/conf/live/swaap.example.com/
```

Output:
```
cert.pem  chain.pem  fullchain.pem  privkey.pem  README
```

> **Kalau gagal**, lihat bagian [Troubleshooting](#15-troubleshooting).

---

## 12. Tahap 10 — Build & Jalankan Docker Compose

```bash
# Build semua image dan jalankan container (detached mode)
docker compose -f docker-compose.demo.yml up --build -d
```

Proses ini akan:
1. **Build Go API** dari `Dockerfile.backend` (~30-60 detik)
2. **Build Flutter Web** dari `flutter_app/Dockerfile` (~3-8 menit pertama kali)
3. **Pull image** nginx & certbot (~30 detik)
4. **Start semua container**

Output akhir yang sukses:
```
[+] Running 4/4
 ✔ Network swaap_internal     Created
 ✔ Network swaap_public       Created
 ✔ Container swaap-backend-1      Started
 ✔ Container swaap-frontend-1     Started
 ✔ Container swaap-nginx-proxy-1  Started
 ✔ Container swaap-certbot-1      Started
```

Cek semua container running:
```bash
docker compose -f docker-compose.demo.yml ps
```

Output:
```
NAME                     STATUS    PORTS
swaap-backend-1          Up        8081/tcp
swaap-frontend-1         Up        8080/tcp
swaap-nginx-proxy-1      Up        0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp
```

---

## 13. Tahap 11 — Verifikasi

### A. Cek dari Terminal (curl)

```bash
# Cek HTTPS aktif
curl -I https://swaap.example.com
```

Output yang benar:
```
HTTP/2 200
server: nginx
strict-transport-security: max-age=63072000; includeSubDomains
x-frame-options: DENY
x-content-type-options: nosniff
```

```bash
# Cek health endpoint API
curl https://swaap.example.com/health
```

Output:
```json
{"ok":true,"data":{"status":"up"}}
```

```bash
# Cek HTTP redirect ke HTTPS
curl -I http://swaap.example.com
```

Output (harus redirect 301):
```
HTTP/1.1 301 Moved Permanently
Location: https://swaap.example.com/
```

### B. Cek dari Browser

Buka: `https://swaap.example.com`

Checklist:
- ✅ Halaman Flutter Web muncul
- ✅ Ada gembok hijau / ikon kunci di address bar
- ✅ Tidak ada warning "Not Secure"
- ✅ Certificate info menunjukkan "Let's Encrypt"

### C. Cek SSL Certificate Detail

```bash
echo | openssl s_client -connect swaap.example.com:443 2>/dev/null | openssl x509 -noout -subject -issuer -dates
```

Output:
```
subject=CN = swaap.example.com
issuer=C = US, O = Let's Encrypt, CN = R11
notBefore=May 24 xx:xx:xx 2026 GMT
notAfter=Aug 22 xx:xx:xx 2026 GMT
```

---

## 14. Tahap 12 — Auto-Renew SSL (Cron)

SSL Let's Encrypt expired setiap **90 hari**. Buat auto-renew:

```bash
# Buka crontab editor
crontab -e
```

Kalau ditanya editor, pilih `1` (nano).

Tambahkan baris ini di paling bawah:

```
0 3 1,15 * * cd /root/SWAAP && docker compose -f docker-compose.demo.yml stop nginx-proxy && docker run --rm -v "$(pwd)/certbot/conf:/etc/letsencrypt" -v "$(pwd)/certbot/www:/var/www/certbot" -p 80:80 certbot/certbot renew && docker compose -f docker-compose.demo.yml start nginx-proxy
```

Simpan: `Ctrl+O` → `Enter` → `Ctrl+X`

> Cron ini jalan setiap tanggal 1 dan 15 jam 3 pagi — stop nginx sebentar, renew cert, lalu start lagi.

---

## 15. Troubleshooting

### Certbot Gagal: "Challenge failed"

```bash
# Cek apakah domain resolve ke IP server
dig swaap.example.com +short
# Harus tampil IP server kamu

# Cek apakah port 80 terbuka dari luar
# (jalankan dari laptop, bukan dari server)
curl http://swaap.example.com
# Kalau timeout = port 80 diblokir

# Cek apakah ada service lain di port 80
ss -tlnp | grep :80
# Kalau ada, stop dulu service tsb
```

### Docker Build Gagal: Out of Memory

```bash
# Cek RAM tersedia
free -h

# Kalau RAM < 1GB, buat swap file
fallocate -l 2G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Permanent (supaya tetap ada setelah reboot)
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

Lalu ulangi build:
```bash
docker compose -f docker-compose.demo.yml up --build -d
```

### 502 Bad Gateway

```bash
# Cek log semua service
docker compose -f docker-compose.demo.yml logs

# Cek khusus backend
docker compose -f docker-compose.demo.yml logs backend

# Biasanya backend belum ready, tunggu beberapa detik lalu refresh browser
# Atau restart:
docker compose -f docker-compose.demo.yml restart
```

### Container Exit / Restart Loop

```bash
# Lihat container yang bermasalah
docker compose -f docker-compose.demo.yml ps -a

# Lihat log container yang exit
docker compose -f docker-compose.demo.yml logs --tail=50 backend
```

### Port 80/443 Sudah Dipakai

```bash
# Cek siapa yang pakai port
ss -tlnp | grep ':80\|:443'

# Stop service yang mengganggu (contoh: apache)
systemctl stop apache2
systemctl disable apache2
```

---

## 16. Perintah Manajemen

### Sehari-hari

```bash
# Lihat status container
docker compose -f docker-compose.demo.yml ps

# Lihat log real-time (Ctrl+C untuk keluar)
docker compose -f docker-compose.demo.yml logs -f

# Lihat log service tertentu
docker compose -f docker-compose.demo.yml logs -f backend
docker compose -f docker-compose.demo.yml logs -f frontend
docker compose -f docker-compose.demo.yml logs -f nginx-proxy

# Restart semua
docker compose -f docker-compose.demo.yml restart

# Restart satu service
docker compose -f docker-compose.demo.yml restart backend
```

### Stop & Start

```bash
# Stop semua (container masih ada, tinggal start lagi)
docker compose -f docker-compose.demo.yml stop

# Start lagi
docker compose -f docker-compose.demo.yml start

# Stop & HAPUS semua container + network
docker compose -f docker-compose.demo.yml down
```

### Update / Redeploy

```bash
# Pull kode terbaru
cd ~/SWAAP
git pull

# Rebuild & restart
docker compose -f docker-compose.demo.yml up --build -d
```

### Bersih-bersih

```bash
# Hapus image lama yang tidak terpakai
docker image prune -af

# Hapus semua yang tidak terpakai (image, container, network, cache)
docker system prune -af

# Cek disk usage Docker
docker system df
```

---

## 17. Diagram Arsitektur

```
┌─────────────────────────────────────────────────────────────────┐
│                          INTERNET                                │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                     ┌─────────┴─────────┐
                     │  DNS A Record      │
                     │  swaap.example.com │
                     │  → 103.123.45.67   │
                     └─────────┬─────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────────┐
│                     VPS (103.123.45.67)                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │  Docker Compose (docker-compose.demo.yml)                   │ │
│  │                                                             │ │
│  │  ┌───────────────────────────────────────────────────────┐  │ │
│  │  │  nginx-proxy (nginx:1.27-alpine)                      │  │ │
│  │  │  ├─ Listen :80  → redirect ke HTTPS                  │  │ │
│  │  │  ├─ Listen :443 → SSL termination                    │  │ │
│  │  │  └─ Proxy pass ke frontend:8080                      │  │ │
│  │  └──────────────────────────┬────────────────────────────┘  │ │
│  │                             │                               │ │
│  │                             ▼                               │ │
│  │  ┌───────────────────────────────────────────────────────┐  │ │
│  │  │  frontend (nginx-unprivileged:1.27-alpine)            │  │ │
│  │  │  ├─ Serve Flutter Web (HTML/JS/CSS)                   │  │ │
│  │  │  └─ Proxy /api/* → backend:8081                      │  │ │
│  │  └──────────────────────────┬────────────────────────────┘  │ │
│  │                             │                               │ │
│  │                             ▼                               │ │
│  │  ┌───────────────────────────────────────────────────────┐  │ │
│  │  │  backend (distroless)                                 │  │ │
│  │  │  └─ Go Wrapper API (:8081)                           │  │ │
│  │  └───────────────────────────────────────────────────────┘  │ │
│  │                                                             │ │
│  │  ┌───────────────────────────────────────────────────────┐  │ │
│  │  │  certbot/conf/ (volume)                               │  │ │
│  │  │  └─ SSL certificates (Let's Encrypt)                  │  │ │
│  │  └───────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

---

## Ringkasan: Semua Perintah dari Nol (Tanpa Script)

```bash
# ═══════════════════════════════════════════════════════════════════
# DEPLOY SWAAP — FULL MANUAL (copy-paste satu per satu)
# Ganti "swaap.example.com" dengan domain kamu
# Ganti "103.123.45.67" dengan IP server kamu
# Ganti "email@gmail.com" dengan email kamu
# ═══════════════════════════════════════════════════════════════════

# ── LOGIN ──
ssh root@103.123.45.67

# ── UPDATE & INSTALL GIT ──
apt update && apt upgrade -y
apt install -y git curl

# ── INSTALL DOCKER ──
curl -fsSL https://get.docker.com | sh
docker --version
docker compose version

# ── FIREWALL ──
apt install -y ufw
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable

# ── CLONE REPO ──
cd ~
git clone https://github.com/FallCatsinSeng/SWAAP.git
cd SWAAP

# ── BUAT .env ──
cat > .env << 'EOF'
DOMAIN=swaap.example.com
CORS_ORIGIN=https://swaap.example.com
PORT=8081
EOF

# ── GENERATE NGINX CONFIG ──
mkdir -p nginx-proxy/conf.d certbot/www certbot/conf
export DOMAIN=swaap.example.com
envsubst '${DOMAIN}' < nginx-proxy/conf.d/default.conf.template > nginx-proxy/conf.d/default.conf

# ── REQUEST SSL ──
docker run --rm \
    -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
    -v "$(pwd)/certbot/www:/var/www/certbot" \
    -p 80:80 \
    certbot/certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email email@gmail.com \
        -d swaap.example.com

# ── BUILD & RUN ──
docker compose -f docker-compose.demo.yml up --build -d

# ── VERIFIKASI ──
docker compose -f docker-compose.demo.yml ps
curl https://swaap.example.com/health

# ═══════════════════════════════════════════════════════════════════
# SELESAI! Buka https://swaap.example.com di browser
# ═══════════════════════════════════════════════════════════════════
```

---

*Materi presentasi deployment SWAAP — Full manual tanpa script.*

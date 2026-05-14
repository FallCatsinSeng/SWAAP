# SWAAP — Panduan Deploy ke VPS

Panduan langkah demi langkah untuk men-deploy SWAAP (Smart Wrapper Academic Portal) ke VPS production dengan HTTPS.

---

## Prasyarat

| Komponen | Versi Minimum |
|----------|---------------|
| Ubuntu/Debian VPS | 22.04+ |
| Docker Engine | 24.0+ |
| Docker Compose (plugin) | v2.20+ |
| Domain yang sudah mengarah ke IP VPS | — |

---

## 1. Install Docker di VPS

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker (official script)
curl -fsSL https://get.docker.com | sudo bash

# Tambahkan user ke group docker (agar tidak perlu sudo)
sudo usermod -aG docker $USER

# Logout dan login kembali, lalu verifikasi
docker --version
docker compose version
```

---

## 2. Clone Repository & Setup Environment

```bash
# Clone repo
git clone <REPO_URL> /opt/swaap
cd /opt/swaap

# Salin dan isi environment variables
cp .env.example .env
nano .env
```

Isi `.env` sesuai kebutuhan (lihat `.env.example` untuk referensi).

---

## 3. Build & Jalankan Container

```bash
# Build semua image
docker compose build

# Jalankan di background
docker compose up -d

# Cek status
docker compose ps

# Lihat log
docker compose logs -f
```

Frontend akan berjalan di `127.0.0.1:8080` (hanya localhost). Backend (`8081`) **tidak** terexpose ke luar — hanya bisa diakses oleh frontend via internal Docker network.

---

## 4. Setup Nginx Reverse Proxy (Host) + HTTPS

### Install Nginx & Certbot

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

### Konfigurasi Nginx (Host)

Buat file `/etc/nginx/sites-available/swaap`:

```nginx
server {
    listen 80;
    server_name yourdomain.com;

    # Redirect semua HTTP ke HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name yourdomain.com;

    # SSL (akan diisi oleh Certbot)
    ssl_certificate     /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;

    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;

    # Proxy ke Docker container (frontend)
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Aktifkan Site & Generate SSL

```bash
# Aktifkan config
sudo ln -s /etc/nginx/sites-available/swaap /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test config
sudo nginx -t

# Generate sertifikat SSL (ganti yourdomain.com)
sudo certbot --nginx -d yourdomain.com

# Restart Nginx
sudo systemctl reload nginx
```

### Auto-Renew SSL

Certbot otomatis menambahkan cron/timer. Verifikasi:

```bash
sudo certbot renew --dry-run
```

---

## 5. Firewall (UFW)

```bash
# Hanya buka port yang diperlukan
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP (redirect ke HTTPS)
sudo ufw allow 443/tcp   # HTTPS
sudo ufw enable
sudo ufw status
```

---

## 6. Maintenance

### Update Aplikasi

```bash
cd /opt/swaap
git pull origin main
docker compose build
docker compose up -d
```

### Lihat Log

```bash
docker compose logs -f backend
docker compose logs -f frontend
```

### Restart

```bash
docker compose restart
```

### Bersihkan Image Lama

```bash
docker image prune -f
```

---

## Arsitektur Deployment

```
Internet
  │
  ▼
[Nginx Host :443 HTTPS]
  │
  ▼ proxy_pass
[Docker: frontend :8080]  ──(internal network)──▶  [Docker: backend :8081]
     (Nginx Alpine)                                    (Go Distroless)
```

- **Backend** hanya bisa diakses dari internal Docker network (tidak ada port expose ke host)
- **Frontend** hanya bind ke `127.0.0.1:8080` (tidak bisa diakses langsung dari luar)
- **Host Nginx** menangani HTTPS termination dan mem-proxy ke frontend
- Semua container berjalan dengan `cap_drop: ALL`, `read_only`, dan `no-new-privileges`

# SWAAP (SWU Alternatif App)

**SWAAP** (SWU Alternatif App) adalah aplikasi alternatif untuk mengakses sistem portal akademik (legacy). Aplikasi ini dikembangkan untuk memberikan antarmuka yang lebih modern dan fitur yang lebih mudah digunakan, dengan memanfaatkan *wrapper API* berbasis Golang di sisi backend dan aplikasi berbasis Flutter di sisi frontend.

## Cara Menjalankan Aplikasi

Untuk menjalankan aplikasi ini secara lokal, Anda perlu menyalakan backend dan frontend-nya.

### 1. Jalankan Backend (Golang)
Buka terminal di root direktori project dan jalankan perintah berikut:
```bash
go run cmd/wrapper-api/main.go
```

### 2. Jalankan Frontend (Flutter)
Buka terminal baru, masuk ke dalam folder `flutter_app`, dan jalankan aplikasinya:
```bash
cd flutter_app
flutter run
```

## Lisensi

Project ini didistribusikan di bawah lisensi **GNU Affero General Public License v3.0 (AGPL-3.0)**. 
Aturan lisensi secara penuh dapat Anda lihat pada file [`LICENSE`](LICENSE) yang terlampir di dalam repositori ini.

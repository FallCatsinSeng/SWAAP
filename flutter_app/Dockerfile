# ── Stage 1: Build Flutter Web ──────────────────────────────────────────────
FROM ghcr.io/cirruslabs/flutter:stable AS builder

WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
RUN flutter build web --release \
      --dart-define=API_URL=/api

# ── Stage 2: Production Nginx (non-root) ─────────────────────────────────────
FROM nginxinc/nginx-unprivileged:1.27-alpine

COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

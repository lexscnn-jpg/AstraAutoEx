# AstraAutoEx Deployment Guide

## Quick Deploy (Docker Compose)

```bash
# 1. Generate secret
export SECRET_KEY_BASE=$(openssl rand -base64 48)

# 2. Start
docker-compose up -d

# 3. Access
open http://localhost:4000
```

## Production Deploy

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DATABASE_URL` | Yes | — | PostgreSQL connection string |
| `SECRET_KEY_BASE` | Yes | — | Generate with `mix phx.gen.secret` |
| `PHX_HOST` | Yes | — | Your domain (e.g., `app.example.com`) |
| `PHX_SERVER` | Yes | `true` | Enable HTTP server |
| `PORT` | No | `4000` | HTTP port |
| `STORAGE_TYPE` | No | `local` | `local` or `s3` |
| `UPLOAD_DIR` | No | `priv/uploads` | Local upload directory |
| `S3_BUCKET` | If S3 | — | S3 bucket name |
| `S3_REGION` | If S3 | `us-east-1` | AWS region |
| `S3_ENDPOINT` | If S3 | — | Custom endpoint (MinIO) |
| `AWS_ACCESS_KEY_ID` | If S3 | — | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | If S3 | — | AWS secret key |
| `POOL_SIZE` | No | `10` | Database connection pool |

### Docker Build

```bash
docker build -t astra-auto-ex .

docker run -d \
  -p 4000:4000 \
  -e DATABASE_URL="ecto://user:pass@host/astra_auto_ex_prod" \
  -e SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  -e PHX_HOST="app.example.com" \
  -e PHX_SERVER=true \
  -v uploads:/app/uploads \
  astra-auto-ex
```

### Elixir Release (No Docker)

```bash
# Build
export MIX_ENV=prod
mix deps.get --only prod
mix compile
mix assets.deploy
mix release

# Run
export DATABASE_URL="ecto://..."
export SECRET_KEY_BASE="..."
export PHX_HOST="..."
export PHX_SERVER=true

_build/prod/rel/astra_auto_ex/bin/migrate
_build/prod/rel/astra_auto_ex/bin/server
```

### Nginx Reverse Proxy (HTTPS)

```nginx
server {
    listen 443 ssl http2;
    server_name app.example.com;

    ssl_certificate /etc/letsencrypt/live/app.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/app.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:4000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    end
}

server {
    listen 80;
    server_name app.example.com;
    return 301 https://$server_name$request_uri;
}
```

### SSL with Let's Encrypt

```bash
apt install certbot python3-certbot-nginx
certbot --nginx -d app.example.com
```

## System Requirements

- **PostgreSQL 16+**
- **FFmpeg** (for video composition) — included in Docker image
- **2GB+ RAM** recommended (Elixir BEAM + PostgreSQL)
- **Storage**: depends on media volume; recommend SSD

## First Run

1. Access the app at your configured URL
2. Setup Wizard guides you through:
   - Admin account creation
   - AI provider API key configuration
   - Storage setup
3. Start creating projects from the home page

## Monitoring

- **Phoenix LiveDashboard**: `/dev/dashboard` (dev only)
- **Health check**: `GET /` returns 200
- **Logs**: `docker logs -f astra-auto-ex-app-1` or systemd journal

## Backup

```bash
# Database
pg_dump -Fc astra_auto_ex_prod > backup.dump

# Uploads
tar czf uploads.tar.gz /app/uploads/
```

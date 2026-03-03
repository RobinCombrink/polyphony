# Production Deployment (VM + Docker Compose)

## Goal
Deploy Polyphony services to a production VM with Docker Compose, without storing secrets in git or plaintext config files.

## Files
- `docker-compose.prod.yml` (production compose)
- `livekit.prod.yaml` (production LiveKit server config)
- `.env.production.example` (template only, safe to commit)
- `.env.production` (real secrets, do not commit)

## Backend image publishing (GHCR)
- Workflow: `.github/workflows/backend_ci.yml`
- Published image: `ghcr.io/polyphony-org/polyphony/backend-api`
- Tags include: `latest` (main), branch refs, commit SHA, and git tags (`v*`)

## Setup on the VM
```bash
cp .env.production.example .env.production
# edit .env.production with real values
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```

## Required secrets
- `POSTGRES_PASSWORD`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`

## Required runtime values
- `BACKEND_API_IMAGE` (for example `ghcr.io/polyphony-org/polyphony/backend-api:latest`)
- `LIVEKIT_URL` (public URL clients should use, for example `wss://livekit.polyphony.com`)

## Services started
- `postgres`
- `livekit`
- `backend-api`

The backend container reads:
- Postgres: `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`
- LiveKit: `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`
- HTTP request logging: `BACKEND_API_HTTP_REQUEST_LOGGING_ENABLED`, `BACKEND_API_HTTP_REQUEST_LOGGING_LEVEL`

HTTP request logs are emitted by automatic middleware instrumentation for every request (method, path, status, latency). Keep request/response headers and bodies disabled unless you have a temporary debugging need and a reviewed redaction plan.

## Notes
- `docker-compose.local.yml` and `livekit.local.yaml` are local-development only.
- Keep `.env.production` on the VM or in a secret manager-backed deployment process.
- On the VM, authenticate to GHCR before first pull if the package is private:
	- `echo <github_pat_with_read_packages> | docker login ghcr.io -u <github_username> --password-stdin`

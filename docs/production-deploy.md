# Production Deployment (VM + Docker Compose)

## Goal
Deploy Polyphony services to a production VM with Docker Compose, without storing secrets in git or plaintext config files.

## Files
- `docker-compose.prod.yml` (production compose)
- `livekit.prod.yaml` (production LiveKit server config)
- `.env.production.example` (template only, safe to commit)
- `.env.production` (real secrets, do not commit)

Configuration source of truth for runtime values is `.env.production`.

## Backend image publishing (GHCR)
- Workflow: `.github/workflows/backend_ci.yml`
- Published image: `ghcr.io/polyphony-org/polyphony/backend-api`
- Tags include: `latest` (main), branch refs, commit SHA, and git tags (`v*`)

### Image tag mapping (from `backend_ci.yml`)
- `latest`: published only from default branch.
- `<branch-name>`: branch ref tag from `type=ref,event=branch`.
- `sha-<short-sha>`: commit tag from `type=sha`.
- `<git-tag>`: git tag ref from `type=ref,event=tag`.

For deterministic deploys, set `BACKEND_API_IMAGE` in `.env.production` to an immutable `sha-<short-sha>` tag and use `latest` only for ad-hoc environments.

## Setup on the VM
```bash
cp .env.production.example .env.production
# edit .env.production with real values
docker compose --env-file .env.production -f docker-compose.prod.yml config --quiet
docker compose --env-file .env.production -f docker-compose.prod.yml up -d
```

Use `config --quiet` for preflight validation to avoid printing resolved environment values.

## Rollout Procedure
```bash
# 1) Authenticate to GHCR (if needed)
echo <github_pat_with_read_packages> | docker login ghcr.io -u <github_username> --password-stdin

# 2) Pull the exact backend image tag referenced by BACKEND_API_IMAGE
docker compose --env-file .env.production -f docker-compose.prod.yml pull backend-api

# 3) Apply deployment
docker compose --env-file .env.production -f docker-compose.prod.yml up -d

# 4) Verify health
docker compose --env-file .env.production -f docker-compose.prod.yml ps
curl -fsS http://127.0.0.1:5067/health
```

## Rollback Procedure
```bash
# 1) Edit BACKEND_API_IMAGE in .env.production to the previous known-good tag

# 2) Pull previous image explicitly
docker compose --env-file .env.production -f docker-compose.prod.yml pull backend-api

# 3) Re-apply with previous image
docker compose --env-file .env.production -f docker-compose.prod.yml up -d backend-api

# 4) Verify rollback health
docker compose --env-file .env.production -f docker-compose.prod.yml ps
curl -fsS http://127.0.0.1:5067/health
```

Rollback should always target a previously verified immutable tag (for example `ghcr.io/polyphony-org/polyphony/backend-api:sha-abc1234`) rather than `latest`.

## Required secrets
- `POSTGRES_PASSWORD`
- `LIVEKIT_API_KEY`
- `LIVEKIT_API_SECRET`
- `SENTRY_BACKEND_DSN`

## Required runtime values
- `BACKEND_API_IMAGE` (for example `ghcr.io/polyphony-org/polyphony/backend-api:latest`)
- `LIVEKIT_URL` (public URL clients should use, for example `wss://livekit.polyphony.com`)
- `BACKEND_API_CORS_ALLOWED_ORIGINS` (comma-separated allowed origins for frontend clients)
- `AUTH0_ISSUER` (`https://dev-polyphony.eu.auth0.com/` for all environments)
- `AUTH0_AUDIENCE` (for example `https://api.polyphony.com`)

Production guardrail: backend startup rejects production configuration when `AUTH0_ISSUER` is not `https://dev-polyphony.eu.auth0.com/`.

Canonical source of required non-local runtime variables is `REQUIRED_NON_LOCAL_ENV_VARS` in `crates/backend-api/src/config.rs`.

## Services started
- `postgres`
- `livekit`
- `backend-api`

Compose runtime semantics:
- All production services use `restart: unless-stopped` for automatic recovery after host or process restarts.
- `backend-api` waits for `postgres` to be healthy before start (`depends_on: condition: service_healthy`).
- `backend-api` requires `livekit` to be started before start (`depends_on: condition: service_started`).

The backend container reads:
- Runtime mode: `BACKEND_API_RUNTIME_ENV` (defaults to `production` if omitted)
- Postgres: `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DATABASE`, `POSTGRES_USERNAME`, `POSTGRES_PASSWORD`
- Auth0: `AUTH0_ISSUER`, `AUTH0_AUDIENCE`
- LiveKit: `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`
- Sentry: `SENTRY_BACKEND_DSN`
- CORS: `BACKEND_API_CORS_ALLOWED_ORIGINS`
- HTTP request logging: `BACKEND_API_HTTP_REQUEST_LOGGING_ENABLED`, `BACKEND_API_HTTP_REQUEST_LOGGING_LEVEL`

When runtime mode is non-local (`dev` or `production`), backend startup validates required env vars before binding the HTTP port. Production additionally rejects localhost CORS origins. This fail-fast behavior is implemented in `crates/backend-api/src/config.rs` and wired in `crates/backend-api/src/main.rs`.

HTTP request logs are emitted by automatic middleware instrumentation for every request (method, path, status, latency). Keep request/response headers and bodies disabled unless you have a temporary debugging need and a reviewed redaction plan.

## Operational Observability Checks
Use these checks after rollout and during incident triage.

```bash
# service process status
docker compose --env-file .env.production -f docker-compose.prod.yml ps

# backend health endpoint
curl -fsS http://127.0.0.1:5067/health

# backend recent logs (method/path/status/latency)
docker compose --env-file .env.production -f docker-compose.prod.yml logs --tail=200 backend-api

# livekit recent logs
docker compose --env-file .env.production -f docker-compose.prod.yml logs --tail=200 livekit

# postgres recent logs
docker compose --env-file .env.production -f docker-compose.prod.yml logs --tail=200 postgres
```

Minimum operational signals to monitor:
- API availability (`/health` success).
- Elevated 5xx response rate from backend logs.
- Elevated request latency from backend logs.
- Repeated container restarts from `docker compose ps` and host logs.

## Temporary Debug Escalation (Safe)
Prefer short, time-boxed escalation and revert promptly.

```bash
# temporarily increase HTTP middleware log verbosity
BACKEND_API_HTTP_REQUEST_LOGGING_LEVEL=debug

# apply with compose after editing .env.production
docker compose --env-file .env.production -f docker-compose.prod.yml up -d backend-api
```

Redaction and safety requirements:
- Do not enable request/response headers or bodies in production unless there is an explicit redaction plan.
- Avoid copying secrets, bearer tokens, or connection strings into tickets or chat logs.
- Revert temporary debug levels to baseline (`info`) after investigation.

## Notes
- `docker-compose.local.yml` and `livekit.local.yaml` are local-development only.
- Keep `.env.production` on the VM or in a secret manager-backed deployment process.
- Do not include localhost origins in `BACKEND_API_CORS_ALLOWED_ORIGINS` for production.
- On the VM, authenticate to GHCR before first pull if the package is private:
	- `echo <github_pat_with_read_packages> | docker login ghcr.io -u <github_username> --password-stdin`

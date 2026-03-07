# Local Development

## Current Scope
- Environment support: local first, then dev.
- Production deployment is intentionally out of scope.
- Media/file storage is intentionally out of MVP scope.

## Auth0 Configuration (No Orgs)
Defaults are defined in backend runtime configuration (`BackendApiConfig` and `Auth0Config`).

Optionally set these environment variables to override defaults at runtime:

- `AUTH0_ISSUER` (for example `https://example-dev.eu.auth0.com/`)
- `AUTH0_AUDIENCE` (for example `polyphony-api`)
- `AUTH0_ACCESS_TOKEN_DURATION_HOURS=18`
- `BACKEND_API_BIND` (for example `127.0.0.1:5067`)
- `BACKEND_API_CORS_ALLOWED_ORIGINS` (comma-separated, defaults to `http://localhost:3000,http://127.0.0.1:3000`)

Auth0 organization support is intentionally disabled for MVP.

Or with Docker Compose:
```bash
docker compose -f docker-compose.local.yml up --build
```

## LiveKit 
This local setup is single-node and intentionally does not use Redis.

With Docker Compose, this starts both backend-api and LiveKit:
```bash
docker compose -f docker-compose.local.yml up --build
```

Connection info:
- `ws://127.0.0.1:7880`
- API key `devkey`
- API secret `secret`

For production deployment with Docker Compose and secret handling, see `docs/production-deploy.md`.

If web clients fail with ICE timeout (for example `Timed out waiting for PeerConnection to connect`):
- Restart LiveKit after config changes: `docker compose -f docker-compose.local.yml up -d --force-recreate livekit`
- Ensure Windows Firewall allows:
	- UDP `50000-50100`
	- TCP `7881`
- Keep `rtc.node_ip` in `livekit.local.yaml` set to `127.0.0.1` for same-machine local development.
- Set `rtc.enable_loopback_candidate: true` for local browser clients on the same machine.
- For testing from other machines/devices, set `rtc.node_ip` to your host LAN IP instead of `127.0.0.1`.

If Windows app connects but browser does not:
- Verify browser and LiveKit are on the same host and LiveKit was recreated after config changes.
- In browser DevTools, inspect `chrome://webrtc-internals` and confirm remote candidates are `127.0.0.1` (same-host test) or your LAN IP (multi-device test), not Docker bridge IPs.

local dev only works on Chrome at the moment due to local ICE caveat

Runtime env configuration used by backend:
- `LIVEKIT_URL` (default `ws://127.0.0.1:7880`)
- `LIVEKIT_API_KEY` (default `devkey`)
- `LIVEKIT_API_SECRET` (default `secret`)
- `LIVEKIT_TOKEN_TTL_SECONDS` (default `3600`)
- `BACKEND_API_HTTP_REQUEST_LOGGING_ENABLED` (default `true`)
- `BACKEND_API_HTTP_REQUEST_LOGGING_LEVEL` (default `info`; one of `trace|debug|info|warn|error`)

HTTP request logging is implemented via automatic middleware instrumentation (Tower HTTP `TraceLayer`) and logs each request with method, path, status, and latency. Request/response headers and bodies are not logged by default.

## Live Audio Architecture (Current)
- LiveKit handles media transport, room signaling, and participant media plumbing.
- Backend API handles domain policy checks and token issuance only.
- Token generation is implemented via LiveKit Rust Server SDK (`livekit-api`), not custom JWT assembly.

Current backend voice connect endpoint:
- `POST /api/v1/channels/{channel_id}/session` with body `{ "session_type": "voice" }`
- Requires bearer auth.
- Returns: `livekit_url`, `access_token`, `channel_id`, `participant_subject`.

Responsibilities split:
- Backend-owned: membership/authorization checks, channel-to-room mapping, audit/business rules.
- LiveKit-owned: media session internals, WebRTC signaling/media semantics, token grant interpretation.

## Developing the server
```bash
cargo install cargo-watch systemfd
```

```bash
systemfd --no-pid -s http::3000 -- cargo watch -x run
```

## Git Hooks
Enable repository-managed Git hooks so `pre-push` runs the same checks as CI:

```bash
git config core.hooksPath .githooks
```

The pre-push hook runs backend Rust checks, Postgres-backed cucumber acceptance tests,
backend Docker image build, and frontend Flutter checks/build.

## OpenAPI Frontend
- Swagger UI: `http://127.0.0.1:5067/openapi`
- OpenAPI JSON: `http://127.0.0.1:5067/api-docs/openapi.json`

## Flutter Client (MVP)
- Location: `apps/flutter_client`
- Purpose: list servers, channels, and messages from the backend API

Run locally:
```bash
cd apps/flutter_client
flutter pub get
flutter run
```

In the app:
- Backend base URL defaults to `POLYPHONY_BACKEND_BASE_URL`
- Click **Sign In** to start Auth0 browser login and automatic token exchange

Flutter OAuth settings (`--dart-define`):
- `AUTH0_DOMAIN` (default: `dev-polyphony.eu.auth0.com`)
- `AUTH0_NATIVE_CLIENT_ID` (default: `3QEwnOrRK5qAFqjNJvXWdPJDhLz1p0yZ`)
- `AUTH0_WEB_CLIENT_ID` (default: `pyTVsVOWzcOK85LQfL4Ulwpeft4XpSqW`)
- `AUTH0_AUDIENCE` (default: `https://polyphony.com`)
- `AUTH0_SCOPES` (default: `openid profile email`)
- `AUTH0_MOBILE_REDIRECT_URI` (default: `polyphony://auth/callback`)
- `AUTH0_DESKTOP_REDIRECT_URI` (default: `http://localhost:4000`)

Package notes:
- The Flutter client uses `auth0_flutter` SDK for web and mobile/macOS auth flows.
- Windows and Linux keep a desktop fallback OAuth flow with `flutter_web_auth_2`.

## Test Strategy
- BDD-style acceptance tests live under `features/` and backend integration tests.
- Entity creation in tests should use `EntitySeeder` types to hide implementation details.

## Observability
- OpenTelemetry initialization is enabled in backend startup.
- Current default output is tracing with OpenTelemetry bridge; exporters can be expanded in dev later.

# Local Development

## Current Scope
- Environment support: local first, then dev.
- Production deployment is intentionally out of scope.
- Media/file storage is intentionally out of MVP scope.

## Auth0 Configuration (No Orgs)
Defaults are defined in backend runtime configuration (`BackendApiConfig` and `Auth0Config`).

Optionally set these environment variables to override defaults at runtime:

- `AUTH0_ISSUER` (for example `https://example-dev.us.auth0.com/`)
- `AUTH0_AUDIENCE` (for example `polyphony-api`)
- `AUTH0_ACCESS_TOKEN_DURATION_HOURS=18`
- `BACKEND_API_BIND` (for example `127.0.0.1:5067`)

Auth0 organization support is intentionally disabled for MVP.

Or with Docker Compose:
```bash
docker compose -f docker-compose.local.yml up --build
```

## Developing the server
```bash
cargo install cargo-watch systemfd
```

```bash
systemfd --no-pid -s http::3000 -- cargo watch -x run
```

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
- `AUTH0_CLIENT_ID` (default: `3QEwnOrRK5qAFqjNJvXWdPJDhLz1p0yZ`)
- `AUTH0_AUDIENCE` (default: `https://polyphony.com`)
- `AUTH0_SCOPES` (default: `openid profile email`)
- `AUTH0_MOBILE_REDIRECT_URI` (default: `polyphony://auth/callback`)
- `AUTH0_DESKTOP_REDIRECT_URI` (default: `http://localhost:3000`)
- `AUTH0_WEB_REDIRECT_PATH` (default: `/auth.html`)

Package notes:
- The Flutter client now uses `flutter_web_auth_2` for browser-based OAuth flow.
- This supports Windows and Linux in addition to mobile/web.

## Test Strategy
- BDD-style acceptance tests live under `features/` and backend integration tests.
- Entity creation in tests should use `EntitySeeder` types to hide implementation details.

## Observability
- OpenTelemetry initialization is enabled in backend startup.
- Current default output is tracing with OpenTelemetry bridge; exporters can be expanded in dev later.

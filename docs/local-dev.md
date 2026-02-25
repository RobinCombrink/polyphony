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
- Backend base URL defaults to `http://127.0.0.1:5067`
- Paste an Auth0 access token and click **Load Servers**

## Test Strategy
- BDD-style acceptance tests live under `features/` and backend integration tests.
- Entity creation in tests should use `EntitySeeder` types to hide implementation details.

## Observability
- OpenTelemetry initialization is enabled in backend startup.
- Current default output is tracing with OpenTelemetry bridge; exporters can be expanded in dev later.

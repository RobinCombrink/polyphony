# Polyphony Flutter Client

Local-first Flutter MVP client for browsing:
- Servers (`GET /api/v1/servers`)
- Channels (`GET /api/v1/servers/{server_id}/channels`)
- Messages (`GET /api/v1/channels/{channel_id}/messages`)

State management uses BLoC for async/API-driven flows (`ServersBloc`, `ChannelsBloc`, `MessagesBloc`) and Result-pattern API responses.

## Architecture

- Vertical slices: `lib/features/chat_browser/` and `lib/features/authentication/` (bloc + presentation + domain)
- Shared concerns: `lib/shared/` (models, network, repositories, services, result)
- App composition: `lib/app/polyphony_app_widget.dart`
- Entrypoint: `lib/main.dart`

## Run

```bash
flutter pub get
flutter run
```

Default backend URL in the app is `http://127.0.0.1:5067`.

### Sentry

The Flutter client supports Sentry for crash/error capture and tracing via
compile-time defines:

- `SENTRY_ENABLED` (default: `true`)
- `SENTRY_FRONTEND_DSN` (default: empty, disables Sentry when empty)
- `SENTRY_TRACES_SAMPLE_RATE` (default: `1.0`)
- `SENTRY_ENVIRONMENT` (default: `development`)
- `SENTRY_RELEASE` (default: empty)

Example local run:

```bash
flutter run \
	--dart-define=SENTRY_ENABLED=true \
	--dart-define=SENTRY_FRONTEND_DSN=https://<key>@o<org>.ingest.de.sentry.io/<project> \
	--dart-define=SENTRY_TRACES_SAMPLE_RATE=1.0 \
	--dart-define=SENTRY_ENVIRONMENT=development \
	--dart-define=SENTRY_RELEASE=local-dev
```

Verification:
- Open Settings > Developer options.
- Enable developer options.
- Use `Verify Sentry Setup` to throw a test exception.

## Authentication

- The app signs in via Auth0 Authorization Code + PKCE.
- On native platforms (Windows/Linux/Android/iOS/macOS), Auth0 refresh tokens are persisted with secure storage and used to restore sessions across app restarts.
- On web, refresh token persistence is disabled because there is no secure storage mechanism.
- Configure separate Auth0 application client IDs per platform:
	- `AUTH0_NATIVE_CLIENT_ID`: Auth0 Native Application client (used on Windows/Linux/Android/iOS/macOS)
	- `AUTH0_WEB_CLIENT_ID`: Auth0 SPA/Web client (used on web)
- flutter_secure_storage read https://github.com/juliansteenbakker/flutter_secure_storage/blob/develop/README.md for build requirements
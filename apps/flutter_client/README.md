# Polyphony Flutter Client

Local-first Flutter MVP client for browsing:
- Servers (`GET /api/v1/servers`)
- Channels (`GET /api/v1/servers/{server_id}/channels`)
- Messages (`GET /api/v1/channels/{channel_id}/messages`)

State management uses BLoC for async/API-driven flows (`ChatBrowserBloc`) and Result-pattern API responses.

## Architecture

- Vertical slice feature: `lib/features/chat_browser/` (application + domain + presentation, end-to-end)
- Shared concerns: `lib/shared/` (auth, models, network, result)
- App composition: `lib/app/polyphony_app.dart`
- Entrypoint: `lib/main.dart`

## Run

```bash
flutter pub get
flutter run
```

Default backend URL in the app is `http://127.0.0.1:5067`.
Enter an Auth0 access token in the app and click **Load Servers**.

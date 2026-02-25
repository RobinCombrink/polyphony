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
Enter an Auth0 access token in the app and click **Load Servers**.

# Polyphony Roadmap (Current)

Last updated: 2026-03-08

## 1) Current State Snapshot

### Delivered foundations
- Rust backend split into `backend-api`, `backend-domain`, and `backend-storage` crates.
- Flutter client is feature-oriented with BLoCs, repositories, and Result-based API/service boundaries.
- Core domain flows are implemented and covered by BDD scenarios:
	- Health + identity (`/health`, `/api/v1/me`, `/api/v1/users/{id}`)
	- Servers/channels CRUD and membership
	- Channel messages CRUD with ownership checks
	- Voice session token issuance for LiveKit (`/api/v1/channels/{channel_id}/session`)
- Live audio architecture is policy/token broker backend + LiveKit media transport.
- CI pipelines exist for backend and frontend with lint/test/build checks.

### Observability baseline (implemented)
- OpenTelemetry initialization is enabled in backend startup.
- Automatic HTTP instrumentation is enabled via middleware (`TraceLayer`), not manual route spans.
- HTTP request logging is configurable:
	- `BACKEND_API_HTTP_REQUEST_LOGGING_ENABLED`
	- `BACKEND_API_HTTP_REQUEST_LOGGING_LEVEL`
- Default logged request dimensions are method/path/status/latency (without headers/bodies).

### Scope constraints currently in force
- Local-first then dev; no full production rollout program in this plan.
- Auth0 only (no org support); access-token lifetime is managed by Auth0 and enforced by JWT claims.
- Server member add operations accept internal `UserId` values only; external references are limited to Auth0 identity mapping.
- No media/file upload support in current MVP scope.
- BDD-first acceptance style and EntitySeeder patterns remain required.

## 2) Priorities for the Next 1-2 Months

### Objective for this horizon
- Deliver an MVP-ready user experience on existing functionality, with a frontend-first focus.
- Prioritize polish and clarity over new backend capability.
- Maintain BDD-first acceptance coverage for the polished happy paths.

### In scope (8 weeks)
- Material 3 theming and brand color integration across the Flutter client.
- Happy-path UX polish for auth, server/channel, messages, and voice entry flows.
- Navigation and usability cleanup to reduce friction and dead ends.
- Full BDD scenario updates for polished happy paths, followed by test implementation updates.

### Explicitly out of scope for this horizon
- Pagination and index optimization.
- Broad backend architecture redesign work.
- Demo seed-data work (existing backend data is sufficient).

### Delivery plan

#### Phase 1 (Weeks 1-2): Theme foundation
- Define and apply a Material 3 theme architecture using brand color tokens.
- Standardize typography, component styling, and state colors for loading/success/error.
- Establish shared theming primitives in Flutter `shared/` for reuse by features.

Status:
- Completed: centralized Material 3 light/dark theme wiring in app shell.
- Completed: persisted dark mode preference with `SettingsBloc` and settings UI toggle.

#### Phase 2 (Weeks 3-4): Happy-path screen polish
- Polish existing screens for core MVP paths with consistent loading, empty, and error states.
- Improve hierarchy and feedback on current views without changing core product scope.
- Keep presentation concerns in widgets while preserving existing BLoC ownership of logic.

Status:
- Completed: settings page layout polish (scroll-safe sections, visual grouping, appearance feedback).
- Completed: auth sign-in and web redirect views polished for responsive card layout and clearer error feedback.
- Completed: server/channel/messages empty and intermediate states polished for clearer guidance and consistent card-based presentation.
- Completed: voice entry/participants flow polished with clearer placeholder states and lifecycle guidance copy.
- Completed: shared UI copy sweep across core empty/error/transition states.
- Completed: targeted BDD scenario updates for polished MVP happy paths.
- Completed: feature/scenario wording pass across top-level and executable backend BDD files to keep scenarios behavior-focused.
- Completed: executable Rust scenario test names aligned to behavior-focused wording for BDD consistency.
- Completed: executable BDD happy-path coverage extended for shared-server member voice join flow.
- Validation: backend executable BDD scenario suite now passes with 40 scenarios.

#### Phase 3 (Weeks 5-6): Navigation and usability cleanup
- Validate responsive quality on desktop and mobile form factors.

Status:
- Completed: home shell and workspace panes now adapt between desktop side-by-side layout and compact stacked layout to prevent overflow on narrow screens.
- Completed: compact viewport widget regression coverage added for home rendering.
- Validation: Flutter quality gates pass (`dart analyze`, `flutter test` with 64 passing tests).

#### Phase 4 (Weeks 7-8): BDD and regression alignment
- Keep CI healthy and treat skipped tests as failures.

Status:
- Completed: executable backend BDD files were rewritten to keep assertions behavior-focused (no response-status/payload implementation leakage in scenario wording).
- Completed: executable voice and messages BDD feature coverage was aligned with existing Rust regression scenarios (non-member restrictions and channel-kind mismatch behavior).

### Quality gates
- Flutter changes must pass `dart analyze` and `flutter test`.
- BDD scenarios remain the source of truth for acceptance behavior.
- MVP smoke flow must be demonstrably reliable end-to-end on local/dev.

### MVP smoke flow (must pass)
1. Sign in.
2. Open server and channel.
3. Read/send messages in channel.
4. Join voice session for the channel.
5. Recover gracefully from expected empty/error states.

## 3) Production Readiness Sprint (Before Expansion)

### Objective for this sprint
- Harden deployment and operations for production usage on existing MVP behavior before introducing major new feature surface.
- Eliminate ambiguous runtime configuration and make rollout/rollback repeatable and auditable.

### Scope
- Backend startup/config hardening.
- Production deployment artifact hardening.
- CI/CD release-path hardening.
- Observability and operations runbook completeness.

### Delivery plan

#### PR Phase A (Week 1): Baseline audit and acceptance criteria
Status:
- Completed.
- Completed: production runtime variable requirements were aligned across `docker-compose.prod.yml`, `.env.production.example`, and `docs/production-deploy.md`.
- Completed: runtime variable source-of-truth was anchored to backend startup validation in `crates/backend-api/src/config.rs`.

Goals:
- Establish an explicit production go-live checklist and definition of done.

Scope:
- Audit `docs/production-deploy.md`, `docker-compose.prod.yml`, `livekit.prod.yaml`, `.env.production.example`.
- Document required runtime variables and secret sources by marking the places that they are configured inside the application rather than inside of documents that can become out of sync with reality.
- Define minimum deploy/recovery targets and post-deploy checks.

Acceptance criteria:
- Production checklist exists and is executable end-to-end.
- No required runtime variable is undocumented - they are all co-located so that they are easily audited, updated and debugged.

#### PR Phase B (Week 2): Backend runtime hardening
Status:
- Completed.
- Completed: `BACKEND_API_RUNTIME_ENV` mode added with production-specific validation behavior.
- Completed: fail-fast validation for missing required production variables and unsafe defaults before server bind.
- Completed: automated unit tests added for production validation behavior in `crates/backend-api/src/config.rs`.
- Completed: backend-managed `AUTH0_ACCESS_TOKEN_DURATION_HOURS` was removed so token lifetime is sourced from Auth0 JWT claims instead of backend config.

Goals:
- Fail fast on invalid/missing production-critical configuration.

Scope:
- Tighten environment validation in `crates/backend-api/src/config.rs` and startup wiring in `crates/backend-api/src/main.rs`.
- Reject unsafe defaults when running in production profile/context.
- Ensure diagnostics avoid secret leakage.

Acceptance criteria:
- Startup exits early with actionable errors for invalid production config.
- Config validation has automated test coverage.

#### PR Phase C (Week 3): Deployment artifact hardening
Status:
- Completed.
- Completed: production compose now passes `BACKEND_API_RUNTIME_ENV=production` and requires `AUTH0_*` and `BACKEND_API_CORS_ALLOWED_ORIGINS` values.
- Completed: `.env.production.example` now includes all newly required production runtime variables.
- Completed: production compose now uses `restart: unless-stopped` for `postgres`, `livekit`, and `backend-api`.
- Completed: backend CORS origins are now resolved from `BackendApiConfig` and passed into router setup (single config-source path for runtime wiring).
- Completed: deployment docs/env references to `AUTH0_ACCESS_TOKEN_DURATION_HOURS` were removed to keep production config authoritative and non-contradictory.

Goals:
- Make production compose/env artifacts authoritative and safe for repeatable deployment.

Scope:
- Refine `docker-compose.prod.yml` dependency/health/restart behavior.
- Align `.env.production.example` with actual runtime requirements.
- Verify `livekit.prod.yaml` expectations are consistent with deployment docs.

Acceptance criteria:
- Production compose startup is deterministic from documented prerequisites.
- Health/dependency semantics are documented and validated.

#### PR Phase D (Week 4): CI/CD release path hardening
Status:
- Completed.
- Completed: deployment runbook now includes explicit production rollout and rollback procedures in `docs/production-deploy.md`.
- Completed: backend CI image tag mapping and immutable tag deployment guidance were documented for reproducible releases.

Goals:
- Ensure release artifacts and deployment commands are traceable and reversible.

Scope:
- Review `.github/workflows/backend_ci.yml` image publishing/tag policy.
- Add explicit rollout and rollback steps to `docs/production-deploy.md`.
- Document GHCR auth and image pull policy for production hosts.

Acceptance criteria:
- Deploy docs include verified rollback path.
- Release tag/image mapping is clear and reproducible.

#### PR Phase E (Week 5): Observability and operations
Status:
- Completed.
- Completed: production runbook now includes operational health/log checks for backend, livekit, and postgres.
- Completed: temporary debug escalation and redaction safety guidance documented for incident response.
- Completed: backend observability defaults now adapt `backend_api` log level by runtime environment (`info` in production, `debug` in local/dev) in `crates/backend-api/src/observability.rs`.

Goals:
- Define minimum operational visibility and alerting posture for production.

Scope:
- Refine `crates/backend-api/src/observability.rs` defaults/documentation alignment.
- Add operational checks for logs/traces/health.
- Document safe temporary debug escalation and redaction constraints.

Acceptance criteria:
- Operators can confirm service health and diagnose failures using documented telemetry.
- Observability guidance is complete in production docs.

### Production readiness quality gates
- Rust: `cargo clippy --workspace --all-targets -- -D warnings` and `cargo test`.
- Flutter: `dart analyze` and `flutter test`.
- BDD: zero skipped scenarios.
- Deployment: documented rollout + rollback procedure exists in `docs/production-deploy.md`.

## 4) Next Expansion Horizon (Post-MVP)

### Objective for this horizon
- Expand collaboration depth (notifications, friends/DMs, richer text chat) while preserving current architecture and BDD-first behavior coverage.
- Keep feature delivery incremental and reversible with strong defaults, clear user controls, and migration-safe backend changes.

### Scope and sequencing principles
- Ship notification controls before high-volume social features to avoid noisy UX.
- Add friend graph and DMs before advanced message enhancements that depend on person-to-person context.
- Keep all new behavior described in feature files first, then implement executable step definitions.

### Delivery plan

#### Phase 5 (Weeks 1-2): Notification foundation and policy model
Status:
- Completed.
- Completed: kickoff BDD scenarios were added in `features/notifications.feature` to define policy precedence and unread-count behavior before implementation.
- Completed: notifications BDD feature was expanded to include authoritative persistence, websocket delivery, and unauthorized-delivery protections in `features/notifications.feature`.
- Completed: DB-authoritative notification outbox and unread-count persistence was added during message creation via `crates/backend-storage/migrations/202603070001_notifications_outbox.sql` and repository updates.
- Completed: websocket realtime adapter endpoint was added at `GET /api/v1/notifications/ws` and message-created fanout is now published from backend message persistence flow.
- Completed: unread aggregation and mark-read APIs were added at `GET /api/v1/notifications/unread-count` and `POST /api/v1/channels/{channel_id}/notifications/read`.
- Completed: executable BDD scenarios now validate unread aggregation across multiple channels and channel-level mark-read lifecycle behavior.
- Completed: server-level mute and temporary channel-mute policy state was added and is now evaluated when computing message notification recipients.
- Completed: executable BDD scenarios now validate mute precedence behavior, including muted-server suppression and temporary channel mute expiry.
- Completed: user-level global mute policy state was added and is now evaluated before server/channel mute policies when selecting notification recipients.
- Completed: executable BDD scenarios now validate global mute suppression and post-unmute notification recovery behavior.
- Completed: executable BDD scenarios now validate precedence conflict behavior where server mute continues suppressing notifications after global mute is lifted.
- Completed: Flutter home app bar now surfaces backend unread notification totals with a refreshable unread badge wired through notification service/repository/BLoC layers.
- Completed: Flutter message decoding now enforces the backend-tagged message contract (`type` + `details.common`) without legacy flat-shape fallback.
- Completed: Flutter settings now includes global/server/channel notification preference controls backed by notification preference APIs.
- Completed: Flutter unread-count synchronization now updates OS app icon/taskbar badge surfaces where supported, covering mobile app icon badges and desktop dock/taskbar badge indicators.

Goals:
- Introduce a unified notification domain model that supports user-level, server-level, and channel-level policies.
- Add device-targeted notification counters for desktop taskbar and mobile app icon badges.

Scope:
- Received text message notifications with per-channel and per-server policy evaluation.
- Channel-scoped "notify me" controls.
- Temporary channel mute (time-boxed mute durations).
- Server-level mute/unmute and per-server notification configuration.
- Notification count aggregation service for:
	- Desktop taskbar count indicator.
	- Mobile app icon badge count indicator.

Implementation notes:
- Backend: add notification preference entities and policy evaluation in service layer.
- Flutter: add preference surfaces in channel/server settings and global notification state display.
- API contracts should return semantic notification states; display copy remains in widgets.

Acceptance criteria:
- A muted server never produces push/badge increments for its channels.
- A muted channel is excluded from unread-notification counts until mute expires.
- Desktop and mobile badge counts are consistent with backend unread policy state.
- BDD scenarios cover policy precedence (global, server, channel, temporary mute).

#### Phase 6 (Weeks 3-4): Mentions and voice presence notifications
Status:
- Completed.

- Completed: text composer now supports inline `@` mention search and selection against server members, and selected mentions are sent with `mentioned_user_id` so backend mention message flow is triggered.
- Completed: an in-app notification feed surface now captures realtime mention/unread live notification stream events in Home, with a clearable recent-events list.
- Completed: notification runtime events were remodeled as a sealed ADT (`UnreadMessageRuntimeNotificationEvent` and `MentionedRuntimeNotificationEvent`) with strict parsing for required server/channel/message metadata.
- Completed: Home notification orchestration was consolidated into `NotificationCenterBloc` (sealed state hierarchy) so live notification stream connection, feed entries, and unread count refreshes are managed in one place.
- Completed: legacy `NotificationFeedBloc` and `NotificationUnreadCountBloc` implementations were removed after migration to `NotificationCenterBloc`.
- Completed: notification feed modal route provider scope was fixed by explicitly propagating `NotificationCenterBloc`, `ServersBloc`, and `ChannelsBloc` into the bottom-sheet context.
- Completed: channel join notifications are now disabled by default via persisted settings, with a dedicated voice-notification toggle in settings to opt in.
- Completed: runtime notification model and parser now support `friend_joined_voice` events, and `NotificationCenterBloc` suppresses these events unless the channel-join-notification preference is enabled.
- Completed: `NotificationCenterBloc` now applies persisted selected-channel allow-list filtering for `friend_joined_voice` events when voice notifications are enabled.
- Completed: voice notification settings now let users configure selected allowed voice channel IDs for friend-joined-voice notifications.
- Completed: widget-level Flutter regression tests now cover voice notification channel selection UX (disabled state, save selection, and clear to all channels).
- Completed: backend live-notification payloads were migrated to a Rust ADT (`NotificationEvent` enum variants) so message and voice events use explicit typed shapes instead of optional transport fields.
- Completed: backend voice session connection now emits `friend_joined_voice` live notifications to other server members, with BDD coverage for delivery and self-suppression behavior.
- Completed: notifications BDD scenario language was refactored to behavior-focused "live notification" phrasing and away from transport-implementation wording.
- Completed: backend API transport logic was cleaned up to remove redundant `NotificationEventType` branching where ADT variants are now constructed directly.

Goals:
- Deliver targeted high-signal notifications based on explicit user intent.

Scope:
- `@mention` support with mention-target selection list and mention-triggered notification.
- Friend-joined-voice notifications with granular controls:
	- Disable entirely.
	- Enable only for selected voice channels.
- In-app notification feed entries for mention and friend-voice events.

Implementation notes:
- Mention parsing and persistence should be backend-authoritative.
- Voice presence notifications should be event-driven and deduplicated for rapid join/leave churn.
- Per-channel voice notification subscription state should be independent of text-notification state.

Acceptance criteria:
- Friend-joined-voice notifications respect selected-channel filters.
- Notification payloads do not leak private server/channel metadata to unauthorized users.
- BDD covers mention generation, delivery filtering, and voice-presence policy behavior.

#### phase 7: frontend implementations of bdd .feature files (where applicable)
status:
- completed

goals:
- High confidence refactors and preventing mismatch between client and server 						

progress:
- completed: phase approach aligned to standard Flutter tests (no extra cucumber package), while using backend-style BDD naming (`Feature`/`Rule`/`Scenario`) and behavior-first assertions.
- completed: added notifications frontend BDD-style test suite at `apps/flutter_client/test/bdd/notifications_feature_test.dart` covering selected-channel filtering behavior for `friend_joined_voice` events.
- completed: expanded frontend notifications BDD-style scenarios to include mention feed delivery, default friend-joined-voice suppression, enabled delivery, allow-list filtering, and unread badge sync behavior.
- completed: added voice sessions frontend BDD-style test suite at `apps/flutter_client/test/bdd/voice_sessions_feature_test.dart` covering voice join success and missing-channel failure behavior.
- completed: added servers/channels frontend BDD-style test suite at `apps/flutter_client/test/bdd/servers_and_channels_feature_test.dart` covering channel loading/selection and server-member validation behavior.
- completed: added messages frontend BDD-style test suite at `apps/flutter_client/test/bdd/messages_feature_test.dart` covering message edit success and missing-message update/delete failure behavior.
- completed: added identity/users frontend BDD-style test suite at `apps/flutter_client/test/bdd/identity_and_users_feature_test.dart` covering profile load, validation failure, and display-name update behavior.
- completed: added auth/health frontend BDD-style test suite at `apps/flutter_client/test/bdd/auth_and_health_feature_test.dart` covering authentication gate session-restore intent and authenticated identity-read scenarios applicable to the Flutter client.
- completed: all current backend `.feature` files now have corresponding frontend BDD-style parity suites where behavior is client-applicable (`auth_and_health`, `identity_and_users`, `messages`, `notifications`, `servers_and_channels`, `voice_sessions`).

#### Phase 11 (Weeks 5-6): Friends, direct messaging, and safety controls
Status:
- In progress.

Goals:
- Add person-to-person social graph and private conversation primitives.

Scope:
- Friend request lifecycle: send, accept, decline, cancel, and notification hooks.
- Direct messaging channels between friends.
- Block list support with block/unblock controls.
- Behavior rules for blocked relationships (friend actions and DMs restricted).
- Search through sent messages to a particular person in DM context.
- Sending friend requests to users who are in servers that we are in

Progress:
- completed: backend friend lifecycle, block-list, and DM endpoints plus route wiring for friends/requests, blocks, and DM operations.
- completed: frontend friend repository/service plumbing for listing friends and sending server-context friend requests.
- completed: server-members UI support for friend status comparison against server users.
- completed: server-members context-menu flows for add friend and cancel pending friend request.
- completed: pending outgoing friend request section with cancel action in server members pane.
- completed: bloc + widget coverage for server-members friend request send/cancel and context-menu rendering paths.
- completed: dedicated `friends` and `direct_messages` feature modules implemented and wired into home composition/authentication gate providers.
- completed: block/unblock controls and blocked-DM composer prompt UX (with unblock action) implemented in frontend feature panes.
- completed: frontend BDD-style social safety and direct-messaging scenarios added and stabilized with deterministic sequential bloc event handling.
Implementation notes:
- Introduce friend relationship state machine in domain layer.
- DM permissions should use explicit relationship checks.
- Blocking should short-circuit DM delivery and friend request operations.

Acceptance criteria:
- Blocked users cannot send DM messages or friend requests until unblocked.
- DM message search returns only messages visible to the requesting user.
- Friend request notifications are emitted exactly once per state transition.
- BDD covers friend lifecycle, DM permissions, and block-list enforcement.

#### phase 11.5: Inviting friends to servers and adding friends through servers
status:
- completed

goals:
- Invite a user that exists in a friends list to a specific server
- Add a user as a friend through a common server membership

progress:
- completed: backend server-context friend request initiation endpoint retained and used by frontend.
- completed: frontend add-friend-through-common-server flow from server members context menu.
- completed: pending outgoing server-context friend requests are listed and cancellable in the members pane.
- completed: invite-friend-to-server operation implemented in Flutter service/repository/bloc/UI context menu.
- completed: validation and API error mapping for invite-friend-to-server flow with automated tests.

#### Phase 12: Upgrade Server and Channel experience
Status:
- Completed.

Progress:
- Completed: backend `PATCH /api/v1/servers/{server_id}` endpoint added for server name updates with owner-only authorization.
- Completed: `update_server_name` repository method added to `ServerRepository` trait with in-memory and Postgres implementations.
- Completed: backend BDD scenarios added for server rename (owner success, non-owner denial, missing server 404) in `features/servers_and_channels.feature`.
- Completed: backend executable BDD step definitions implemented and passing (23 scenarios, 104 steps).
- Completed: frontend `updateServerName` added to server service interface and REST implementation.
- Completed: `UpdateServerNameCommand` added to server repository with full BLoC event/handler wiring (`UpdateServerNameRequested`).
- Completed: server rename accessible from right-click context menu on server avatar (owner-gated).
- Completed: Server Settings page created at `features/servers/presentation/pages/server_settings_page.dart` with name editing and save action.
- Completed: server name header in channel pane is tappable to navigate to Server Settings page (owner-gated, with settings icon indicator).
- Completed: frontend `updateChannelName` added to channel service interface and REST implementation.
- Completed: `UpdateChannelNameCommand` added to channel repository with full BLoC event/handler wiring (`UpdateChannelNameRequested`).
- Completed: channel rename accessible from right-click context menu on channel items (owner-gated).
- Completed: frontend BDD-style tests expanded for server rename (success + validation) and channel rename (success + validation) scenarios.
- Validation: backend quality gates pass (`cargo clippy --workspace --all-targets -- -D warnings`, `cargo test` with 23 server/channel scenarios).
- Validation: frontend quality gates pass (`dart analyze` clean, `flutter test` with 136 passing tests).

Scope:
- Add Server name updating to the right click context menu (And the new Server Settings page, accessed by clicking on the name of the server in the channel list)
- Add Channel name updating to the right click context menu

#### Phase 12.5: Developer experience regarding the mobile client
Status:
- Completed.

Goal:
- Improve debugability of the frontend client

Progress:
- Completed: Created `entity_ids.dart` with 7 extension types (`UserId`, `ServerId`, `ChannelId`, `MessageId`, `FriendRequestId`, `DirectMessageThreadId`, `DirectMessageId`) as zero-cost compile-time wrappers over `String`.
- Completed: Updated all domain models (`chat_models.dart`) to use typed IDs; API models remain `String` at the JSON/HTTP boundary.
- Completed: Updated `api_model_extensions.dart` to wrap/unwrap typed IDs at the API-to-domain bridge.
- Completed: Updated all 10 repository interfaces and implementations to use typed IDs in commands/queries.
- Completed: Updated all BLoC event/state/handler files, presentation widgets, and test files to use typed IDs.
- Completed: Developer mode toggle persisted via `PreferencesStore` and managed by `SettingsBloc` (`SettingsDeveloperModeToggledRequested` event, `isDeveloperModeEnabled` on loaded/exception states).
- Completed: Developer options widget reads persisted developer mode from `SettingsBloc` via `BlocSelector` instead of local `setState`.
- Completed: "Copy server ID" context menu item added to server right-click menu (gated on developer mode).
- Completed: "Copy channel ID" context menu item added to channel right-click menu (gated on developer mode).
- Completed: "Copy user ID" context menu item added to server member right-click menu (gated on developer mode, also shows for friends).
- Completed: "Copy message ID" context menu item added to message right-click menu (gated on developer mode).
- Validation: `dart analyze` clean, `flutter test` 136 tests passing, `cargo clippy` clean, `cargo test` passing.

Scope: 
- add a context menu item to more entities in the frontend when developer mode is enabled. This will copy the Id of the user
- ensure that developer mode is saved via the preferences store so that it doesn't need to be toggled all the time
- Refactor all {Entity}Id fields, e.g. userId, to named extension types for compile time safety and preventing id wires being crossed accidentally

#### Phase 12.7 (Weeks 7-10): Text chat enhancements (media, reactions, threading, retrieval)
Status:
- In progress.

Goals:
- Improve message expressiveness and discoverability while maintaining moderation and performance guardrails.

Scope:
- Rich text messages — markdown format while maintaining safety, including emote shortcode rendering.
- Website previews (link unfurl metadata cards).
- Preset emotes catalog (global).
- Message reactions using emotes, including notification behavior and quick most-used emotes.
- Server-wide pinned messages with source channel context and auditability.
- Mark message as unread in a chat.
- Search through messages in a channel.

Sub-phases:
- **12.7a** — Rich text (markdown) rendering (frontend-only, no backend changes). Includes emote shortcode→emoji rendering.
- **12.7b** — Link previews / unfurl (backend metadata fetch + frontend card).
- **12.7c** — Preset emotes catalog (backend endpoint + frontend picker).
- **12.7d** — Message reactions (backend + frontend, depends on 12.7c emotes catalog).
- **12.7e** — Server-wide pinned messages (backend + frontend).
- **12.7f** — Mark message as unread (backend + frontend).
- **12.7g** — Channel message search (backend + frontend).

Threading is deferred to Phase 12.8.

Progress:
- Completed: 12.7a — Rich text (markdown) rendering with emote shortcode support.
  - Added `flutter_markdown_plus`, `markdown`, and `url_launcher` dependencies.
  - Replaced `SelectableText(message.content)` with `MarkdownBody` in `messages_section_widget.dart`.
  - Uses `ExtensionSet.gitHubWeb` for GitHub-flavored markdown plus emoji shortcodes (`:thumbsup:` → 👍).
  - Markdown links open via `url_launcher` with scheme validation (http/https only).
  - Image markdown renders as alt text instead of loading remote images (privacy/safety).
  - 9 widget tests added for markdown rendering: plain text, bold, italic, inline code, code blocks, emoji shortcodes, links, image safety, no raw SelectableText.
  - Validation: `dart analyze` clean, 145 `flutter test` passing.
- Completed: 12.7b — Link previews (unfurl) with backend metadata fetch and frontend card.
  - Backend: added `GET /api/v1/link-preview?url={url}` endpoint in `routes/link_preview.rs` with SSRF protection (private/loopback IP rejection, post-redirect host validation), 3s timeout, 256KB max response, http/https-only scheme validation.
  - Backend: `LinkPreviewResponse` DTO with `url`, `title?`, `description?`, `image_url?`.
  - Backend: HTML parsing via `scraper` crate extracting `og:title`, `og:description`, `og:image` with `<title>`/`<meta name="description">` fallback.
  - Backend: added `reqwest` and `scraper` dependencies; 6 unit tests for SSRF protection and metadata extraction.
  - Frontend: `LinkPreviewService` interface + `RestLinkPreviewService` with in-memory URL cache.
  - Frontend: `LinkPreviewCardWidget` rendering title, description, and URL in a left-bordered card.
  - Frontend: `_MessageLinkPreviewWidget` in messages section detects first URL via regex, fetches preview, renders card below message content.
  - Frontend: `FakeLinkPreviewService` test double; 3 widget tests for link preview rendering (with URL, without URL, empty preview).
  - Validation: `dart analyze` clean, 148 `flutter test` passing, `cargo clippy` clean, backend unit tests passing.

Implementation notes:
- Markdown rendering is frontend-only; messages stored as plain text, interpreted at display time.
- Link preview is backend-proxied to avoid CORS and enable SSRF protection.
- Emotes start as a hardcoded catalog; custom server emotes deferred to a stretch goal.
- Reactions use toggle semantics (add/remove same endpoint).
- Search starts with `ILIKE`; full-text search upgrade deferred.
- Server-wide pins are a lightweight join (pin metadata + message reference), not a message copy.
- Reactions and reply/thread notifications should be user-configurable and rate-limited to reduce spam.
- Channel search should support pagination and ranking to avoid full-scan behavior.

Acceptance criteria:
- Markdown renders bold, italic, code, code blocks, links, lists, and headings safely (no raw HTML).
- Emote shortcodes (e.g., `:thumbsup:`) render as emoji in message display.
- Link previews fail gracefully without blocking message send.
- Reaction notifications respect user preference settings.
- Server-wide pinned messages are visible from any channel context and link back to the source.
- Pin/unpin operations are durable, auditable, and reflected across all clients.
- Mark-unread operations are durable and reflected in unread counters.
- Channel message search returns relevant results with stable ordering.
- BDD scenarios cover server-wide pin/unpin, media/reaction/unread/search behavior.

#### Phase 12.8: Threaded conversations
Status:
- Planned.

Goals:
- Add threaded conversation support for focused, context-preserving discussions within channels.

Scope:
- A reply to a message creates a reply link (first reply stays inline in the channel).
- When a second reply is sent to the same message, the conversation automatically becomes a thread.
- Threads open in a dedicated right-hand pane showing only the messages inside the thread.
- Thread-level notification controls: auto-follow on reply, manual follow/unfollow.
- Optional "also send to channel" toggle when posting inside a thread.
- Thread reply count and latest-reply preview displayed inline on the parent message in the channel.
- "Threads" inbox view aggregating all threads the user is following, with unread indicators.

Implementation notes:
- Thread promotion (reply → thread) should be backend-authoritative: when a second reply targets any of the other messages in the reply, the backend creates a thread entity and reparents existing replies.
- Thread message streams should be independently paginated from channel message streams.

Acceptance criteria:
- A single reply stays inline; a reply to either of the replies automatically promotes to a thread.
- Thread pane displays only thread messages and is independently scrollable from the channel view.
- Thread notification subscriptions are independent of channel-level notification settings.
- "Threads" inbox shows all followed threads with accurate unread state.
- BDD scenarios cover threading promotion/lifecycle and thread-pane rendering.

#### Phase 12.9: Push notifications
Status:
- Planned.

Goals:
- Deliver reliable, policy-aware push notifications for mobile and desktop while avoiding noisy delivery.

Scope:
- Device registration lifecycle for push tokens/endpoints (register, rotate, revoke).
- Platform delivery adapters for Android, iOS, and desktop-supported push surfaces where available.
- Push delivery for high-signal events:
	- Mentions.
	- Direct messages.
	- Friend request lifecycle transitions.
	- Optional reactions/replies based on user settings.
- Respect existing notification preference precedence (global, server, channel, temporary mute).
- Quiet hours and per-event-type push toggles in notification settings.

Implementation notes:
- Keep provider credentials and signing material in runtime secret stores, never in source control.
- Reuse existing notification policy evaluation before enqueueing push payloads.
- Apply retry with bounded backoff and dead-letter handling for provider failures.
- Keep payloads minimal and privacy-safe on lock screens.

Acceptance criteria:
- Push notifications are delivered only when allowed by user notification policies.
- Duplicate push delivery is suppressed for retried or rapidly repeated events.
- Revoked or expired device tokens are detected and cleaned up automatically.
- Quiet hours suppress push delivery while preserving unread state and in-app notification history.
- BDD scenarios cover device registration lifecycle, policy-filtered delivery, and retry/dead-letter behavior.

#### Phase 13 (Weeks 11-12): Settings IA and discoverability
Status:
- Planned.

Goals:
- Make the growing configuration surface navigable and understandable.

Scope:
- Settings search with indexed sections for account, notifications, friends/DMs, chat behavior, and accessibility.
- Full configuration surfaces for all new notification and social/chat features.
- Clear defaults and reset-to-default behavior for each settings group.

Implementation notes:
- Keep settings state semantic in BLoCs and move all display text decisions to widgets.
- Reuse shared settings section components rather than adding custom ad-hoc layouts per feature.

Acceptance criteria:
- Settings search finds feature toggles by label and common synonyms.
- Every feature flag added in phases 5-8 has a discoverable settings entry.
- No configuration path requires hidden navigation gestures.
- BDD covers settings discoverability and persistence of major toggles.

#### Phase 13.1: Automatic openapi wiring
Status:
- Completed.

Goals:
- Improve api spec dev experience

Progress:
- Completed: added `utoipa-axum` dependency and replaced manual `Router::new().route(...)` with `OpenApiRouter` and `routes!()` macro so OpenAPI paths are registered automatically alongside route handlers.
- Completed: removed manual `paths(...)` list from `#[openapi]` derive in `openapi.rs`; paths are now collected by `OpenApiRouter` at router composition time.
- Completed: added `#[utoipa::path]` annotations and `ToSchema` derives to all friends, blocks, and direct message route handlers that were previously undocumented in the OpenAPI spec.
- Completed: replaced single `"backend-api"` tag with entity-based tags across all endpoints: Health, Identity, Users, Servers, Channels, Messages, Voice, Notifications, Friends, Blocks, Direct Messages.
- Completed: all notification and friends/DMs schemas were added to OpenAPI component schemas.
- Validation: backend quality gates pass (`cargo clippy --workspace --all-targets -- -D warnings`, `cargo test` with 97 BDD scenarios).

#### Phase 13.2: Improve cucumber dev experience and readability
Status:
- Completed.

Goals:
- Improve cucumber test dev experience and ease of understanding

Scope:
- Replace all (where possible) regexes with named parameters as per the cucumber (rust compatible) spec

Implementation notes:
- cucumber implementations for steps should overwhelmingly (entirely) use "{*name*}" instead of the equivalent regex with typed where possible

Progress:
- Completed: all `#[given/when/then(regex = ...)]` step attributes across 5 BDD step definition files were converted to `#[given/when/then(expr = ...)]` using cucumber expression syntax.
- Completed: `"([^"]+)"` regex capture groups replaced with `{string}` named parameters across all step files.
- Completed: `([0-9]+)` regex capture groups replaced with `{int}` named parameters for integer step parameters.
- Completed: `(muted|unmuted)` and `(present|absent)` regex alternation groups replaced with `{word}` named parameters for enum-like step parameters.
- Completed: 108 regex step definitions converted across `servers_and_channels_steps.rs`, `messages_steps.rs`, `voice_sessions_steps.rs`, `notifications_steps.rs`, and `friends_and_dms_steps.rs`.
- Completed: `auth_and_health_steps.rs` and `identity_and_users_steps.rs` already used plain string step matching (no regex patterns to convert).
- Validation: `cargo clippy --workspace --all-targets -- -D warnings` passes clean.
- Validation: `cargo test --workspace` passes with 97 BDD scenarios (all passing).


#### Phase 13.3: Rust backend maintainability, type safety, and performance hardening
Status:
- Planned.

Goals:
- Improve backend maintainability and runtime performance by favoring immutability, pure functions, and compile-time safety.
- Reduce invalid-state and schema-drift risk by encoding constraints in types and validated boundaries.

Scope:
- Introduce typestate-driven transitions for friend request lifecycle operations where valid transitions can be enforced at compile time.
- Refactor mutable domain update paths to immutable transition methods that return new values rather than mutating existing state.
- Expand validated value-object boundaries (for example display-name and external-reference invariants) using `TryFrom`/`FromStr` and typed error models.
- Replace manual enum string conversion/parsing with derive-driven conversion patterns (`strum`, `sqlx::Type`) and Postgres enum backing where applicable.
- Tighten repository error modeling to separate business outcomes (forbidden/not-found/conflict) from infrastructure/storage failures.
- Tighten and centralize repository error to api error response conversion (mutation not found to http not found etc) 
- Reduce dynamic allocation overhead in async repository traits by moving from boxed async-trait patterns to native async trait patterns where toolchain support allows.
- Centralize policy-resolution logic (for example notification precedence) into shared pure functions used by both in-memory and postgres paths.
- Migrate DB enum-like text columns to explicit Postgres enum types where domain enums already exist.
- Adopt compile-time SQL validation with `sqlx::query!`/`query_as!`/`query_scalar!` and offline metadata in CI, with migration updates as the source of truth.

Implementation notes:
- Keep domain transitions explicit and side-effect free; keep side effects at repository/API boundaries.
- Prefer standard conversion traits and avoid ad-hoc conversion helpers when no additional context is required.
- Stage rollout by subsystem (messages, channels, friends, notifications) to keep migrations and refactors reviewable.

Acceptance criteria:
- Illegal friend-request transition paths are unrepresentable or rejected through typed transition APIs.
- Domain update APIs used in core flows are immutable and test-covered.
- Value objects reject invalid input at construction boundaries with explicit error types.
- Repository methods do not collapse infrastructure failures into not-found/forbidden business outcomes.
- Enum persistence and parsing paths are derive-driven with no duplicated manual string mapping in core flows.
- Notification precedence logic is implemented once and reused across storage backends.
- SQL query shape/type mismatches are caught at build time through compile-time validation in the postgres repository path.

#### Phase 14 (Weeks 13-14): User identity and workspace usability enhancements
Status:
- Planned.

Goals:
- Improve server-specific identity expression and reduce visual clutter in dense workspaces.

Scope:
- Server profiles: per-server display names.
- Member list visibility toggle with an easy-to-reach button.

Implementation notes:
- Server profile display names should resolve at render time with clear fallback to global identity.
- Member-list visibility state should be persisted per device/session as appropriate.

Acceptance criteria:
- Users can set and update a per-server display name without changing global identity.
- Member list can be hidden/restored in one interaction from the main chat view.
- Layout remains stable on compact viewports when member list visibility changes.
- BDD covers server profile naming precedence and member-list toggle behavior.

#### Phase 14.1: Typed extension IDs across Flutter domain and flows
Status:
- Planned.

Goals:
- Prevent ID wires being crossed accidentally by enforcing compile-time ID distinctions.

Scope:
- Introduce extension types for all core IDs (user/server/channel/message/thread/etc.) and migrate shared models, bloc events/state, repository queries/commands, and service boundaries to use them.
- Keep this explicit across layers even when implied by broader type-safety work.

Acceptance criteria:
- Passing an ID of the wrong entity type fails at compile time in core domain and repository/service call paths.

#### Phase 14.2: BLoC state transitions over constructor/copyWith mutation style
Status:
- Planned.

Goals:
- Keep state transitions explicit and semantic in BLoCs.

Scope:
- Standardize loaded-state transition methods (for example `load`, `select`, `clearSelection`, `append`, `fail`) and route state changes through those methods.
- Prefer named transition methods over generic `copyWith` usage so transition intent remains explicit and invalid combinations are harder to emit.

Acceptance criteria:
- Core BLoCs use explicit transition methods for state evolution, and direct constructor/copyWith state rewrites are reduced to boundary/bootstrap cases.

#### Phase 14.3: Loud enum contract failures in API-to-domain parsing
Status:
- Planned.

Goals:
- Surface backend contract drift immediately instead of silently defaulting.

Scope:
- Replace enum fallback parsing paths with strict lookups that throw on unknown values (for example `firstWhere` without `orElse`) so unknown transport values fail loudly.

Acceptance criteria:
- Unknown enum payload values trigger immediate failure with actionable diagnostics instead of defaulting to another variant.

#### Phase 14.4: Service-layer memory cache defaults
Status:
- Planned.

Goals:
- Introduce consistent caching behavior with safe defaults.

Scope:
- Add reusable `MemoryCache<T>` primitive(s) in the service layer with a default TTL so call sites are not required to specify TTL for every use.

Acceptance criteria:
- Service caches have a documented and tested default TTL, with optional overrides where required.

#### Phase 14.5: Entity-specific cache invalidation strategies
Status:
- Planned.

Goals:
- Prevent stale-data bugs by matching invalidation rules to entity behavior.

Scope:
- Define and implement explicit invalidation policies per entity surface (messages, servers, channels, friends/DMs, notification preferences, identity), including event-driven invalidation hooks and time-based expiry behavior where applicable.
- Document expected invalidation triggers for create/update/delete and membership/relationship changes.

Acceptance criteria:
- Cache invalidation behavior is deterministic per entity category and covered by automated tests for high-risk flows.

#### Phase 15 (Priority 0): Roles, permissions, and server governance
Status:
- Planned.

Goals:
- Establish enterprise-grade access control and governance for medium-to-large communities.

Scope:
- Role-based access control matrix for server/channel capabilities (read/write/speak/stream/attach/manage).
- Permission inheritance model across server, category, and channel levels.
- Governance tools for onboarding and controlled growth:
	- Invite links with expiry and usage limits.
	- Channel/category default permission templates.

Implementation notes:
- Keep permission evaluation backend-authoritative and expose semantic capability states to clients.
- Ensure deny/allow precedence rules are explicit and covered by BDD scenarios.

Acceptance criteria:
- Permission updates apply consistently across clients without stale authorization behavior.
- Inheritance and override behavior is deterministic and BDD-covered.
- Invite expiry/usage constraints are enforced and auditable.

#### Phase 16 (Priority 0): Moderation and trust/safety controls
Status:
- Planned.

Goals:
- Provide moderators and operators with practical tools to prevent abuse and recover quickly.

Scope:
- Report flows for users/messages with triage states.
- Moderation actions (warn, timeout, remove content, kick, ban) with reason capture.
- Anti-spam and anti-raid controls (rate limits, burst detection, and temporary hardening modes).
- Moderation audit log with actor/action/target/timestamp traceability.

Implementation notes:
- Keep moderation outcomes and policy checks backend-authoritative.
- Use bounded rate limiting and abuse heuristics that are configurable per deployment.

Acceptance criteria:
- Moderation actions are durable, visible in audit history, and reversible where applicable.
- Abuse controls reduce repeated spam/raid behavior without blocking normal usage patterns.
- BDD scenarios cover report lifecycle, enforcement paths, and auditability.

#### Phase 17 (Priority 0): Voice quality controls and realtime reliability
Status:
- Planned.

Goals:
- Reach TeamSpeak-class voice reliability and operator confidence under real network variability.

Scope:
- User voice controls: push-to-talk, voice activation threshold, input/output device fallback, per-user volume.
- Audio quality controls: noise suppression, echo cancellation, and quality profile presets.
- Participant audio controls: local mute of other participants and quick per-participant volume increase/reduction.
- Voice session quality analytics per channel and region:
	- Packet loss.
	- Jitter.
	- Reconnect rate.
	- Median join time.
- Voice participation analytics:
	- Time in channel.
	- Time spent speaking.
	- Time spent speaking over other participants.
	- Times being interrupted.
	- Times interrupting others.

Implementation notes:
- Validate reconnect and failover behavior with deterministic integration coverage.
- Keep voice analytics privacy-aware and aggregate-first for shared dashboards.
- Derive interruption/overlap metrics from server-timestamped speaking windows to avoid client clock skew.

Acceptance criteria:
- Voice join/rejoin behavior remains stable during transient disconnects.
- Voice quality controls are configurable and persisted across sessions.
- Channel and regional voice quality analytics are queryable with stable time windows.
- Participant audio controls apply immediately without affecting other users' own device settings.

#### Phase 18 (Priority 1): Messaging realtime UX and search at scale
Status:
- Planned.

Goals:
- Improve communication flow quality and retrieval performance as message volume grows.

Scope:
- Realtime UX signals: typing indicators, presence state, read-state semantics, thread subscription behavior.
- Message navigation UX: jump-to-message and context restoration.
- Search architecture: indexed retrieval, cross-channel/global search, retention-aware filtering, relevance ranking controls.
- Conversation momentum map analytics with timeline views for:
	- Burst windows.
	- Drop-off points.
	- Reactivation triggers.

Implementation notes:
- Keep search behavior pagination-first with stable ordering guarantees.
- Keep presence and typing events rate-limited and privacy-aware.
- Keep momentum analytics explainable by surfacing the top factors behind burst and drop-off transitions.

Acceptance criteria:
- Realtime signals remain timely without overwhelming event traffic.
- Search returns relevant, stable, and paginated results at higher message volumes.
- Momentum map highlights channel engagement rises/collapses with consistent timeline bucketing.
- BDD scenarios cover typing/presence/read-state semantics and search behavior.

#### Phase 19 (Priority 1): Platform parity and media lifecycle hardening
Status:
- Planned.

Goals:
- Ensure desktop/mobile parity and safe media handling across the full content lifecycle.

Scope:
- Platform parity: tray/taskbar behavior, startup/background behavior, deep links, and offline reconnection UX.
- End-to-end push-notification parity checks across supported clients.

Implementation notes:
- Keep client surfaces semantic; display copy and user prompts stay in widgets.

Acceptance criteria:
- Desktop and mobile behavior is consistent for notification and reconnection flows.
- BDD scenarios cover media lifecycle policy outcomes and parity-critical client behavior.

#### Phase 22 (Priority 2): Data governance and compliance posture
Status:
- Planned.

Goals:
- Prepare for regulated deployments without compromising core product velocity.

Scope:
- Data export/delete lifecycle for user-controlled data rights.
- Retention policy controls and legal-hold support.
- Regional data residency strategy and deployment constraints.

Acceptance criteria:
- Export/delete operations are auditable and policy-compliant.
- Retention/legal-hold behavior is deterministic and documented.
- BDD scenarios cover governance-critical data lifecycle outcomes.

#### Phase 24 (Priority 2): Performance budgets and release guardrails
Status:
- Planned.

Goals:
- Prevent performance regressions as feature surface expands.

Scope:
- Explicit budgets for app startup, message-send latency, voice-join latency, and memory usage.
- CI/CD guardrails that fail builds when defined budgets regress beyond thresholds.
- Load and regression test profiles for text, voice, and notification-heavy scenarios.

Acceptance criteria:
- Budget regressions are detected before release.
- Release gates enforce performance quality consistently across platforms.
- BDD smoke coverage includes critical latency-sensitive journeys.

#### Phase 25 (Priority 3): Improved UI look and feel
Status:
- Planned.

Goal:
- Improve frontend usability and visual personalization after core reliability/governance phases.

Scope:
- Improve the @mentions experience.
- Add multiple presets for colour scheme (scene green, scene purple, chroma, high contrast, monochrome) for both dark and light mode.

#### Stretch goal A: Fuzz testing
status:
- planned

goals:
- Improve robustness and security by finding edge cases and vulnerabilities

scope:
- Implement fuzz testing for critical backend components

#### Stretch goal B: Encryption at rest (future-facing)
status:
- planned

goals:
- Privacy-first design and user trust.

scope:
- All media (voice and video) is encrypted at rest and in transit between client(s) and server.
- All data is encrypted at rest and in transit between client(s) and server.
- The server cannot know what is being sent.

#### Stretch goal C: End-to-end encryption and storage-backed media
status:
- planned

goals:
- Privacy-first design, user trust, and user data protection in event of server breach/compromise.
- Deliver dynamic object-store-backed rich media capabilities after core collaboration scope is stable.

scope:
- All media (voice and video) is encrypted in transit between client(s) and server.
- All data is encrypted in transit between client(s) and server.
- The server cannot know what is being sent.
- Direct image upload in text chat with inline rendering.
- Dynamic object-store-backed custom emotes per server.
- Dynamic object-store-backed GIF emotes.
- Media lifecycle controls for object-store-backed assets:
	- Malware/content-policy scanning.
	- Quotas and retention/expiry policy.
	- CDN/cache invalidation and stale-content controls.

implementation notes:
- Put upload/cache concerns in service layer and avoid repository-level caching.


### Quality gates for expansion phases
- Rust changes must pass: `cargo clippy --workspace --all-targets -- -D warnings` and `cargo test`.
- Flutter changes must pass: `dart analyze` and `flutter test`.
- No skipped BDD scenarios are allowed in feature validation.
- MVP smoke flow plus new-feature smoke paths must pass on local/dev.

### New smoke paths to add
1. Notification policy precedence (global/server/channel/temporary mute) with badge counts.
2. Mention flow from compose to recipient notification.
3. Friend request to accepted DM conversation.
4. Blocked-user enforcement across friend actions and DM messaging.
5. Channel message search, pin/unpin, and mark-unread roundtrip.
6. Server profile display name rendering and member-list hide/show behavior.
7. Role/permission inheritance and override behavior across server/category/channel.
8. Moderation enforcement roundtrip (report, action, audit visibility, and reversal path).
9. Voice join under degraded network with reconnect and region failover behavior.
10. Platform parity check for deep links, background resume, and offline-to-online recovery.
11. Policy-enforced media lifecycle (scan, quota, retention, and cache invalidation).
12. Performance budget gate verification for startup, message-send, and voice-join latency.

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
- Planned

Scope: 
- Add Server name updating to the right click context menu (And the new Server Settings page, accessed by clicking on the name of the server in the channel list)
- Add Channel name updating to the right click context menu

#### Phase 12.5: Developer experience regarding the mobile client
Status:
- Planned

Goal:
- Improve debugability of the frontend client

Scope: 
- add a context menu item to more entities in the frontend when developer mode is enabled. This will copy the Id of the user
- Refactor all {Entity}Id fields, e.g. userId, to named extension types for compile time safety and preventing id wires being crossed accidentally

#### Phase 12.7 (Weeks 7-10): Text chat enhancements (media, reactions, threading, retrieval)
Status:
- Planned.

Goals:
- Improve message expressiveness and discoverability while maintaining moderation and performance guardrails.

Scope:
- Website previews (link unfurl metadata cards).
- Direct image upload in text chat with inline rendering.
- Link-based image rendering fallback when upload is unavailable.
- Preset emotes (global).
- Custom emotes per server.
- GIF emotes.
- Message reactions using emotes, including:
	- Notification behavior.
	- Quick list of most-used emotes.
- Replies to messages with optional "notify original author" checkbox.
- Mark message as unread in a chat.
- Pinned messages.
- Search through messages in a channel.

Implementation notes:
- Put upload/cache concerns in service layer and avoid repository-level caching.
- Reactions and reply notifications should be user-configurable and rate-limited to reduce spam.
- Channel search should support pagination and ranking to avoid full-scan behavior.

Acceptance criteria:
- Link previews fail gracefully without blocking message send.
- Uploaded and linked images render consistently across desktop/mobile.
- Reaction notifications respect user preference settings.
- Mark-unread and pin operations are durable and reflected in unread counters.
- Channel message search returns relevant results with stable ordering.
- BDD scenarios cover media/reaction/reply/pin/unread/search behavior.

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

#### Phase 17: Improved UI look and feel
Status:
- Planned

Goal:
- Improve usability of the frontend client

Scope: 
- Improve the @mentions experience
- Add multiple presets for Colour scheme - Scene green, scene purple, Chroma, high contrast, monochrome, etc For both dark and light mode

#### phase 18: Fuzz testing
status:
- planned

goals:
- Improve robustness and security by finding edge cases and vulnerabilities															

scope: 
- Implement fuzz testing for critical backend compoennts



#### phase 19: encryption at rest (Although taking the future into account)
status:
- planned

goals:
- privacy first design, user trust.

scope: 
- all media (voice and video) is encrypted at rest and in transit between client(s) and server
- all data is encrypted at rest and in transit between client(s) and server
- the server cannot know what is being sent

#### phase 20: end to end encryption
status:
- planned

goals:
- privacy first design, user trust, user data protection in event of server breach/compromise.

scope: 
- all media (voice and video) is encrypted in transit between client(s) and server
- all data is encrypted in transit between client(s) and server
- the server cannot know what is being sent


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

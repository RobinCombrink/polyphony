# polyphony

@~/.claude/stacks/rust.md
@~/.claude/stacks/flutter.md

## Local rules

- **Per-entity repository traits**: domain CRUD goes through per-entity repository traits
  (User, Server, Channel, Message, ...) — never a single god-trait; prefer `impl Trait` over
  `dyn` in hot paths.
- **Entity identity + DTO placement**: every persisted entity has a UUID primary key (a
  `#[repr(transparent)]` newtype id) and a `date_created` field; DTOs never live in the
  domain crate.
- **BDD dual-store**: backend BDD runs against in-memory and Postgres (Testcontainers) via
  the `BDD_STORE` env var, swapped behind the shared repository traits (see the
  `polyphony-bdd` skill).
- **Auth centralized in a sealed BLoC**: auth/bearer-token state lives in one
  `AuthenticationBloc` sealed-state hierarchy; authenticated BLoCs are gated below it,
  carrying a `Metadata` value object.
- **LiveKit architecture**: the Flutter client connects directly to LiveKit; the backend
  only issues short-lived tokens via the unified `channels/{id}/session` endpoint
  (session-type parameter) and performs privileged admin ops — it never proxies media.
  Channels are a sealed ADT in both languages.
- **Notifications ADT + outbox**: notification level is one enum applied at
  global/server/channel scope plus time-based mute, resolved by one centralized policy
  resolver; delivery is DB-authoritative + outbox + websocket.
- **No back-compat pre-launch** (time-bound — re-verify at launch): no compatibility
  shims or dual API shapes while nothing is in production.
- **PreferencesStore abstraction**: all local preference access goes through the one
  `PreferencesStore` abstraction with typed get/set; UI never touches `shared_preferences`
  directly.
- **Markdown security**: user markdown links are restricted to http/https via
  `url_launcher`; images render as alt text only — no remote image loading.

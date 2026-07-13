---
name: polyphony-bdd
description: Write and run polyphony's backend BDD suite — cucumber-rs mechanics, actor-model worlds, dual-store (in-memory/Postgres) runs, and EntitySeeder usage. Use whenever adding or changing Gherkin features, step definitions, or BDD test infrastructure.
---

# polyphony BDD

`.feature` files live in `features/` at the repo root; step definitions and worlds live in
`crates/backend-api/tests/`. The `.feature` file is written/updated FIRST, then the matching
Rust scenario steps, then production code. Feature files and step tests are audited in both
directions — no feature without steps, no steps without a feature.

## Generic cucumber-rs mechanics

(Generic to any Rust workspace using cucumber-rs — candidate for stack-tier promotion,
tracked in dotfiles #55.)

- cucumber 0.21.x API: `World::cucumber().run_and_exit("<feature-path>")` — no `WorldInit`
  import, no `.features(...)` builder. The feature path is relative to the crate root:
  from `crates/backend-api` it's `../../features/...`.
- Step definitions use named parameter placeholders (`{string}`, `{int}`), never raw regex
  captures.
- The Gherkin parser rejects scenarios whose first step is `And` — every scenario starts
  with `Given`/`When`/`Then`, even under a `Background`.
- Cucumber test binaries are custom test executables: `cargo test -- --nocapture`/`-q`
  passes those args to the binary and errors — run them without libtest flags.
- Assert helpers must not `expect()`/panic — use `assert_eq!(option.as_deref(), Some(...))`
  so one failure doesn't abort the whole run.

## Actor-model worlds (polyphony convention)

- Worlds resolve actors by name: `ensure_actor(name) -> ActorHandle { token, app, user_id }`
  cached in a `HashMap<String, ActorHandle>`. No positional owner/second-user fields, no
  order-dependent `Given`s doing HTTP plumbing.
- Fields that always exist (`app`, `shared_store`) are non-`Option`, assigned once at world
  bootstrap.
- Step helpers use the `backend_api::domain` typed wrappers (`UserId`, `ServerId`, ...) —
  never local UUID wrapper structs; payload id parsing is centralized via `payload_*_id`
  helpers.
- Websocket steps: build the request with `tokio_tungstenite`'s `IntoClientRequest`, then
  append auth headers — hand-crafting websocket headers breaks the handshake
  (`sec-websocket-key` invalid).
- No process-global statics in test infra (e.g. a global notification hub) — they leak
  state across scenarios and break user isolation. Use per-world injected instances.

## Dual-store runs (polyphony-specific)

- The suite runs against both stores, swapped behind the shared repository traits by the
  `BDD_STORE` env var: in-memory by default, Postgres via
  `BDD_STORE=postgres cargo test -p backend-api --tests` (Testcontainers; startup is slow —
  allow generous timeouts). Run the Postgres mode locally after storage-layer changes; the
  pre-push githook and CI force it.
- Postgres mode spins up **one Testcontainers Postgres per feature** (not per scenario),
  with the container handle owned so it's disposed — never `Box::leak` it.
- No database wiping/truncation between scenarios: isolation comes from
  unique-by-construction identities per actor/scenario.

## EntitySeeder

- Seed real domain types — never test-local structs.
- Pass only the properties the scenario is actually about; the seeder auto-generates
  everything else.

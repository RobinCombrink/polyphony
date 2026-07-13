---
name: implementing-a-slice
description: Implement a full-stack vertical feature slice in polyphony — backend (domain → storage → API/DTO → OpenAPI → BDD → cargo test) then Flutter (API model → service → repository → BLoC → widget → tests). Use when adding or extending any capability that crosses the backend/frontend boundary; the local companion to to-tickets/implement.
---

# Implementing a slice

One capability, end to end, backend first. Each half ends with its quality gates green
before moving on.

## Backend (crates/)

1. **Domain**: add/extend the entity or field in the domain crate. UUID-pk newtype id
   (`#[repr(transparent)]`, `From<Uuid>` construction only) + `date_created` on every
   persisted entity. No DTOs here — DTOs never live in the domain crate.
2. **Storage**: extend the per-entity repository trait and BOTH implementations
   (`InMemoryRepository`, `PostgresRepository`). New SQL goes in a migration
   (`crates/backend-storage/migrations/` — `build.rs` handles rebuild-on-change).
3. **API + DTO**: route handler in `backend-api`, DTOs at this layer. UUIDs typed
   in-process, strings only at the wire.
4. **OpenAPI**: `#[utoipa::path]` annotation with entity-based tags; register the path in
   the OpenAPI derive **using the handler's concrete/defining module path** — re-exported
   paths break compilation.
5. **BDD**: write/update the Gherkin `.feature` first, then the Rust scenario steps — see
   the `polyphony-bdd` skill for world/seeder mechanics.
6. **Gate**: `cargo clippy --workspace --all-targets -- -D warnings`, then
   `cargo test --workspace`. After storage changes also run the Postgres suite:
   `BDD_STORE=postgres cargo test -p backend-api --tests`.

## Frontend (apps/flutter_client/)

7. **API model**: regenerate the OpenAPI-generated Dart SDK
   (`tool/generate_openapi_sdk.dart`) or add the API model. For domain sum types crossing
   the boundary, use the enum-conversion pattern below.
8. **Service**: REST service method over the generated client.
9. **Repository**: repository method (CRUD mixin shapes; `getMany`/`updateMany` return
   `Iterable`).
10. **BLoC**: event + state + bloc as the standard 3-file triplet; sealed ADT states, one
    concern per BLoC.
11. **Widget**: wire the UI; ViewData models at the widget boundary; no business logic in
    widgets.
12. **Tests + gate**: BDD-named `flutter test` groups (`Feature:`/`Scenario:` labels — no
    Gherkin runner exists for Dart), then `dart analyze`, `flutter test`, and
    `dart format` on touched files.

## API-boundary enum conversion (standard for all tagged API contracts)

1. Declare an API-layer-only enum with constant string values for (de)serialization.
2. The API→domain converter parses the raw string into that enum, then switches on the
   enum — never on raw strings — to build the sealed domain subtype.
3. Nothing past the conversion layer sees the enum or raw strings.

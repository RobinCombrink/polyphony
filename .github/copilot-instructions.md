## Cross-Codebase Principles (Rust + Flutter)

These rules apply everywhere unless a language-specific rule below overrides implementation details.

Rule precedence for this file:
- If rules conflict, language-specific rules override cross-codebase rules.
- Architecture and layering rules override stylistic preferences.

- Prioritise functional style programming with pure functions and immutable data structures.
- Treat functional, immutable, and pure style as the default across the entire codebase.
- Avoid side effects and mutable state whenever possible.
- Prioritise early returns and guard clauses to reduce nesting and improve readability.
- Use descriptive variable and function names that clearly indicate purpose and behaviour.
- If any test is reported as skipped, treat the test run as a failure and investigate why.
- BDD scenarios should describe behaviour and outcomes, not implementation mechanics.
- When updating BDD tests, update feature files first, then implement step definitions.

## Project Architecture Layout

Use this repository layout and naming when creating or updating code.

- Root-level architecture:
- `apps/flutter_client/`: Flutter client application.
- `crates/backend-api/`: Rust HTTP/API crate (routes, DTOs, runtime wiring).
- `crates/backend-domain/`: Rust domain model crate (entities, ids, domain rules).
- `crates/backend-storage/`: Rust persistence crate (repository implementations, in-memory + postgres).
- `features/`: BDD feature files that describe expected product behaviour.

- Flutter client layout (`apps/flutter_client/lib`):
- `app/`: app shell/bootstrap (for example `polyphony_app_widget.dart`).
- `features/<feature_name>/`: feature-owned code (authentication, channels, messages, notifications, etc.).
- `shared/`: cross-feature building blocks (auth, models, network, repositories, result, services, presentation).

- Feature layout conventions:
- Keep feature code under `features/<feature_name>/` with subfolders like `bloc/` and `presentation/` as needed.
- Features may depend on `shared/*` but should not import code from other feature folders directly.
- BLoC should use three files by default:
- `<feature>_bloc.dart`
- `<feature>_event.dart`
- `<feature>_state.dart`
- Keep one public BLoC per concern; use separate BLoCs when a feature has distinct concerns (for example `servers_bloc` and `server_members_bloc`).
- Single-file BLoCs are never acceptable. Always split into bloc/event/state files.
- Presentation conventions:
- Prefer `presentation/pages/` for screen-level widgets and `presentation/widgets/` for reusable view components.
- Keep feature-specific mapping/conversion helpers in feature-owned files and use the extension method pattern `extensions/` instead of inline.

- Rust crate layout conventions:
- `backend-api/src/`: entrypoints and transport layer (`main.rs`, `lib.rs`, `routes/`, `dto/`, auth/config/observability).
- `backend-domain/src/`: pure domain types and invariants (`ids.rs`, entity/value-object modules).
- `backend-storage/src/`: repository contracts and implementations (`repository.rs`, `postgres_repository.rs`, `in_memory_repository.rs`).
- Rust dependency direction:
- `backend-api` may depend on `backend-domain` and `backend-storage`.
- `backend-storage` may depend on `backend-domain`.
- `backend-domain` should not depend on other workspace crates.

- Test and behaviour layout:
- Keep BDD behaviour in `features/*.feature`.
- Keep Rust tests in each crate's `tests/` directory and unit tests near source modules.
- Keep Flutter tests in `apps/flutter_client/test/` mirroring feature structure.

## Rust-Specific Rules

- Always run `cargo clippy --workspace --all-targets -- -D warnings` and `cargo test` after every Rust change.
- Always use typed `#[repr(transparent)]` structs for id/external_reference fields in domain entities, not type aliases or raw UUIDs.
- Always prioritise using standard library types and traits over custom implementations; for example, prefer `From<T>`/`TryFrom<T>` for conversions over custom implementations. The `From<>` and `TryFrom<>` traits should be implemented when converting from one type to another without any additional data. This is very common when going from API to domain or domain to API. `FromStr<T>` should be implemented when converting from a string to a type. This is very common for parsing values that will become an enum or a typed id. Custom conversion methods should only be used when the conversion requires additional context or parameters that cannot be captured by the standard traits.
- For Rust enums persisted to Postgres, use derive-driven conversions by default: in domain enums derive Strum traits (`EnumString`, `Display`, `AsRefStr`) and `sqlx::Type` with snake_case rename metadata, and model DB columns as Postgres enum types rather than `TEXT` plus manual parse/match conversion code.
- For Rust tests, use the EntitySeeder pattern and only pass properties that are part of scenario setup or assertions; let non-essential required fields be auto-generated by seeders.
- Never use `as` for Rust type conversions; implement `From`/`TryFrom` for explicit and safe conversions.
- Use `impl {Trait}` over `dyn {Trait}` in the overwhelming majority of cases for better performance and ergonomics; only use `dyn` when true dynamic dispatch is required (very rare).

## Flutter-Specific Rules

- Always run `dart analyze` and `flutter test` after every Flutter change.
- For Flutter tests, use the EntitySeeder pattern and only pass properties that are part of scenario setup or assertions; let non-essential required fields be auto-generated by seeders.
- Never use `as` in Dart for type coercions; use pattern matching or explicit type checks.
- Never catch `Object`, `Error`, or any non-`Exception` type. Only catch `Exception` types.
- API clients should return `Result<T>` values and not throw; represent failures in `Result` and handle them in the UI layer.
- Conversions between API and domain models must be implemented as extension methods in `api/domain_extensions/api_model_extensions` files, not inline in services, repositories, or BLoCs.
- Keep side effects at boundaries (API clients, repositories, runtime wiring). Keep feature/domain logic pure where practical.
- Use Widgets instead of methods for reusable UI components.
- Keep UI logic in BLoCs, not widgets. Widgets should render state only.
- UI display text must never be part of BLoC state or BLoC logic. BLoCs expose semantic state and required data; widgets decide display text.
- Prerequisite state checks inside BLoCs should use pattern matching (prefer switch expressions, then switch statements, and avoid null-flag branching patterns).
- Repositories can ONLY use services and API clients; they must not use other repositories. Services and API clients must not use repositories. This ensures a clear separation between pure data access logic (repositories) and side-effecting operations (services/API clients).
- Services should implement caching (if necessary), not repositories.
- Repositories MUST use the Repository Mixins for ALL public methods that they implement from their abstract interface. This ensures a consistent API and allows for easy swapping of implementations without changing the public interface.
Bloc events should never be published inside of the build method. It should only ever be inside of a Stateful widget's init state or inside a callback from a button (or similar user interaction), or inside a BloCListener
## Service and Caching Rules

- Implement caching in the service layer, not the repository layer.
- Reuse `MemoryCache<T>` for in-memory caching.
- Do not create separate cache classes per entity when `MemoryCache<T>` is sufficient.

## Definition of Done

- Build/analysis succeeds for changed areas.
- Relevant tests pass.
- No skipped tests remain.
- Lint checks pass with no warnings in enforced contexts.
- New files and symbols follow the architecture and naming conventions in this document.
- Do not leave placeholder TODOs without a linked issue/reference.
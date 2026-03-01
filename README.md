# Polyphony

Polyphony is a real-time communication platform with a Rust backend and a Flutter client.

## What this project includes

- **Backend API** for auth, identity, messaging, servers/channels, and voice session flows
- **Domain layer** for business entities and invariants
- **Storage layer** with migrations and persistence implementation
- **Flutter client** for cross-platform user experiences
- **Infrastructure as code** for cloud provisioning and environment setup
- **BDD feature coverage** for behavior-focused acceptance tests

## High-level technology choices

### Backend (Rust)

- **Language/runtime:** Rust
- **Architecture:** multi-crate workspace with clear boundaries:
  - `backend-api`: transport, DTOs, routing, OpenAPI wiring
  - `backend-domain`: core domain entities and rules
  - `backend-storage`: persistence and database migrations
- **Testing:** unit tests + BDD acceptance scenarios in `features/` and `backend-api/tests/`

Why this choice:
- Strong type safety and performance for network services
- Clear separation between API, domain, and persistence concerns
- Reliable refactoring in a growing codebase

### Client (Flutter)

- **Framework:** Flutter/Dart
- **Target platforms:** web + desktop/mobile foundations via a shared codebase
- **Client structure:** feature-oriented modules under `apps/flutter_client/lib/`

Why this choice:
- Single UI codebase across platforms
- Fast iteration for UX and state-driven interfaces
- Good fit for shared product behavior across targets

### Infrastructure & operations

- **Containerized local dependencies:** Docker Compose (`docker-compose.local.yml`)
- **Real-time media/config support:** LiveKit local config (`livekit.local.yaml`)
- **Infrastructure as code:** Pulumi (`pulumi/`)

Why this choice:
- Reproducible local environments
- Explicit, versioned infrastructure changes
- Consistent developer setup and deployment workflows

## Repository layout

```text
apps/flutter_client/   # Flutter application
crates/                # Experimental/support Rust crates
backend-api/           # API crate
backend-domain/        # Domain crate
backend-storage/       # Storage crate + migrations
features/              # BDD feature files
pulumi/                # Infrastructure as code
```

## Getting started (local)

1. Start local dependencies (for services that require containers).
2. Run backend tests from the repository root:
   - `cargo test`
3. Run Flutter tests from the Flutter app directory:
   - `flutter test`

See also:
- `docs/local-dev.md`
- `apps/flutter_client/README.md`
- `pulumi/README.md`

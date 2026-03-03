FROM rust:1.90-bookworm AS builder

WORKDIR /app

COPY Cargo.toml Cargo.toml
COPY crates/backend-api/Cargo.toml crates/backend-api/Cargo.toml
COPY crates/backend-domain/Cargo.toml crates/backend-domain/Cargo.toml
COPY crates/backend-storage/Cargo.toml crates/backend-storage/Cargo.toml
COPY crates/backend-api/src crates/backend-api/src
COPY crates/backend-domain/src crates/backend-domain/src
COPY crates/backend-storage/src crates/backend-storage/src
COPY crates/backend-storage/migrations crates/backend-storage/migrations
COPY crates/backend-storage/build.rs crates/backend-storage/build.rs

RUN cargo build --release -p backend-api

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /app/target/release/backend-api /usr/local/bin/backend-api

EXPOSE 5067

CMD ["backend-api"]
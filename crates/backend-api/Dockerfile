# syntax=docker/dockerfile:1.7

FROM rust:1.94-bookworm AS chef

RUN cargo install cargo-chef --locked

WORKDIR /app

FROM chef AS planner

WORKDIR /app

COPY . .

RUN cargo chef prepare --recipe-path recipe.json

FROM chef AS builder

WORKDIR /app

ARG BUILD_PROFILE=release

COPY --from=planner /app/recipe.json recipe.json

RUN --mount=type=cache,id=polyphony-cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=polyphony-cargo-git,target=/usr/local/cargo/git \
        if [ "$BUILD_PROFILE" = "release" ]; then \
            cargo chef cook --release --locked --recipe-path recipe.json; \
        else \
            cargo chef cook --locked --recipe-path recipe.json; \
        fi

COPY . .

RUN --mount=type=cache,id=polyphony-cargo-registry,target=/usr/local/cargo/registry \
    --mount=type=cache,id=polyphony-cargo-git,target=/usr/local/cargo/git \
        if [ "$BUILD_PROFILE" = "release" ]; then \
            cargo build --release -p backend-api --locked; \
            cp /app/target/release/backend-api /tmp/backend-api; \
        else \
            cargo build -p backend-api --locked; \
            cp /app/target/debug/backend-api /tmp/backend-api; \
        fi

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /tmp/backend-api /usr/local/bin/backend-api

EXPOSE 5067

CMD ["backend-api"]
pub mod auth;
pub mod config;
pub mod domain;
pub mod observability;

use std::{net::SocketAddr, sync::Arc};

use auth::{AuthState, AuthenticatedUser, JwksTokenVerifier, TokenVerifier};
use axum::{
    Json, Router,
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::get,
};
use serde::Serialize;
use tower_http::trace::TraceLayer;
use utoipa::openapi::{
    Components,
    security::{HttpAuthScheme, HttpBuilder, SecurityScheme},
};
use utoipa::{Modify, OpenApi, ToSchema};
use utoipa_swagger_ui::{Config, SwaggerUi};

#[derive(Clone)]
pub struct ApiState {
    pub auth_state: Arc<AuthState>,
}

#[derive(Serialize, ToSchema)]
struct HealthResponse {
    status: &'static str,
    service: &'static str,
}

#[derive(Serialize, ToSchema)]
struct MeResponse {
    user_id: String,
    issuer: String,
    token_duration_hours: u64,
}

#[derive(OpenApi)]
#[openapi(
    paths(health, me),
    components(schemas(HealthResponse, MeResponse)),
    modifiers(&ApiSecurityAddon),
    tags((name = "backend-api", description = "Polyphony backend API"))
)]
struct ApiDocumentation;

struct ApiSecurityAddon;

impl Modify for ApiSecurityAddon {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        let components = openapi.components.get_or_insert_with(Components::new);

        components.add_security_scheme(
            "bearer_auth",
            SecurityScheme::Http(
                HttpBuilder::new()
                    .scheme(HttpAuthScheme::Bearer)
                    .bearer_format("JWT")
                    .build(),
            ),
        );
    }
}

pub fn default_bind_address() -> SocketAddr {
    config::BackendApiConfig::from_environment().bind_address
}

pub fn default_api_state() -> ApiState {
    let auth_config = config::BackendApiConfig::from_environment().auth0;
    let token_verifier: Arc<dyn TokenVerifier> = Arc::new(JwksTokenVerifier::new(auth_config.clone()));

    ApiState {
        auth_state: Arc::new(AuthState::new(auth_config, token_verifier)),
    }
}

pub fn build_app(state: ApiState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/api/v1/me", get(me))
        .merge(
            SwaggerUi::new("/openapi")
                .url("/api-docs/openapi.json", ApiDocumentation::openapi())
                .config(Config::default().try_it_out_enabled(true)),
        )
        .with_state(state)
        .layer(TraceLayer::new_for_http())
}

#[utoipa::path(
    get,
    path = "/health",
    responses(
        (status = 200, description = "Backend API health status", body = HealthResponse)
    ),
    tag = "backend-api"
)]
async fn health() -> impl IntoResponse {
    Json(HealthResponse {
        status: "ok",
        service: "backend-api",
    })
}

#[utoipa::path(
    get,
    path = "/api/v1/me",
    responses(
        (status = 200, description = "Authenticated user identity", body = MeResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
async fn me(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse {
    let response = MeResponse {
        user_id: authenticated_user.subject,
        issuer: state.auth_state.config.issuer.to_string(),
        token_duration_hours: state.auth_state.config.token_duration_hours,
    };

    (StatusCode::OK, Json(response))
}

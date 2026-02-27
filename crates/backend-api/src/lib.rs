pub mod auth;
pub mod config;
pub mod dto;
pub mod observability;
mod openapi;
mod routes;

pub use backend_domain as domain;
pub use backend_storage as storage;

use std::{net::SocketAddr, sync::Arc};

use auth::{AuthState, JwksTokenVerifier, TokenVerifier};
use axum::routing::{patch, post};
use axum::{Router, routing::get};
use backend_storage::{ChatRepository, InMemoryChatRepository};
use http::{HeaderValue, Method};
use openapi::ApiDocumentation;
use routes::{
    health::health,
    me::{me, update_me},
    messages::{create_message, delete_message, list_messages, update_message},
    servers::{add_server_member, create_channel, create_server, list_channels, list_servers},
    voice::connect_voice_session,
};
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::trace::TraceLayer;
use utoipa::OpenApi;
use utoipa_swagger_ui::{Config, SwaggerUi};

#[derive(Clone)]
pub struct ApiState {
    pub auth_state: Arc<AuthState>,
    pub store: Arc<dyn ChatRepository>,
    pub livekit_config: Arc<config::LiveKitConfig>,
}

pub fn default_bind_address() -> SocketAddr {
    config::BackendApiConfig::from_environment().bind_address
}

pub async fn default_api_state() -> ApiState {
    let backend_config = config::BackendApiConfig::from_environment();
    let auth_config = backend_config.auth0;
    let token_verifier: Arc<dyn TokenVerifier> = Arc::new(
        JwksTokenVerifier::new(auth_config.clone())
            .await
            .expect("jwt authorizer initialization to succeed"),
    );

    ApiState {
        auth_state: Arc::new(AuthState::new(auth_config, token_verifier)),
        store: Arc::new(InMemoryChatRepository::new()),
        livekit_config: Arc::new(backend_config.livekit),
    }
}

pub fn build_app(state: ApiState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/api/v1/me", get(me).patch(update_me))
        .route("/api/v1/servers", post(create_server).get(list_servers))
        .route(
            "/api/v1/servers/{server_id}/channels",
            post(create_channel).get(list_channels),
        )
        .route(
            "/api/v1/servers/{server_id}/members",
            post(add_server_member),
        )
        .route(
            "/api/v1/channels/{channel_id}/messages",
            post(create_message).get(list_messages),
        )
        .route(
            "/api/v1/channels/{channel_id}/messages/{message_id}",
            patch(update_message).delete(delete_message),
        )
        .route(
            "/api/v1/channels/{channel_id}/voice/connect",
            post(connect_voice_session),
        )
        .merge(
            SwaggerUi::new("/openapi")
                .url("/api-docs/openapi.json", ApiDocumentation::openapi())
                .config(Config::default().try_it_out_enabled(true)),
        )
        .with_state(state)
        .layer(build_cors_layer())
        .layer(TraceLayer::new_for_http())
}

fn build_cors_layer() -> CorsLayer {
    let default_origins = ["http://localhost:3000", "http://127.0.0.1:3000"];

    let configured_origins = std::env::var("BACKEND_API_CORS_ALLOWED_ORIGINS")
        .ok()
        .map(|value| {
            value
                .split(',')
                .map(str::trim)
                .filter(|origin| !origin.is_empty())
                .map(str::to_owned)
                .collect::<Vec<_>>()
        })
        .filter(|origins| !origins.is_empty())
        .unwrap_or_else(|| {
            default_origins
                .iter()
                .map(|origin| origin.to_string())
                .collect()
        });

    let allowed_origins = configured_origins
        .iter()
        .filter_map(|origin| HeaderValue::from_str(origin).ok())
        .collect::<Vec<_>>();

    let allow_origin = if allowed_origins.is_empty() {
        AllowOrigin::list(
            default_origins
                .iter()
                .filter_map(|origin| HeaderValue::from_str(origin).ok()),
        )
    } else {
        AllowOrigin::list(allowed_origins)
    };

    CorsLayer::new()
        .allow_origin(allow_origin)
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PATCH,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers(tower_http::cors::Any)
}

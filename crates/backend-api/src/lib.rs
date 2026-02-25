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
use openapi::ApiDocumentation;
use routes::{
    health::health,
    me::me,
    messages::{create_message, delete_message, list_messages, update_message},
    servers::{create_channel, create_server, list_channels, list_servers},
};
use tower_http::trace::TraceLayer;
use utoipa::OpenApi;
use utoipa_swagger_ui::{Config, SwaggerUi};

#[derive(Clone)]
pub struct ApiState {
    pub auth_state: Arc<AuthState>,
    pub store: Arc<dyn ChatRepository>,
}

pub fn default_bind_address() -> SocketAddr {
    config::BackendApiConfig::from_environment().bind_address
}

pub async fn default_api_state() -> ApiState {
    let auth_config = config::BackendApiConfig::from_environment().auth0;
    let token_verifier: Arc<dyn TokenVerifier> = Arc::new(
        JwksTokenVerifier::new(auth_config.clone())
            .await
            .expect("jwt authorizer initialization to succeed"),
    );

    ApiState {
        auth_state: Arc::new(AuthState::new(auth_config, token_verifier)),
        store: Arc::new(InMemoryChatRepository::new()),
    }
}

pub fn build_app(state: ApiState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/api/v1/me", get(me))
        .route("/api/v1/servers", post(create_server).get(list_servers))
        .route(
            "/api/v1/servers/{server_id}/channels",
            post(create_channel).get(list_channels),
        )
        .route(
            "/api/v1/channels/{channel_id}/messages",
            post(create_message).get(list_messages),
        )
        .route(
            "/api/v1/channels/{channel_id}/messages/{message_id}",
            patch(update_message).delete(delete_message),
        )
        .merge(
            SwaggerUi::new("/openapi")
                .url("/api-docs/openapi.json", ApiDocumentation::openapi())
                .config(Config::default().try_it_out_enabled(true)),
        )
        .with_state(state)
        .layer(TraceLayer::new_for_http())
}

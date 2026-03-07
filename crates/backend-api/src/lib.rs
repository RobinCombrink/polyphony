pub mod auth;
pub mod config;
pub mod dto;
pub mod notification_hub;
pub mod observability;
mod openapi;
mod routes;

pub use backend_domain as domain;
pub use backend_storage as storage;

use std::{net::SocketAddr, sync::Arc};

use auth::{AuthState, JwksTokenVerifier};
use axum::routing::{patch, post};
use axum::{Router, routing::get};
use backend_storage::{
    ChannelRepository, MessageRepository, NotificationRepository, PostgresRepository,
    ServerRepository, UserRepository,
};
use http::{HeaderValue, Method};
use openapi::ApiDocumentation;
use routes::{
    health::health,
    me::{me, update_me},
    messages::{create_message, delete_message, list_messages, update_message},
    notifications::{
        mark_channel_notifications_read, unread_notifications_count, websocket_notifications,
    },
    servers::{
        add_server_member, create_channel, create_server, delete_channel, delete_server,
        list_channels, list_server_members, list_servers, update_channel,
    },
    users::get_user_by_id,
    voice::create_session,
};
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::trace::{
    DefaultMakeSpan, DefaultOnFailure, DefaultOnRequest, DefaultOnResponse, TraceLayer,
};
use utoipa::OpenApi;
use utoipa_swagger_ui::{Config, SwaggerUi};

use crate::auth::TokenVerifier;
use crate::notification_hub::NotificationHub;

pub struct ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    pub auth_state: Arc<AuthState<Verifier>>,
    pub user_repository: Arc<UserRepo>,
    pub server_repository: Arc<ServerRepo>,
    pub channel_repository: Arc<ChannelRepo>,
    pub message_repository: Arc<MessageRepo>,
    pub livekit_config: Arc<config::LiveKitConfig>,
    pub notification_hub: Arc<NotificationHub>,
}

impl<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>
    ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    pub fn new(
        auth_state: Arc<AuthState<Verifier>>,
        user_repository: Arc<UserRepo>,
        server_repository: Arc<ServerRepo>,
        channel_repository: Arc<ChannelRepo>,
        message_repository: Arc<MessageRepo>,
        livekit_config: Arc<config::LiveKitConfig>,
    ) -> Self {
        Self {
            auth_state,
            user_repository,
            server_repository,
            channel_repository,
            message_repository,
            livekit_config,
            notification_hub: Arc::new(NotificationHub::default()),
        }
    }
}

impl<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier> Clone
    for ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    fn clone(&self) -> Self {
        Self {
            auth_state: self.auth_state.clone(),
            user_repository: self.user_repository.clone(),
            server_repository: self.server_repository.clone(),
            channel_repository: self.channel_repository.clone(),
            message_repository: self.message_repository.clone(),
            livekit_config: self.livekit_config.clone(),
            notification_hub: self.notification_hub.clone(),
        }
    }
}

pub type DefaultApiState = ApiState<
    PostgresRepository,
    PostgresRepository,
    PostgresRepository,
    PostgresRepository,
    JwksTokenVerifier,
>;

pub fn default_bind_address() -> SocketAddr {
    config::BackendApiConfig::from_environment().bind_address
}

pub async fn default_api_state() -> DefaultApiState {
    default_api_state_with_config(config::BackendApiConfig::from_environment()).await
}

pub async fn default_api_state_with_config(
    backend_config: config::BackendApiConfig,
) -> DefaultApiState {
    let auth_config = backend_config.auth0;
    let token_verifier = Arc::new(
        JwksTokenVerifier::new(auth_config.clone())
            .await
            .expect("jwt authorizer initialization to succeed"),
    );

    let repository = Arc::new(
        PostgresRepository::connect(
            &backend_config.postgres.host,
            backend_config.postgres.port,
            &backend_config.postgres.database,
            &backend_config.postgres.username,
            &backend_config.postgres.password,
            backend_config.postgres.max_connections,
        )
        .await
        .expect("postgres repository initialization to succeed"),
    );
    let user_store = repository.clone();
    let server_store = repository.clone();
    let channel_store = repository.clone();
    let message_store = repository;

    ApiState::new(
        Arc::new(AuthState::new(auth_config, token_verifier)),
        user_store,
        server_store,
        channel_store,
        message_store,
        Arc::new(backend_config.livekit),
    )
}

pub fn build_app<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    state: ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
) -> Router
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: auth::TokenVerifier + Send + Sync + 'static,
{
    let backend_config = config::BackendApiConfig::from_environment();
    build_app_with_runtime_settings(
        state,
        backend_config.http_request_logging,
        backend_config.allowed_cors_origins(),
    )
}

pub fn build_app_with_runtime_settings<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    state: ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
    http_request_logging: config::HttpRequestLoggingConfig,
    cors_allowed_origins: Vec<String>,
) -> Router
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: auth::TokenVerifier + Send + Sync + 'static,
{
    let router = Router::new()
        .route("/health", get(health))
        .route("/api/v1/me", get(me).patch(update_me))
        .route("/api/v1/users/{user_id}", get(get_user_by_id))
        .route("/api/v1/servers", post(create_server).get(list_servers))
        .route(
            "/api/v1/servers/{server_id}",
            axum::routing::delete(delete_server),
        )
        .route(
            "/api/v1/servers/{server_id}/channels",
            post(create_channel).get(list_channels),
        )
        .route(
            "/api/v1/servers/{server_id}/members",
            post(add_server_member).get(list_server_members),
        )
        .route(
            "/api/v1/channels/{channel_id}/messages",
            post(create_message).get(list_messages),
        )
        .route(
            "/api/v1/channels/{channel_id}",
            patch(update_channel).delete(delete_channel),
        )
        .route(
            "/api/v1/channels/{channel_id}/messages/{message_id}",
            patch(update_message).delete(delete_message),
        )
        .route(
            "/api/v1/channels/{channel_id}/session",
            post(create_session),
        )
        .route(
            "/api/v1/channels/{channel_id}/notifications/read",
            post(mark_channel_notifications_read),
        )
        .route(
            "/api/v1/notifications/unread-count",
            get(unread_notifications_count),
        )
        .route("/api/v1/notifications/ws", get(websocket_notifications))
        .merge(
            SwaggerUi::new("/openapi")
                .url("/api-docs/openapi.json", ApiDocumentation::openapi())
                .config(Config::default().try_it_out_enabled(true)),
        )
        .with_state(state)
        .layer(build_cors_layer(cors_allowed_origins));

    if http_request_logging.enabled {
        let log_level = http_request_logging.level.as_tracing_level();

        let trace_layer = TraceLayer::new_for_http()
            .make_span_with(
                DefaultMakeSpan::new()
                    .level(log_level)
                    .include_headers(false),
            )
            .on_request(DefaultOnRequest::new().level(log_level))
            .on_response(
                DefaultOnResponse::new()
                    .level(log_level)
                    .include_headers(false),
            )
            .on_failure(DefaultOnFailure::new().level(log_level));

        router.layer(trace_layer)
    } else {
        router
    }
}

fn build_cors_layer(configured_origins: Vec<String>) -> CorsLayer {
    let allowed_origins = configured_origins
        .iter()
        .filter_map(|origin| HeaderValue::from_str(origin).ok())
        .collect::<Vec<_>>();

    let allow_origin = AllowOrigin::list(allowed_origins);

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

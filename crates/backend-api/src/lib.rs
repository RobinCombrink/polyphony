pub mod auth;
pub mod config;
pub mod dto;
pub mod notification_hub;
pub mod observability;
mod openapi;
mod routes;

pub use backend_domain as domain;
pub use backend_storage as storage;

use std::{collections::HashSet, net::SocketAddr, sync::Arc};

use auth::{AuthState, JwksTokenVerifier};
use axum::Router;
use axum::routing::get;
use backend_storage::{
    BlockRepository, ChannelRepository, DirectMessageRepository, FriendRepository,
    MessageRepository, NotificationRepository, PostgresRepository, ServerRepository,
    UserRepository,
};
use http::{HeaderValue, Method, Request, header::AUTHORIZATION};
use openapi::ApiDocumentation;
use routes::{
    friends_and_dms::{
        __path_accept_friend_request, __path_block_user, __path_cancel_friend_request,
        __path_decline_friend_request, __path_list_blocked_users,
        __path_list_direct_message_threads, __path_list_direct_messages, __path_list_friends,
        __path_list_incoming_friend_requests, __path_list_outgoing_friend_requests,
        __path_open_or_get_direct_message_thread, __path_search_direct_messages,
        __path_send_direct_message, __path_send_friend_request,
        __path_send_friend_request_from_server_context, __path_unblock_user, accept_friend_request,
        block_user, cancel_friend_request, decline_friend_request, list_blocked_users,
        list_direct_message_threads, list_direct_messages, list_friends,
        list_incoming_friend_requests, list_outgoing_friend_requests,
        open_or_get_direct_message_thread, search_direct_messages, send_direct_message,
        send_friend_request, send_friend_request_from_server_context, unblock_user,
    },
    health::{__path_health, health},
    link_preview::{__path_link_preview, link_preview},
    me::{__path_me, __path_update_me, me, update_me},
    messages::{
        __path_create_message, __path_delete_message, __path_list_messages, __path_update_message,
        create_message, delete_message, list_messages, update_message,
    },
    notifications::{
        __path_channel_notification_preference, __path_global_notification_preference,
        __path_mark_channel_notifications_read, __path_mute_channel_notifications,
        __path_server_notification_preference, __path_unmute_channel_notifications,
        __path_unread_notifications_count, __path_update_channel_notification_preference,
        __path_update_global_notification_preference, __path_update_server_notification_preference,
        channel_notification_preference, global_notification_preference,
        mark_channel_notifications_read, mute_channel_notifications,
        server_notification_preference, unmute_channel_notifications, unread_notifications_count,
        update_channel_notification_preference, update_global_notification_preference,
        update_server_notification_preference, websocket_notifications,
    },
    servers::{
        __path_add_server_member, __path_create_channel, __path_create_server,
        __path_delete_channel, __path_delete_server, __path_invite_friend_to_server,
        __path_list_channels, __path_list_server_members, __path_list_servers,
        __path_update_channel, __path_update_server, add_server_member, create_channel,
        create_server, delete_channel, delete_server, invite_friend_to_server, list_channels,
        list_server_members, list_servers, update_channel, update_server,
    },
    users::{__path_get_user_by_id, get_user_by_id},
    voice::{__path_create_session, create_session},
};
use tower_http::cors::{AllowOrigin, CorsLayer};
use tower_http::sensitive_headers::SetSensitiveRequestHeadersLayer;
use tower_http::trace::{DefaultOnFailure, DefaultOnRequest, DefaultOnResponse, TraceLayer};
use url::form_urlencoded;
use utoipa::OpenApi;
use utoipa_axum::router::OpenApiRouter;
use utoipa_axum::routes;
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
    MessageRepo: MessageRepository
        + NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
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
    MessageRepo: MessageRepository
        + NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: auth::TokenVerifier + Send + Sync + 'static,
{
    let (router, api) = OpenApiRouter::with_openapi(ApiDocumentation::openapi())
        .routes(routes!(health))
        .routes(routes!(link_preview))
        .routes(routes!(me, update_me))
        .routes(routes!(get_user_by_id))
        .routes(routes!(create_server, list_servers))
        .routes(routes!(list_friends))
        .routes(routes!(list_incoming_friend_requests))
        .routes(routes!(list_outgoing_friend_requests))
        .routes(routes!(send_friend_request))
        .routes(routes!(send_friend_request_from_server_context))
        .routes(routes!(accept_friend_request))
        .routes(routes!(decline_friend_request))
        .routes(routes!(cancel_friend_request))
        .routes(routes!(list_blocked_users))
        .routes(routes!(block_user, unblock_user))
        .routes(routes!(list_direct_message_threads))
        .routes(routes!(open_or_get_direct_message_thread))
        .routes(routes!(send_direct_message, list_direct_messages))
        .routes(routes!(search_direct_messages))
        .routes(routes!(update_server, delete_server))
        .routes(routes!(create_channel, list_channels))
        .routes(routes!(add_server_member, list_server_members))
        .routes(routes!(invite_friend_to_server))
        .routes(routes!(create_message, list_messages))
        .routes(routes!(update_channel, delete_channel))
        .routes(routes!(update_message, delete_message))
        .routes(routes!(create_session))
        .routes(routes!(mark_channel_notifications_read))
        .routes(routes!(
            channel_notification_preference,
            update_channel_notification_preference
        ))
        .routes(routes!(mute_channel_notifications))
        .routes(routes!(unmute_channel_notifications))
        .routes(routes!(unread_notifications_count))
        .routes(routes!(
            global_notification_preference,
            update_global_notification_preference
        ))
        .routes(routes!(
            server_notification_preference,
            update_server_notification_preference
        ))
        .split_for_parts();

    let router = router
        .route("/api/v1/notifications/ws", get(websocket_notifications))
        .merge(
            SwaggerUi::new("/openapi")
                .url("/api-docs/openapi.json", api)
                .config(Config::default().try_it_out_enabled(true)),
        )
        .with_state(state)
        .layer(build_cors_layer(cors_allowed_origins));

    if http_request_logging.enabled {
        let log_level = http_request_logging.level.as_tracing_level();

        let trace_layer = TraceLayer::new_for_http()
            .make_span_with(move |request: &Request<_>| {
                make_sanitized_http_span(log_level, request)
            })
            .on_request(DefaultOnRequest::new().level(log_level))
            .on_response(
                DefaultOnResponse::new()
                    .level(log_level)
                    .include_headers(false),
            )
            .on_failure(DefaultOnFailure::new().level(log_level));

        router
            .layer(trace_layer)
            .layer(SetSensitiveRequestHeadersLayer::new(std::iter::once(
                AUTHORIZATION,
            )))
    } else {
        router
    }
}

fn make_sanitized_http_span(
    log_level: tracing::Level,
    request: &Request<impl Sized>,
) -> tracing::Span {
    let method = request.method();
    let uri = sanitize_request_uri(request.uri());
    let headers = request.headers();
    let version = request.version();

    match log_level {
        tracing::Level::ERROR => {
            tracing::span!(tracing::Level::ERROR, "request", %method, %uri, headers = ?headers, ?version)
        }
        tracing::Level::WARN => {
            tracing::span!(tracing::Level::WARN, "request", %method, %uri, headers = ?headers, ?version)
        }
        tracing::Level::INFO => {
            tracing::span!(tracing::Level::INFO, "request", %method, %uri, headers = ?headers, ?version)
        }
        tracing::Level::DEBUG => {
            tracing::span!(tracing::Level::DEBUG, "request", %method, %uri, headers = ?headers, ?version)
        }
        tracing::Level::TRACE => {
            tracing::span!(tracing::Level::TRACE, "request", %method, %uri, headers = ?headers, ?version)
        }
    }
}

fn sanitize_request_uri(uri: &http::Uri) -> String {
    let path = uri.path();
    let Some(query) = uri.query() else {
        return path.to_owned();
    };

    let redacted_query_parameter_names: HashSet<&str> = ["access_token"].into_iter().collect();

    let mut serializer = form_urlencoded::Serializer::new(String::new());
    for (key, value) in form_urlencoded::parse(query.as_bytes()) {
        let serialized_value = if redacted_query_parameter_names.contains(key.as_ref()) {
            "__REDACTED__"
        } else {
            value.as_ref()
        };

        serializer.append_pair(&key, serialized_value);
    }

    let sanitized_query = serializer.finish();
    if sanitized_query.is_empty() {
        return path.to_owned();
    }

    format!("{path}?{sanitized_query}")
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

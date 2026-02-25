pub mod auth;
pub mod config;
pub mod domain;
pub mod observability;
pub mod storage;

use std::{net::SocketAddr, sync::Arc};

use auth::{AuthState, AuthenticatedUser, JwksTokenVerifier, TokenVerifier};
use axum::{Json, Router, extract::State, http::StatusCode, response::IntoResponse, routing::get};
use axum::{
    extract::Path,
    routing::{patch, post},
};
use domain::{
    Channel, CreateChannelRequest, CreateMessageRequest, CreateServerRequest, Message, Server,
    UpdateMessageRequest,
};
use serde::Serialize;
use storage::{ChatRepository, InMemoryChatRepository, MutationResult};
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
    pub store: Arc<dyn ChatRepository>,
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
    paths(
        health,
        me,
        create_server,
        list_servers,
        create_channel,
        list_channels,
        create_message,
        update_message,
        delete_message,
        list_messages
    ),
    components(schemas(
        HealthResponse,
        MeResponse,
        Server,
        Channel,
        Message,
        CreateServerRequest,
        CreateChannelRequest,
        CreateMessageRequest,
        UpdateMessageRequest
    )),
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

#[utoipa::path(
    post,
    path = "/api/v1/servers",
    request_body = CreateServerRequest,
    responses(
        (status = 201, description = "Server created", body = Server),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
async fn create_server(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<CreateServerRequest>,
) -> impl IntoResponse {
    let created_server = state
        .store
        .create_server(request.name, authenticated_user.subject)
        .await;

    (StatusCode::CREATED, Json(created_server))
}

#[utoipa::path(
    get,
    path = "/api/v1/servers",
    responses(
        (status = 200, description = "Servers listed for authenticated user", body = [Server]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
async fn list_servers(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse {
    let servers = state
        .store
        .list_servers_for_user(&authenticated_user.subject)
        .await;

    (StatusCode::OK, Json(servers))
}

#[utoipa::path(
    post,
    path = "/api/v1/servers/{server_id}/channels",
    request_body = CreateChannelRequest,
    responses(
        (status = 201, description = "Channel created", body = Channel),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = String, Path, description = "Server id")),
    tag = "backend-api"
)]
async fn create_channel(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<String>,
    Json(request): Json<CreateChannelRequest>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let created_channel = state.store.create_channel(&server_id, request.name).await;

    match created_channel {
        Some(channel) => (StatusCode::CREATED, Json(channel)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/servers/{server_id}/channels",
    responses(
        (status = 200, description = "Channels listed for server", body = [Channel]),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = String, Path, description = "Server id")),
    tag = "backend-api"
)]
async fn list_channels(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<String>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let channels = state.store.list_channels_for_server(&server_id).await;

    match channels {
        Some(server_channels) => (StatusCode::OK, Json(server_channels)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/messages",
    request_body = CreateMessageRequest,
    responses(
        (status = 201, description = "Message created", body = Message),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
async fn create_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
    Json(request): Json<CreateMessageRequest>,
) -> impl IntoResponse {
    let created_message = state
        .store
        .create_message(&channel_id, authenticated_user.subject, request.content)
        .await;

    match created_message {
        Some(message) => (StatusCode::CREATED, Json(message)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    patch,
    path = "/api/v1/channels/{channel_id}/messages/{message_id}",
    request_body = UpdateMessageRequest,
    responses(
        (status = 200, description = "Message updated", body = Message),
        (status = 403, description = "Message not owned by authenticated user"),
        (status = 404, description = "Message not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("channel_id" = String, Path, description = "Channel id"),
        ("message_id" = String, Path, description = "Message id")
    ),
    tag = "backend-api"
)]
async fn update_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(String, String)>,
    Json(request): Json<UpdateMessageRequest>,
) -> impl IntoResponse {
    let mutation_result = state
        .store
        .update_message(
            &channel_id,
            &message_id,
            &authenticated_user.subject,
            request.content,
        )
        .await;

    match mutation_result {
        MutationResult::Updated => {
            let updated_message = state
                .store
                .list_messages(&channel_id)
                .await
                .into_iter()
                .find(|message| message.id == message_id);

            match updated_message {
                Some(message) => (StatusCode::OK, Json(message)).into_response(),
                None => StatusCode::NOT_FOUND.into_response(),
            }
        }
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Deleted => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

#[utoipa::path(
    delete,
    path = "/api/v1/channels/{channel_id}/messages/{message_id}",
    responses(
        (status = 204, description = "Message deleted"),
        (status = 403, description = "Message not owned by authenticated user"),
        (status = 404, description = "Message not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("channel_id" = String, Path, description = "Channel id"),
        ("message_id" = String, Path, description = "Message id")
    ),
    tag = "backend-api"
)]
async fn delete_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(String, String)>,
) -> impl IntoResponse {
    let mutation_result = state
        .store
        .delete_message(&channel_id, &message_id, &authenticated_user.subject)
        .await;

    match mutation_result {
        MutationResult::Deleted => StatusCode::NO_CONTENT.into_response(),
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Updated => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/messages",
    responses(
        (status = 200, description = "Messages listed", body = [Message]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
async fn list_messages(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let messages = state.store.list_messages(&channel_id).await;

    (StatusCode::OK, Json(messages))
}

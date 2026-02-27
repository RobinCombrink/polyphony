use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{Channel, Membership, Server};
use backend_storage::MutationResult;

use crate::{
    ApiState,
    auth::AuthenticatedUser,
    dto::{AddServerMemberRequest, CreateChannelRequest, CreateServerRequest},
};

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
pub(crate) async fn create_server(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<CreateServerRequest>,
) -> impl IntoResponse {
    let created_server = state
        .chat_repository
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
pub(crate) async fn list_servers(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse {
    let servers = state
        .chat_repository
        .list_servers_for_user(&authenticated_user.subject)
        .await;

    (StatusCode::OK, Json(servers))
}

#[utoipa::path(
    post,
    path = "/api/v1/servers/{server_id}/members",
    request_body = AddServerMemberRequest,
    responses(
        (status = 201, description = "Server member added", body = Membership),
        (status = 403, description = "Only server owner can add members"),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = String, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn add_server_member(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<String>,
    Json(request): Json<AddServerMemberRequest>,
) -> impl IntoResponse {
    let mutation_result = state
        .chat_repository
        .add_server_member(
            &server_id,
            &authenticated_user.subject,
            request.user_subject.clone(),
        )
        .await;

    match mutation_result {
        MutationResult::Updated => (
            StatusCode::CREATED,
            Json(Membership {
                user_subject: request.user_subject,
                server_id,
            }),
        )
            .into_response(),
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Deleted => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
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
pub(crate) async fn create_channel(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<String>,
    Json(request): Json<CreateChannelRequest>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let created_channel = state
        .chat_repository
        .create_channel(&server_id, request.name)
        .await;

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
pub(crate) async fn list_channels(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<String>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let channels = state.chat_repository.list_channels_for_server(&server_id).await;

    match channels {
        Some(server_channels) => (StatusCode::OK, Json(server_channels)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

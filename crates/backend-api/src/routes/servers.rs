use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{Channel, Membership, Server};
use backend_storage::{ChannelRepository, MutationResult, ServerRepository};
use uuid::Uuid;

use crate::{
    ApiState, RepositoryProfile,
    auth::AuthenticatedUser,
    dto::{
        AddServerMemberRequest, CreateChannelRequest, CreateServerRequest, UpdateChannelRequest,
    },
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
pub(crate) async fn create_server<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<CreateServerRequest>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let created_server = state
        .server_repository
        .create_server(request.name, authenticated_user.user_id)
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
pub(crate) async fn list_servers<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let servers = state
        .server_repository
        .list_servers_for_user(authenticated_user.user_id)
        .await;

    (StatusCode::OK, Json(servers))
}

#[utoipa::path(
    get,
    path = "/api/v1/servers/{server_id}/members",
    responses(
        (status = 200, description = "Server members listed", body = [Membership]),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = Uuid, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn list_server_members<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<Uuid>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let _ = authenticated_user;

    let members = state.server_repository.list_server_members(server_id).await;

    match members {
        Some(server_members) => (StatusCode::OK, Json(server_members)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
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
    params(("server_id" = Uuid, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn add_server_member<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<Uuid>,
    Json(request): Json<AddServerMemberRequest>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let mutation_result = state
        .server_repository
        .add_server_member(server_id, authenticated_user.user_id, request.user_id)
        .await;

    match mutation_result {
        MutationResult::Updated => (
            StatusCode::CREATED,
            Json(Membership {
                user_id: request.user_id,
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
    delete,
    path = "/api/v1/servers/{server_id}",
    responses(
        (status = 204, description = "Server deleted"),
        (status = 403, description = "Only server owner can delete server"),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = Uuid, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn delete_server<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<Uuid>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let mutation_result = state
        .server_repository
        .delete_server(server_id, authenticated_user.user_id)
        .await;

    match mutation_result {
        MutationResult::Deleted => StatusCode::NO_CONTENT.into_response(),
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Updated => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
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
    params(("server_id" = Uuid, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn create_channel<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<Uuid>,
    Json(request): Json<CreateChannelRequest>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let _ = authenticated_user;

    let created_channel = state
        .channel_repository
        .create_channel(server_id, request.name, request.channel_type)
        .await;

    match created_channel {
        Some(channel) => (StatusCode::CREATED, Json(channel)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    patch,
    path = "/api/v1/channels/{channel_id}",
    request_body = UpdateChannelRequest,
    responses(
        (status = 204, description = "Channel updated"),
        (status = 403, description = "Only server owner can update channel"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn update_channel<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
    Json(request): Json<UpdateChannelRequest>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let mutation_result = state
        .channel_repository
        .update_channel_name(channel_id, authenticated_user.user_id, request.name)
        .await;

    match mutation_result {
        MutationResult::Updated => StatusCode::NO_CONTENT.into_response(),
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Deleted => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

#[utoipa::path(
    delete,
    path = "/api/v1/channels/{channel_id}",
    responses(
        (status = 204, description = "Channel deleted"),
        (status = 403, description = "Only server owner can delete channel"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn delete_channel<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let mutation_result = state
        .channel_repository
        .delete_channel(channel_id, authenticated_user.user_id)
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
    path = "/api/v1/servers/{server_id}/channels",
    responses(
        (status = 200, description = "Channels listed for server", body = [Channel]),
        (status = 403, description = "User is not a member of the server"),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = Uuid, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn list_channels<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<Uuid>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let is_server_member = match state
        .server_repository
        .is_server_member(server_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    if !is_server_member {
        return StatusCode::FORBIDDEN.into_response();
    }

    let channels = state
        .channel_repository
        .list_channels_for_server(server_id)
        .await;

    match channels {
        Some(mut server_channels) => {
            server_channels.sort_by_key(Channel::id);

            (StatusCode::OK, Json(server_channels)).into_response()
        }
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

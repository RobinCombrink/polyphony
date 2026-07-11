use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{Channel, ChannelId, Membership, Server, ServerId};
use backend_storage::{
    ChannelRepository, FriendRepository, MessageRepository, MutationResult, ServerRepository,
    UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{
        AddServerMemberRequest, CreateChannelRequest, CreateServerRequest, UpdateChannelRequest,
        UpdateServerRequest,
    },
    response_mapping::{DeletedResponse, UpdatedResponse},
    use_cases::require_server_membership,
};

type AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier> =
    ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>;

#[utoipa::path(
    post,
    path = "/api/v1/servers",
    request_body = CreateServerRequest,
    responses(
        (status = 201, description = "Server created", body = Server),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Servers"
)]
pub(crate) async fn create_server<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<CreateServerRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(created_server) = state
        .server_repository
        .create_server(request.name, authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    (StatusCode::CREATED, Json(created_server)).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/servers",
    responses(
        (status = 200, description = "Servers listed for authenticated user", body = [Server]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Servers"
)]
pub(crate) async fn list_servers<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(servers) = state
        .server_repository
        .list_servers_for_user(authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    (StatusCode::OK, Json(servers)).into_response()
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
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "Servers"
)]
pub(crate) async fn list_server_members<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let _ = authenticated_user;

    let Ok(members) = state.server_repository.list_server_members(server_id).await else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

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
        (status = 404, description = "Server or user not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "Servers"
)]
pub(crate) async fn add_server_member<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
    Json(request): Json<AddServerMemberRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(mutation_result) = state
        .server_repository
        .add_server_member(server_id, authenticated_user.user_id, request.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

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
    post,
    path = "/api/v1/servers/{server_id}/invite/friends/{friend_user_id}",
    responses(
        (status = 201, description = "Friend invited to server", body = Membership),
        (status = 403, description = "Only server owner can invite members or users are not friends"),
        (status = 404, description = "Server or user not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("server_id" = ServerId, Path, description = "Server id"),
        ("friend_user_id" = backend_domain::UserId, Path, description = "Friend user id")
    ),
    tag = "Servers"
)]
pub(crate) async fn invite_friend_to_server<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((server_id, friend_user_id)): Path<(ServerId, backend_domain::UserId)>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + FriendRepository,
    Verifier: TokenVerifier,
{
    use crate::use_cases::servers::invite_friend_to_server as invite_use_case;

    match invite_use_case(
        &*state.server_repository,
        &*state.message_repository,
        server_id,
        authenticated_user.user_id,
        friend_user_id,
    )
    .await
    {
        Ok(membership) => (StatusCode::CREATED, Json(membership)).into_response(),
        Err(error) => error.into_response(),
    }
}

#[utoipa::path(
    patch,
    path = "/api/v1/servers/{server_id}",
    request_body = UpdateServerRequest,
    responses(
        (status = 204, description = "Server updated"),
        (status = 403, description = "Only server owner can update server"),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "Servers"
)]
pub(crate) async fn update_server<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
    Json(request): Json<UpdateServerRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(mutation_result) = state
        .server_repository
        .update_server_name(server_id, authenticated_user.user_id, request.name)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    UpdatedResponse(mutation_result).into_response()
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
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "Servers"
)]
pub(crate) async fn delete_server<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(mutation_result) = state
        .server_repository
        .delete_server(server_id, authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    DeletedResponse(mutation_result).into_response()
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
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "Channels"
)]
pub(crate) async fn create_channel<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
    Json(request): Json<CreateChannelRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let _ = authenticated_user;

    let Ok(created_channel) = state
        .channel_repository
        .create_channel(server_id, request.name, request.channel_type)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

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
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "Channels"
)]
pub(crate) async fn update_channel<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
    Json(request): Json<UpdateChannelRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(mutation_result) = state
        .channel_repository
        .update_channel_name(channel_id, authenticated_user.user_id, request.name)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    UpdatedResponse(mutation_result).into_response()
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
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "Channels"
)]
pub(crate) async fn delete_channel<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(mutation_result) = state
        .channel_repository
        .delete_channel(channel_id, authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    DeletedResponse(mutation_result).into_response()
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
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "Channels"
)]
pub(crate) async fn list_channels<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<AppState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    if let Err(gate_error) = require_server_membership(
        &*state.server_repository,
        server_id,
        authenticated_user.user_id,
    )
    .await
    {
        return gate_error.into_response();
    }

    let Ok(channels) = state
        .channel_repository
        .list_channels_for_server(server_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    match channels {
        Some(mut server_channels) => {
            server_channels.sort_by_key(Channel::id);

            (StatusCode::OK, Json(server_channels)).into_response()
        }
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

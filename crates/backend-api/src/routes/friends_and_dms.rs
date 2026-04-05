use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{DirectMessageThreadId, FriendRequestId, FriendRequestState, UserId};
use backend_storage::{
    BlockRepository, DirectMessageRepository, FriendRepository, SendFriendRequestResult,
    UpdateFriendRequestResult,
};
use serde::Deserialize;
use serde::Serialize;
use utoipa::ToSchema;

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::ApiErrorResponse,
    notification_hub::{NotificationEnvelope, NotificationEvent},
    response_mapping::{
        BlockUserResponse, OpenOrGetDmThreadResponse, SendDirectMessageResponse,
        UpdateFriendRequestResponse,
    },
};

#[derive(Debug, Serialize, ToSchema)]
pub struct FriendSummaryResponse {
    pub user_id: UserId,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct FriendRequestResponse {
    pub id: FriendRequestId,
    pub requester_user_id: UserId,
    pub addressee_user_id: UserId,
    pub state: FriendRequestState,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct BlockRelationshipResponse {
    pub blocked_user_id: UserId,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct DirectMessageThreadResponse {
    pub id: DirectMessageThreadId,
    pub participant_a_user_id: UserId,
    pub participant_b_user_id: UserId,
}

#[derive(Debug, Serialize, ToSchema)]
pub struct DirectMessageResponse {
    pub id: backend_domain::DirectMessageId,
    pub thread_id: DirectMessageThreadId,
    pub author_user_id: UserId,
    pub content: String,
}

impl From<backend_domain::FriendRequest> for FriendRequestResponse {
    fn from(value: backend_domain::FriendRequest) -> Self {
        Self {
            id: value.id,
            requester_user_id: value.requester_user_id,
            addressee_user_id: value.addressee_user_id,
            state: value.state,
        }
    }
}

impl From<backend_domain::DirectMessageThread> for DirectMessageThreadResponse {
    fn from(value: backend_domain::DirectMessageThread) -> Self {
        Self {
            id: value.id,
            participant_a_user_id: value.participant_a_user_id,
            participant_b_user_id: value.participant_b_user_id,
        }
    }
}

impl From<backend_domain::DirectMessage> for DirectMessageResponse {
    fn from(value: backend_domain::DirectMessage) -> Self {
        Self {
            id: value.id,
            thread_id: value.thread_id,
            author_user_id: value.author_user_id,
            content: value.content,
        }
    }
}

#[derive(Debug, Deserialize, ToSchema)]
pub struct SendDirectMessageRequest {
    pub content: String,
}

#[derive(Debug, Deserialize)]
pub struct SearchDirectMessagesQuery {
    pub q: Option<String>,
}

#[utoipa::path(
    get,
    path = "/api/v1/friends",
    responses(
        (status = 200, description = "Friends listed", body = [FriendSummaryResponse]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Friends"
)]
pub(crate) async fn list_friends<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(friendships) = state
        .message_repository
        .list_friendships_for_user(authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let friends = friendships
        .into_iter()
        .map(|friendship| {
            let user_id = if friendship.user_a_id == authenticated_user.user_id {
                friendship.user_b_id
            } else {
                friendship.user_a_id
            };
            FriendSummaryResponse { user_id }
        })
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(friends)).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/friends/requests/incoming",
    responses(
        (status = 200, description = "Incoming friend requests listed", body = [FriendRequestResponse]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Friends"
)]
pub(crate) async fn list_incoming_friend_requests<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(pending) = state
        .message_repository
        .list_pending_incoming_friend_requests(authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let requests = pending
        .into_iter()
        .map(FriendRequestResponse::from)
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(requests)).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/friends/requests/outgoing",
    responses(
        (status = 200, description = "Outgoing friend requests listed", body = [FriendRequestResponse]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Friends"
)]
pub(crate) async fn list_outgoing_friend_requests<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(pending) = state
        .message_repository
        .list_pending_outgoing_friend_requests(authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let requests = pending
        .into_iter()
        .map(FriendRequestResponse::from)
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(requests)).into_response()
}

#[utoipa::path(
    post,
    path = "/api/v1/friends/requests/{user_id}",
    responses(
        (status = 201, description = "Friend request sent", body = FriendRequestResponse),
        (status = 403, description = "Operation forbidden or users blocked", body = ApiErrorResponse),
        (status = 404, description = "Target user not found", body = ApiErrorResponse),
        (status = 409, description = "Already friends or request already pending", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("user_id" = UserId, Path, description = "Target user id")),
    tag = "Friends"
)]
pub(crate) async fn send_friend_request<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(user_id): Path<UserId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .send_friend_request(authenticated_user.user_id, user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    match result {
        SendFriendRequestResult::Created(friend_request) => {
            state.notification_hub.publish(NotificationEnvelope {
                recipient_user_id: friend_request.addressee_user_id,
                event: NotificationEvent::friend_request_received(
                    friend_request.id,
                    friend_request.requester_user_id,
                    friend_request.addressee_user_id,
                ),
            });

            (
                StatusCode::CREATED,
                Json(FriendRequestResponse::from(friend_request)),
            )
                .into_response()
        }
        SendFriendRequestResult::AlreadyFriends => (
            StatusCode::CONFLICT,
            Json(ApiErrorResponse::new(
                "ALREADY_FRIENDS",
                "users are already friends",
            )),
        )
            .into_response(),
        SendFriendRequestResult::AlreadyPending => (
            StatusCode::CONFLICT,
            Json(ApiErrorResponse::new(
                "ALREADY_PENDING",
                "friend request is already pending",
            )),
        )
            .into_response(),
        SendFriendRequestResult::Blocked => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new(
                "USERS_BLOCKED",
                "friend request is denied due to blocked relationship",
            )),
        )
            .into_response(),
        SendFriendRequestResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        SendFriendRequestResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "target user was not found",
            )),
        )
            .into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/servers/{server_id}/friends/requests/{user_id}",
    responses(
        (status = 201, description = "Friend request sent from server context", body = FriendRequestResponse),
        (status = 403, description = "Operation forbidden or users blocked", body = ApiErrorResponse),
        (status = 404, description = "Server or user not found", body = ApiErrorResponse),
        (status = 409, description = "Already friends or request already pending", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("server_id" = backend_domain::ServerId, Path, description = "Server id"),
        ("user_id" = UserId, Path, description = "Target user id")
    ),
    tag = "Friends"
)]
pub(crate) async fn send_friend_request_from_server_context<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((server_id, user_id)): Path<(backend_domain::ServerId, UserId)>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let requester_is_member = match state
        .server_repository
        .is_server_member(server_id, authenticated_user.user_id)
        .await
    {
        Ok(Some(value)) => value,
        Ok(None) | Err(_) => {
            return (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new("NOT_FOUND", "server was not found")),
            )
                .into_response();
        }
    };

    let addressee_is_member = match state
        .server_repository
        .is_server_member(server_id, user_id)
        .await
    {
        Ok(Some(value)) => value,
        Ok(None) | Err(_) => {
            return (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new("NOT_FOUND", "server was not found")),
            )
                .into_response();
        }
    };

    if !requester_is_member || !addressee_is_member {
        return (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new(
                "FORBIDDEN",
                "friend request is denied because users do not share this server",
            )),
        )
            .into_response();
    }

    let Ok(result) = state
        .message_repository
        .send_friend_request(authenticated_user.user_id, user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    match result {
        SendFriendRequestResult::Created(friend_request) => {
            state.notification_hub.publish(NotificationEnvelope {
                recipient_user_id: friend_request.addressee_user_id,
                event: NotificationEvent::friend_request_received(
                    friend_request.id,
                    friend_request.requester_user_id,
                    friend_request.addressee_user_id,
                ),
            });

            (
                StatusCode::CREATED,
                Json(FriendRequestResponse::from(friend_request)),
            )
                .into_response()
        }
        SendFriendRequestResult::AlreadyFriends => (
            StatusCode::CONFLICT,
            Json(ApiErrorResponse::new(
                "ALREADY_FRIENDS",
                "users are already friends",
            )),
        )
            .into_response(),
        SendFriendRequestResult::AlreadyPending => (
            StatusCode::CONFLICT,
            Json(ApiErrorResponse::new(
                "ALREADY_PENDING",
                "friend request is already pending",
            )),
        )
            .into_response(),
        SendFriendRequestResult::Blocked => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new(
                "USERS_BLOCKED",
                "friend request is denied due to blocked relationship",
            )),
        )
            .into_response(),
        SendFriendRequestResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        SendFriendRequestResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "target user was not found",
            )),
        )
            .into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/friends/requests/{friend_request_id}/accept",
    responses(
        (status = 200, description = "Friend request accepted", body = FriendRequestResponse),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 404, description = "Friend request not found", body = ApiErrorResponse),
        (status = 409, description = "Invalid state transition", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("friend_request_id" = FriendRequestId, Path, description = "Friend request id")),
    tag = "Friends"
)]
pub(crate) async fn accept_friend_request<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(friend_request_id): Path<FriendRequestId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .accept_friend_request(authenticated_user.user_id, friend_request_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    match result {
        UpdateFriendRequestResult::Updated(friend_request) => {
            state.notification_hub.publish(NotificationEnvelope {
                recipient_user_id: friend_request.requester_user_id,
                event: NotificationEvent::friend_request_accepted(
                    friend_request.id,
                    friend_request.requester_user_id,
                    friend_request.addressee_user_id,
                ),
            });

            (
                StatusCode::OK,
                Json(FriendRequestResponse::from(friend_request)),
            )
                .into_response()
        }
        UpdateFriendRequestResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        UpdateFriendRequestResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "friend request was not found",
            )),
        )
            .into_response(),
        UpdateFriendRequestResult::InvalidState => (
            StatusCode::CONFLICT,
            Json(ApiErrorResponse::new(
                "INVALID_STATE",
                "friend request transition is invalid",
            )),
        )
            .into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/friends/requests/{friend_request_id}/decline",
    responses(
        (status = 200, description = "Friend request declined", body = FriendRequestResponse),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 404, description = "Friend request not found", body = ApiErrorResponse),
        (status = 409, description = "Invalid state transition", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("friend_request_id" = FriendRequestId, Path, description = "Friend request id")),
    tag = "Friends"
)]
pub(crate) async fn decline_friend_request<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(friend_request_id): Path<FriendRequestId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .decline_friend_request(authenticated_user.user_id, friend_request_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    UpdateFriendRequestResponse(result).into_response()
}

#[utoipa::path(
    post,
    path = "/api/v1/friends/requests/{friend_request_id}/cancel",
    responses(
        (status = 200, description = "Friend request cancelled", body = FriendRequestResponse),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 404, description = "Friend request not found", body = ApiErrorResponse),
        (status = 409, description = "Invalid state transition", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("friend_request_id" = FriendRequestId, Path, description = "Friend request id")),
    tag = "Friends"
)]
pub(crate) async fn cancel_friend_request<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(friend_request_id): Path<FriendRequestId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .cancel_friend_request(authenticated_user.user_id, friend_request_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    UpdateFriendRequestResponse(result).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/blocks",
    responses(
        (status = 200, description = "Blocked users listed", body = [BlockRelationshipResponse]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Blocks"
)]
pub(crate) async fn list_blocked_users<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(blocked) = state
        .message_repository
        .list_blocked_users(authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let blocked_users = blocked
        .into_iter()
        .map(|relationship| BlockRelationshipResponse {
            blocked_user_id: relationship.blocked_user_id,
        })
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(blocked_users)).into_response()
}

#[utoipa::path(
    post,
    path = "/api/v1/blocks/{user_id}",
    responses(
        (status = 201, description = "User blocked"),
        (status = 200, description = "User already blocked"),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 404, description = "Target user not found", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("user_id" = UserId, Path, description = "User id to block")),
    tag = "Blocks"
)]
pub(crate) async fn block_user<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(user_id): Path<UserId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .block_user(authenticated_user.user_id, user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    BlockUserResponse(result).into_response()
}

#[utoipa::path(
    delete,
    path = "/api/v1/blocks/{user_id}",
    responses(
        (status = 204, description = "User unblocked"),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 404, description = "Block relationship not found", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("user_id" = UserId, Path, description = "User id to unblock")),
    tag = "Blocks"
)]
pub(crate) async fn unblock_user<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(user_id): Path<UserId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .unblock_user(authenticated_user.user_id, user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    match result {
        backend_storage::MutationResult::Deleted | backend_storage::MutationResult::Updated => {
            StatusCode::NO_CONTENT.into_response()
        }
        backend_storage::MutationResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        backend_storage::MutationResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "block relationship was not found",
            )),
        )
            .into_response(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/dms/threads",
    responses(
        (status = 200, description = "Direct message threads listed", body = [DirectMessageThreadResponse]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Direct Messages"
)]
pub(crate) async fn list_direct_message_threads<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(raw_threads) = state
        .message_repository
        .list_direct_message_threads_for_user(authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let threads = raw_threads
        .into_iter()
        .map(DirectMessageThreadResponse::from)
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(threads)).into_response()
}

#[utoipa::path(
    post,
    path = "/api/v1/dms/threads/{user_id}",
    responses(
        (status = 200, description = "Direct message thread opened or retrieved", body = DirectMessageThreadResponse),
        (status = 403, description = "Operation forbidden or users blocked", body = ApiErrorResponse),
        (status = 404, description = "Target user not found", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("user_id" = UserId, Path, description = "Other participant user id")),
    tag = "Direct Messages"
)]
pub(crate) async fn open_or_get_direct_message_thread<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(user_id): Path<UserId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .open_or_get_direct_message_thread(authenticated_user.user_id, user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    OpenOrGetDmThreadResponse(result).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/dms/threads/{thread_id}/messages",
    responses(
        (status = 200, description = "Direct messages listed", body = [DirectMessageResponse]),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("thread_id" = DirectMessageThreadId, Path, description = "DM thread id")),
    tag = "Direct Messages"
)]
pub(crate) async fn list_direct_messages<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(thread_id): Path<DirectMessageThreadId>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(messages) = state
        .message_repository
        .list_direct_messages(authenticated_user.user_id, thread_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let Some(messages) = messages else {
        return (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response();
    };

    (
        StatusCode::OK,
        Json(
            messages
                .into_iter()
                .map(DirectMessageResponse::from)
                .collect::<Vec<_>>(),
        ),
    )
        .into_response()
}

#[utoipa::path(
    post,
    path = "/api/v1/dms/threads/{thread_id}/messages",
    request_body = SendDirectMessageRequest,
    responses(
        (status = 201, description = "Direct message sent", body = DirectMessageResponse),
        (status = 403, description = "Operation forbidden or users blocked", body = ApiErrorResponse),
        (status = 404, description = "DM thread not found", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("thread_id" = DirectMessageThreadId, Path, description = "DM thread id")),
    tag = "Direct Messages"
)]
pub(crate) async fn send_direct_message<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(thread_id): Path<DirectMessageThreadId>,
    Json(payload): Json<SendDirectMessageRequest>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let Ok(result) = state
        .message_repository
        .send_direct_message(authenticated_user.user_id, thread_id, payload.content)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    SendDirectMessageResponse(result).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/dms/search/{user_id}",
    responses(
        (status = 200, description = "Search results returned", body = [DirectMessageResponse]),
        (status = 403, description = "Operation forbidden", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("user_id" = UserId, Path, description = "User id to search DM history with"),
        ("q" = Option<String>, Query, description = "Search query text")
    ),
    tag = "Direct Messages"
)]
pub(crate) async fn search_direct_messages<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(user_id): Path<UserId>,
    Query(query): Query<SearchDirectMessagesQuery>,
) -> impl IntoResponse
where
    UserRepo: backend_storage::UserRepository + Send + Sync + 'static,
    ServerRepo: backend_storage::ServerRepository + Send + Sync + 'static,
    ChannelRepo: backend_storage::ChannelRepository + Send + Sync + 'static,
    MessageRepo: backend_storage::MessageRepository
        + backend_storage::NotificationRepository
        + FriendRepository
        + BlockRepository
        + DirectMessageRepository
        + Send
        + Sync
        + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let query_text = query.q.unwrap_or_default();
    let Ok(messages) = state
        .message_repository
        .search_direct_messages_for_person(authenticated_user.user_id, user_id, &query_text)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let Some(messages) = messages else {
        return (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response();
    };

    (
        StatusCode::OK,
        Json(
            messages
                .into_iter()
                .map(DirectMessageResponse::from)
                .collect::<Vec<_>>(),
        ),
    )
        .into_response()
}

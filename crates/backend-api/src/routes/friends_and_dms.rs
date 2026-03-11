use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{DirectMessageThreadId, FriendRequestId, FriendRequestState, UserId};
use backend_storage::{
    BlockRepository, BlockUserResult, DirectMessageRepository, FriendRepository,
    OpenOrGetDirectMessageThreadResult, SendDirectMessageResult, SendFriendRequestResult,
    UpdateFriendRequestResult,
};
use serde::Deserialize;
use serde::Serialize;

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::ApiErrorResponse,
    notification_hub::{NotificationEnvelope, NotificationEvent},
};

#[derive(Debug, Serialize)]
pub struct FriendSummaryResponse {
    pub user_id: UserId,
}

#[derive(Debug, Serialize)]
pub struct FriendRequestResponse {
    pub id: FriendRequestId,
    pub requester_user_id: UserId,
    pub addressee_user_id: UserId,
    pub state: FriendRequestState,
}

#[derive(Debug, Serialize)]
pub struct BlockRelationshipResponse {
    pub blocked_user_id: UserId,
}

#[derive(Debug, Serialize)]
pub struct DirectMessageThreadResponse {
    pub id: DirectMessageThreadId,
    pub participant_a_user_id: UserId,
    pub participant_b_user_id: UserId,
}

#[derive(Debug, Serialize)]
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

#[derive(Debug, Deserialize)]
pub struct SendDirectMessageRequest {
    pub content: String,
}

#[derive(Debug, Deserialize)]
pub struct SearchDirectMessagesQuery {
    pub q: Option<String>,
}

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
    let friendships = state
        .message_repository
        .list_friendships_for_user(authenticated_user.user_id)
        .await;

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
    let requests = state
        .message_repository
        .list_pending_incoming_friend_requests(authenticated_user.user_id)
        .await
        .into_iter()
        .map(FriendRequestResponse::from)
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(requests)).into_response()
}

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
    let requests = state
        .message_repository
        .list_pending_outgoing_friend_requests(authenticated_user.user_id)
        .await
        .into_iter()
        .map(FriendRequestResponse::from)
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(requests)).into_response()
}

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
    match state
        .message_repository
        .send_friend_request(authenticated_user.user_id, user_id)
        .await
    {
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
        Some(value) => value,
        None => {
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
        Some(value) => value,
        None => {
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

    match state
        .message_repository
        .send_friend_request(authenticated_user.user_id, user_id)
        .await
    {
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
    match state
        .message_repository
        .set_friend_request_state(
            authenticated_user.user_id,
            friend_request_id,
            backend_domain::FriendRequestState::Accepted,
        )
        .await
    {
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
    match state
        .message_repository
        .set_friend_request_state(
            authenticated_user.user_id,
            friend_request_id,
            backend_domain::FriendRequestState::Declined,
        )
        .await
    {
        UpdateFriendRequestResult::Updated(friend_request) => (
            StatusCode::OK,
            Json(FriendRequestResponse::from(friend_request)),
        )
            .into_response(),
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
    match state
        .message_repository
        .set_friend_request_state(
            authenticated_user.user_id,
            friend_request_id,
            backend_domain::FriendRequestState::Cancelled,
        )
        .await
    {
        UpdateFriendRequestResult::Updated(friend_request) => (
            StatusCode::OK,
            Json(FriendRequestResponse::from(friend_request)),
        )
            .into_response(),
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
    let blocked_users = state
        .message_repository
        .list_blocked_users(authenticated_user.user_id)
        .await
        .into_iter()
        .map(|relationship| BlockRelationshipResponse {
            blocked_user_id: relationship.blocked_user_id,
        })
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(blocked_users)).into_response()
}

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
    match state
        .message_repository
        .block_user(authenticated_user.user_id, user_id)
        .await
    {
        BlockUserResult::Created(_) => StatusCode::CREATED.into_response(),
        BlockUserResult::AlreadyBlocked => StatusCode::OK.into_response(),
        BlockUserResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        BlockUserResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "target user was not found",
            )),
        )
            .into_response(),
    }
}

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
    match state
        .message_repository
        .unblock_user(authenticated_user.user_id, user_id)
        .await
    {
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
    let threads = state
        .message_repository
        .list_direct_message_threads_for_user(authenticated_user.user_id)
        .await
        .into_iter()
        .map(DirectMessageThreadResponse::from)
        .collect::<Vec<_>>();

    (StatusCode::OK, Json(threads)).into_response()
}

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
    match state
        .message_repository
        .open_or_get_direct_message_thread(authenticated_user.user_id, user_id)
        .await
    {
        OpenOrGetDirectMessageThreadResult::Opened(direct_message_thread) => (
            StatusCode::OK,
            Json(DirectMessageThreadResponse::from(direct_message_thread)),
        )
            .into_response(),
        OpenOrGetDirectMessageThreadResult::Blocked => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new(
                "USERS_BLOCKED",
                "cannot open dm thread due to blocked relationship",
            )),
        )
            .into_response(),
        OpenOrGetDirectMessageThreadResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        OpenOrGetDirectMessageThreadResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "target user was not found",
            )),
        )
            .into_response(),
    }
}

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
    let messages = state
        .message_repository
        .list_direct_messages(authenticated_user.user_id, thread_id)
        .await;

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
    match state
        .message_repository
        .send_direct_message(authenticated_user.user_id, thread_id, payload.content)
        .await
    {
        SendDirectMessageResult::Created(direct_message) => (
            StatusCode::CREATED,
            Json(DirectMessageResponse::from(direct_message)),
        )
            .into_response(),
        SendDirectMessageResult::Blocked => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new(
                "USERS_BLOCKED",
                "cannot send dm due to blocked relationship",
            )),
        )
            .into_response(),
        SendDirectMessageResult::Forbidden => (
            StatusCode::FORBIDDEN,
            Json(ApiErrorResponse::new("FORBIDDEN", "operation is forbidden")),
        )
            .into_response(),
        SendDirectMessageResult::NotFound => (
            StatusCode::NOT_FOUND,
            Json(ApiErrorResponse::new(
                "NOT_FOUND",
                "dm thread was not found",
            )),
        )
            .into_response(),
    }
}

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
    let messages = state
        .message_repository
        .search_direct_messages_for_person(authenticated_user.user_id, user_id, &query_text)
        .await;

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

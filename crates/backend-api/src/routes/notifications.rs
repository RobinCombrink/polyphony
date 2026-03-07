use axum::{
    Json,
    extract::{
        Path, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, ServerId};
use backend_storage::{
    ChannelRepository, MessageRepository, NotificationRepository, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{
        ApiErrorResponse, MuteChannelNotificationsRequest, NotificationChannelPreferenceResponse,
        NotificationGlobalPreferenceResponse, NotificationServerPreferenceResponse,
        NotificationUnreadCountResponse, UpdateNotificationGlobalPreferenceRequest,
        UpdateNotificationServerPreferenceRequest,
    },
};

#[utoipa::path(
    get,
    path = "/api/v1/notifications/preferences/global",
    responses(
        (status = 200, description = "Global notification preference loaded", body = NotificationGlobalPreferenceResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn global_notification_preference<
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
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let muted = state
        .message_repository
        .is_globally_muted_for_user(authenticated_user.user_id)
        .await;

    (
        StatusCode::OK,
        Json(NotificationGlobalPreferenceResponse { muted }),
    )
}

#[utoipa::path(
    get,
    path = "/api/v1/servers/{server_id}/notifications/preferences",
    responses(
        (status = 200, description = "Server notification preference loaded", body = NotificationServerPreferenceResponse),
        (status = 403, description = "User is not a member of the server"),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn server_notification_preference<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
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

    let muted = state
        .message_repository
        .is_server_muted_for_user(authenticated_user.user_id, server_id)
        .await;

    (
        StatusCode::OK,
        Json(NotificationServerPreferenceResponse { muted }),
    )
        .into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/notifications/preferences",
    responses(
        (status = 200, description = "Channel notification preference loaded", body = NotificationChannelPreferenceResponse),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn channel_notification_preference<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let is_channel_member = match state
        .channel_repository
        .is_channel_member(channel_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    if !is_channel_member {
        return StatusCode::FORBIDDEN.into_response();
    }

    let muted_until_epoch_seconds = state
        .message_repository
        .channel_mute_expires_at_epoch_seconds(authenticated_user.user_id, channel_id)
        .await;

    (
        StatusCode::OK,
        Json(NotificationChannelPreferenceResponse {
            muted: muted_until_epoch_seconds.is_some(),
            muted_until_epoch_seconds,
        }),
    )
        .into_response()
}

#[utoipa::path(
    patch,
    path = "/api/v1/notifications/preferences/global",
    request_body = UpdateNotificationGlobalPreferenceRequest,
    responses(
        (status = 204, description = "Global notification preference updated"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn update_global_notification_preference<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<UpdateNotificationGlobalPreferenceRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    state
        .message_repository
        .set_globally_muted_for_user(authenticated_user.user_id, request.muted)
        .await;

    StatusCode::NO_CONTENT
}

#[utoipa::path(
    patch,
    path = "/api/v1/servers/{server_id}/notifications/preferences",
    request_body = UpdateNotificationServerPreferenceRequest,
    responses(
        (status = 204, description = "Server notification preference updated"),
        (status = 403, description = "User is not a member of the server"),
        (status = 404, description = "Server not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("server_id" = ServerId, Path, description = "Server id")),
    tag = "backend-api"
)]
pub(crate) async fn update_server_notification_preference<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
    Json(request): Json<UpdateNotificationServerPreferenceRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let is_server_member = match state
        .server_repository
        .is_server_member(server_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND,
    };

    if !is_server_member {
        return StatusCode::FORBIDDEN;
    }

    state
        .message_repository
        .set_server_muted_for_user(authenticated_user.user_id, server_id, request.muted)
        .await;

    StatusCode::NO_CONTENT
}

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/notifications/preferences/mute",
    request_body = MuteChannelNotificationsRequest,
    responses(
        (status = 204, description = "Channel mute preference updated"),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 422, description = "Invalid mute duration", body = ApiErrorResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn mute_channel_notifications<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
    Json(request): Json<MuteChannelNotificationsRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let is_channel_member = match state
        .channel_repository
        .is_channel_member(channel_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    if !is_channel_member {
        return StatusCode::FORBIDDEN.into_response();
    }

    if request.duration_minutes == 0 {
        return (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(ApiErrorResponse::new(
                "INVALID_MUTE_DURATION",
                "mute duration must be greater than zero minutes",
            )),
        )
            .into_response();
    }

    state
        .message_repository
        .set_channel_temporarily_muted_for_user(
            authenticated_user.user_id,
            channel_id,
            request.duration_minutes,
        )
        .await;

    StatusCode::NO_CONTENT.into_response()
}

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/notifications/preferences/unmute",
    responses(
        (status = 204, description = "Channel mute preference cleared"),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn unmute_channel_notifications<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let is_channel_member = match state
        .channel_repository
        .is_channel_member(channel_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND,
    };

    if !is_channel_member {
        return StatusCode::FORBIDDEN;
    }

    state
        .message_repository
        .expire_channel_mute_for_user(authenticated_user.user_id, channel_id)
        .await;

    StatusCode::NO_CONTENT
}

#[utoipa::path(
    get,
    path = "/api/v1/notifications/unread-count",
    responses(
        (status = 200, description = "Unread count loaded", body = NotificationUnreadCountResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn unread_notifications_count<
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
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let total_unread_count = state
        .message_repository
        .total_unread_count_for_user(authenticated_user.user_id)
        .await;

    (
        StatusCode::OK,
        Json(NotificationUnreadCountResponse { total_unread_count }),
    )
}

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/notifications/read",
    responses(
        (status = 204, description = "Unread count cleared for channel"),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn mark_channel_notifications_read<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let is_channel_member = match state
        .channel_repository
        .is_channel_member(channel_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND,
    };

    if !is_channel_member {
        return StatusCode::FORBIDDEN;
    }

    state
        .message_repository
        .clear_unread_count_for_channel(authenticated_user.user_id, channel_id)
        .await;

    StatusCode::NO_CONTENT
}

pub(crate) async fn websocket_notifications<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    ws: WebSocketUpgrade,
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    ws.on_upgrade(move |socket| async move {
        forward_notifications(socket, state, authenticated_user).await;
    })
}

async fn forward_notifications<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    mut socket: WebSocket,
    state: ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
    authenticated_user: AuthenticatedUser,
) where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + NotificationRepository,
    Verifier: TokenVerifier,
{
    let mut subscriber = state.notification_hub.subscribe();

    while let Ok(envelope) = subscriber.recv().await {
        if envelope.recipient_user_id != authenticated_user.user_id {
            continue;
        }

        let payload = match serde_json::to_string(&envelope.event) {
            Ok(value) => value,
            Err(_) => continue,
        };

        if socket.send(Message::Text(payload.into())).await.is_err() {
            break;
        }
    }
}

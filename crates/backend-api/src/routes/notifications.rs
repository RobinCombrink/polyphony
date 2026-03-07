use axum::{
    Json,
    extract::{
        Path, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::ChannelId;
use backend_storage::{
    ChannelRepository, MessageRepository, NotificationRepository, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::NotificationUnreadCountResponse,
};

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

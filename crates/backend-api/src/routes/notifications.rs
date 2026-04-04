use axum::{
    Json,
    extract::{
        Path, Query, State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    http::HeaderMap,
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, NotificationMuteState, ServerId};
use backend_storage::{
    ChannelRepository, MarkUnreadFromMessageResult, MessageRepository, NotificationRepository,
    ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthError, AuthenticatedUser, TokenVerifier},
    dto::{
        ApiErrorResponse, MarkUnreadRequest, MuteChannelNotificationsRequest,
        NotificationChannelPreferenceResponse,
        NotificationGlobalPreferenceResponse, NotificationServerPreferenceResponse,
        NotificationUnreadCountResponse, UpdateNotificationChannelPreferenceRequest,
        UpdateNotificationGlobalPreferenceRequest, UpdateNotificationServerPreferenceRequest,
    },
};
use serde::Deserialize;

#[utoipa::path(
    get,
    path = "/api/v1/notifications/preferences/global",
    responses(
        (status = 200, description = "Global notification preference loaded", body = NotificationGlobalPreferenceResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Notifications"
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
    let mute_state = state
        .message_repository
        .global_mute_state_for_user(authenticated_user.user_id)
        .await;
    let notification_category = state
        .message_repository
        .global_notification_category_for_user(authenticated_user.user_id)
        .await;
    let channel_default_category = state
        .message_repository
        .global_channel_default_notification_category_for_user(authenticated_user.user_id)
        .await;

    (
        StatusCode::OK,
        Json(NotificationGlobalPreferenceResponse {
            mute_state,
            notification_category,
            channel_default_category,
        }),
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
    tag = "Notifications"
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

    let global_category = state
        .message_repository
        .global_notification_category_for_user(authenticated_user.user_id)
        .await;

    let notification_category = state
        .message_repository
        .server_notification_category_for_user(authenticated_user.user_id, server_id)
        .await
        .unwrap_or(global_category);
    let mute_state = state
        .message_repository
        .server_mute_state_for_user(authenticated_user.user_id, server_id)
        .await;

    (
        StatusCode::OK,
        Json(NotificationServerPreferenceResponse {
            mute_state,
            notification_category,
        }),
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
    tag = "Notifications"
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
        .channel_temporary_mute_expires_at_epoch_seconds(authenticated_user.user_id, channel_id)
        .await;

    let channel_category = state
        .message_repository
        .channel_notification_category_for_user(authenticated_user.user_id, channel_id)
        .await;
    let global_channel_default = state
        .message_repository
        .global_channel_default_notification_category_for_user(authenticated_user.user_id)
        .await;
    let notification_category = channel_category.unwrap_or(global_channel_default);
    let mute_state = if muted_until_epoch_seconds.is_some() {
        NotificationMuteState::Muted
    } else {
        NotificationMuteState::Unmuted
    };

    (
        StatusCode::OK,
        Json(NotificationChannelPreferenceResponse {
            mute_state,
            muted_until_epoch_seconds,
            notification_category,
            inherited_from_global_default: channel_category.is_none(),
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
    tag = "Notifications"
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
    if let Some(notification_category) = request.notification_category {
        state
            .message_repository
            .set_global_notification_category_for_user(
                authenticated_user.user_id,
                notification_category,
            )
            .await;
    }

    if let Some(mute_state) = request.mute_state {
        state
            .message_repository
            .set_global_mute_state_for_user(authenticated_user.user_id, mute_state)
            .await;
    }

    if let Some(channel_default_category) = request.channel_default_category {
        state
            .message_repository
            .set_global_channel_default_notification_category_for_user(
                authenticated_user.user_id,
                channel_default_category,
            )
            .await;
    }

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
    tag = "Notifications"
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

    if let Some(notification_category) = request.notification_category {
        state
            .message_repository
            .set_server_notification_category_for_user(
                authenticated_user.user_id,
                server_id,
                notification_category,
            )
            .await;
    }

    if let Some(mute_state) = request.mute_state {
        state
            .message_repository
            .set_server_mute_state_for_user(authenticated_user.user_id, server_id, mute_state)
            .await;
    }

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
    tag = "Notifications"
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
        .set_channel_temporary_mute_for_user(
            authenticated_user.user_id,
            channel_id,
            request.duration_minutes,
        )
        .await;

    StatusCode::NO_CONTENT.into_response()
}

#[utoipa::path(
    patch,
    path = "/api/v1/channels/{channel_id}/notifications/preferences",
    request_body = UpdateNotificationChannelPreferenceRequest,
    responses(
        (status = 204, description = "Channel category preference updated"),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "Notifications"
)]
pub(crate) async fn update_channel_notification_preference<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
    Json(request): Json<UpdateNotificationChannelPreferenceRequest>,
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
        .set_channel_notification_category_for_user(
            authenticated_user.user_id,
            channel_id,
            request.notification_category,
        )
        .await;

    StatusCode::NO_CONTENT
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
    tag = "Notifications"
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
        .clear_channel_temporary_mute_for_user(authenticated_user.user_id, channel_id)
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
    tag = "Notifications"
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
    tag = "Notifications"
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

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/notifications/unread-from",
    request_body = MarkUnreadRequest,
    responses(
        (status = 204, description = "Unread count updated from specified message"),
        (status = 401, description = "Authentication failed"),
        (status = 403, description = "Not a channel member"),
        (status = 404, description = "Channel or message not found")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "Notifications"
)]
pub(crate) async fn mark_message_as_unread<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
    Json(body): Json<MarkUnreadRequest>,
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

    match state
        .message_repository
        .mark_unread_from_message(authenticated_user.user_id, channel_id, body.message_id)
        .await
    {
        MarkUnreadFromMessageResult::Updated => StatusCode::NO_CONTENT,
        MarkUnreadFromMessageResult::MessageNotFound => StatusCode::NOT_FOUND,
    }
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
    headers: HeaderMap,
    query: Query<WebSocketNotificationsQuery>,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + NotificationRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    let bearer_token = match websocket_bearer_token(&headers, query.0) {
        Ok(value) => value,
        Err(error) => return error.into_response(),
    };

    let authenticated_user = match resolve_authenticated_user(&state, &bearer_token).await {
        Ok(value) => value,
        Err(error) => return error.into_response(),
    };

    ws.on_upgrade(move |socket| async move {
        forward_notifications(socket, state, authenticated_user).await;
    })
}

#[derive(Deserialize)]
pub(crate) struct WebSocketNotificationsQuery {
    access_token: Option<String>,
}

fn websocket_bearer_token(
    headers: &HeaderMap,
    query: WebSocketNotificationsQuery,
) -> Result<String, AuthError> {
    if let Some(header_value) = headers.get("Authorization") {
        let raw_header_value = header_value
            .to_str()
            .map_err(|_| AuthError::NonBearerAuthorization)?;
        return parse_bearer_token(raw_header_value);
    }

    let token_from_query = query
        .access_token
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty())
        .ok_or(AuthError::MissingAuthorizationHeader)?;

    Ok(token_from_query)
}

async fn resolve_authenticated_user<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    state: &ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
    bearer_token: &str,
) -> Result<AuthenticatedUser, AuthError>
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + NotificationRepository,
    Verifier: TokenVerifier,
{
    let verified_user = state.auth_state.token_verifier.verify(bearer_token).await?;
    let user = state
        .user_repository
        .get_or_create_user_by_external_reference(&verified_user.external_reference)
        .await;

    Ok(AuthenticatedUser {
        user_id: user.id,
        external_reference: verified_user.external_reference,
    })
}

fn parse_bearer_token(authorization_value: &str) -> Result<String, AuthError> {
    let bearer_prefix = "Bearer ";

    if !authorization_value.starts_with(bearer_prefix) {
        return Err(AuthError::NonBearerAuthorization);
    }

    Ok(authorization_value
        .trim_start_matches(bearer_prefix)
        .to_owned())
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

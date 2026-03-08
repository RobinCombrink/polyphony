use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, Message, NotificationEventType};
use backend_storage::{
    ChannelRepository, CreateMessageResult, MessageRepository, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{ApiErrorResponse, CreateMessageRequest},
    notification_hub::{NotificationEnvelope, NotificationEvent},
};

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/messages",
    request_body = CreateMessageRequest,
    responses(
        (status = 201, description = "Message created", body = Message),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 422, description = "Channel does not support text messages", body = ApiErrorResponse),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn create_message<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
    Json(request): Json<CreateMessageRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let channel = match state
        .channel_repository
        .find_channel_by_id(channel_id)
        .await
    {
        Some(channel) => channel,
        None => return StatusCode::NOT_FOUND.into_response(),
    };
    let server_name = match state
        .server_repository
        .list_servers_for_user(authenticated_user.user_id)
        .await
        .into_iter()
        .find(|candidate| candidate.id == channel.server_id())
    {
        Some(server) => server.name,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

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

    let created_message = state
        .message_repository
        .create_message(
            channel_id,
            authenticated_user.user_id,
            request.content,
            request.mentioned_user_id,
        )
        .await;

    match created_message {
        CreateMessageResult::Created {
            message,
            notified_user_ids,
        } => {
            let event_type = if message.is_mentioned() {
                NotificationEventType::Mentioned
            } else {
                NotificationEventType::UnreadMessage
            };

            for recipient_user_id in notified_user_ids {
                state.notification_hub.publish(NotificationEnvelope {
                    recipient_user_id,
                    event: NotificationEvent {
                        event_type,
                        server_id: channel.server_id(),
                        server_name: server_name.clone(),
                        channel_id: message.channel_id(),
                        channel_name: channel.name().to_owned(),
                        message_id: message.id(),
                    },
                });
            }

            (StatusCode::CREATED, Json(message)).into_response()
        }
        CreateMessageResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        CreateMessageResult::ChannelKindMismatch => (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(ApiErrorResponse::new(
                "CHANNEL_KIND_MISMATCH",
                "channel does not support text messages",
            )),
        )
            .into_response(),
        CreateMessageResult::NotFound => StatusCode::NOT_FOUND.into_response(),
    }
}

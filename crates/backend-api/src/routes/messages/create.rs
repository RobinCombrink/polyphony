use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, Message};
use backend_storage::{
    ChannelRepository, CreateMessageResult, MessageRepository, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{ApiErrorResponse, CreateMessageRequest},
    notification_hub::{NotificationEnvelope, NotificationEvent},
    use_cases::messages::create_message as create_message_use_case,
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
    tag = "Messages"
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
    let outcome = match create_message_use_case(
        &*state.channel_repository,
        &*state.server_repository,
        &*state.message_repository,
        channel_id,
        authenticated_user.user_id,
        request.content,
        request.mentioned_user_id,
    )
    .await
    {
        Ok(outcome) => outcome,
        Err(error) => return error.into_response(),
    };

    let ctx = outcome.context;
    match outcome.result {
        CreateMessageResult::Created {
            message,
            notified_user_ids,
        } => {
            for recipient_user_id in notified_user_ids {
                let event = if message.is_mentioned() {
                    NotificationEvent::mentioned(
                        ctx.server_id,
                        ctx.server_name.clone(),
                        message.channel_id(),
                        ctx.channel_name.clone(),
                        message.id(),
                    )
                } else {
                    NotificationEvent::unread_message(
                        ctx.server_id,
                        ctx.server_name.clone(),
                        message.channel_id(),
                        ctx.channel_name.clone(),
                        message.id(),
                    )
                };

                state.notification_hub.publish(NotificationEnvelope {
                    recipient_user_id,
                    event,
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

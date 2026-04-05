use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, Message, MessageId};
use backend_storage::{
    ChannelRepository, MessageRepository, MutationResult, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::UpdateMessageRequest,
};

#[utoipa::path(
    patch,
    path = "/api/v1/channels/{channel_id}/messages/{message_id}",
    request_body = UpdateMessageRequest,
    responses(
        (status = 200, description = "Message updated", body = Message),
        (status = 403, description = "Message not owned by authenticated user"),
        (status = 404, description = "Message not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("channel_id" = ChannelId, Path, description = "Channel id"),
        ("message_id" = MessageId, Path, description = "Message id")
    ),
    tag = "Messages"
)]
pub(crate) async fn update_message<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(ChannelId, MessageId)>,
    Json(request): Json<UpdateMessageRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let Ok(mutation_result) = state
        .message_repository
        .update_message(
            channel_id,
            message_id,
            authenticated_user.user_id,
            request.content,
        )
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    match mutation_result {
        MutationResult::Updated => {
            let Ok(messages) = state
                .message_repository
                .list_messages(channel_id)
                .await
            else {
                return StatusCode::INTERNAL_SERVER_ERROR.into_response();
            };

            let updated_message = messages
                .into_iter()
                .find(|message| message.id() == message_id);

            match updated_message {
                Some(message) => (StatusCode::OK, Json(message)).into_response(),
                None => StatusCode::NOT_FOUND.into_response(),
            }
        }
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Deleted => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

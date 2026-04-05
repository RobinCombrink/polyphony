use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, MessageId};
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    response_mapping::DeletedResponse,
};

#[utoipa::path(
    delete,
    path = "/api/v1/channels/{channel_id}/messages/{message_id}",
    responses(
        (status = 204, description = "Message deleted"),
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
pub(crate) async fn delete_message<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(ChannelId, MessageId)>,
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
        .delete_message(channel_id, message_id, authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    DeletedResponse(mutation_result).into_response()
}

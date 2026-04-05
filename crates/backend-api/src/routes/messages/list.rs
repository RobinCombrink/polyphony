use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::ChannelId;
use backend_domain::Message;
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    use_cases::require_channel_membership,
};

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/messages",
    responses(
        (status = 200, description = "Messages listed", body = [Message]),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = ChannelId, Path, description = "Channel id")),
    tag = "Messages"
)]
pub(crate) async fn list_messages<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
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
    if let Err(gate_error) = require_channel_membership(
        &*state.channel_repository,
        channel_id,
        authenticated_user.user_id,
    )
    .await
    {
        return gate_error.into_response();
    }

    let Ok(messages) = state.message_repository.list_messages(channel_id).await else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    (StatusCode::OK, Json(messages)).into_response()
}

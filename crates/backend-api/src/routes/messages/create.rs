use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::ChannelId;
use backend_domain::Message;
use backend_storage::{
    ChannelRepository, CreateMessageResult, MessageRepository, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{ApiErrorResponse, CreateMessageRequest},
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
        .create_message(channel_id, authenticated_user.user_id, request.content)
        .await;

    match created_message {
        CreateMessageResult::Created(message) => {
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

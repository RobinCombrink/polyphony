use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::Message;
use backend_storage::MutationResult;
use uuid::Uuid;

use crate::{ApiState, auth::AuthenticatedUser, dto::UpdateMessageRequest};

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
        ("channel_id" = Uuid, Path, description = "Channel id"),
        ("message_id" = Uuid, Path, description = "Message id")
    ),
    tag = "backend-api"
)]
pub(crate) async fn update_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(Uuid, Uuid)>,
    Json(request): Json<UpdateMessageRequest>,
) -> impl IntoResponse {
    let mutation_result = state
        .message_repository
        .update_message(
            channel_id,
            message_id,
            &authenticated_user.subject,
            request.content,
        )
        .await;

    match mutation_result {
        MutationResult::Updated => {
            let updated_message = state
                .message_repository
                .list_messages(channel_id)
                .await
                .into_iter()
                .find(|message| message.id == message_id);

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

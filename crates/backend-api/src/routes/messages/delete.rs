use axum::{
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_storage::MutationResult;

use crate::{ApiState, auth::AuthenticatedUser};

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
        ("channel_id" = String, Path, description = "Channel id"),
        ("message_id" = String, Path, description = "Message id")
    ),
    tag = "backend-api"
)]
pub(crate) async fn delete_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(String, String)>,
) -> impl IntoResponse {
    let mutation_result = state
        .store
        .delete_message(&channel_id, &message_id, &authenticated_user.subject)
        .await;

    match mutation_result {
        MutationResult::Deleted => StatusCode::NO_CONTENT.into_response(),
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Updated => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::Message;
use backend_storage::MutationResult;

use crate::{
    ApiState,
    auth::AuthenticatedUser,
    dto::{CreateMessageRequest, UpdateMessageRequest},
};

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/messages",
    request_body = CreateMessageRequest,
    responses(
        (status = 201, description = "Message created", body = Message),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn create_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
    Json(request): Json<CreateMessageRequest>,
) -> impl IntoResponse {
    let created_message = state
        .store
        .create_message(&channel_id, authenticated_user.subject, request.content)
        .await;

    match created_message {
        Some(message) => (StatusCode::CREATED, Json(message)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

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
        ("channel_id" = String, Path, description = "Channel id"),
        ("message_id" = String, Path, description = "Message id")
    ),
    tag = "backend-api"
)]
pub(crate) async fn update_message(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path((channel_id, message_id)): Path<(String, String)>,
    Json(request): Json<UpdateMessageRequest>,
) -> impl IntoResponse {
    let mutation_result = state
        .store
        .update_message(
            &channel_id,
            &message_id,
            &authenticated_user.subject,
            request.content,
        )
        .await;

    match mutation_result {
        MutationResult::Updated => {
            let updated_message = state
                .store
                .list_messages(&channel_id)
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

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/messages",
    responses(
        (status = 200, description = "Messages listed", body = [Message]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn list_messages(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let messages = state.store.list_messages(&channel_id).await;

    (StatusCode::OK, Json(messages))
}

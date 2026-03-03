use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::Message;
use backend_storage::MessageRepository;
use uuid::Uuid;

use crate::{ApiState, RepositoryProfile, auth::AuthenticatedUser};

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/messages",
    responses(
        (status = 200, description = "Messages listed", body = [Message]),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn list_messages<Repos>(
    State(state): State<ApiState<Repos>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
) -> impl IntoResponse
where
    Repos: RepositoryProfile,
{
    let _ = authenticated_user;

    let messages = state.message_repository.list_messages(channel_id).await;

    (StatusCode::OK, Json(messages))
}

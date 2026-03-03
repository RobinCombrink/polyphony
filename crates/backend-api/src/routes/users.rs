use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};
use uuid::Uuid;

use crate::{ApiState, auth::AuthenticatedUser, dto::UserLookupResponse};

#[utoipa::path(
    get,
    path = "/api/v1/users/{user_id}",
    params(
        ("user_id" = Uuid, Path, description = "User identifier")
    ),
    responses(
        (status = 200, description = "User profile by id", body = UserLookupResponse),
        (status = 401, description = "Authentication failed"),
        (status = 404, description = "User not found")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn get_user_by_id<UserRepo, ServerRepo, ChannelRepo, MessageRepo>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo>>,
    _authenticated_user: AuthenticatedUser,
    Path(user_id): Path<Uuid>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
{
    let Some(user) = state.user_repository.find_user_by_id(user_id).await else {
        return StatusCode::NOT_FOUND.into_response();
    };

    (
        StatusCode::OK,
        Json(UserLookupResponse {
            id: user.id,
            display_name: user.display_name.map(String::from),
        }),
    )
        .into_response()
}

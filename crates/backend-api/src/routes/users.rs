use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};

use crate::{
    ApiState,
    auth::AuthenticatedUser,
    dto::UserLookupResponse,
};

#[utoipa::path(
    get,
    path = "/api/v1/users/{user_id}",
    params(
        ("user_id" = String, Path, description = "User identifier (Auth0 subject)")
    ),
    responses(
        (status = 200, description = "User profile by id", body = UserLookupResponse),
        (status = 401, description = "Authentication failed"),
        (status = 404, description = "User not found")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn get_user_by_id(
    State(state): State<ApiState>,
    _authenticated_user: AuthenticatedUser,
    Path(user_id): Path<String>,
) -> impl IntoResponse {
    let Some(user) = state.store.find_user_by_subject(&user_id).await else {
        return StatusCode::NOT_FOUND.into_response();
    };

    (
        StatusCode::OK,
        Json(UserLookupResponse {
            id: user.auth0_subject,
            display_name: user.display_name.map(String::from),
        }),
    )
        .into_response()
}

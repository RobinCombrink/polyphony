use axum::{Json, extract::State, http::StatusCode, response::IntoResponse};

use crate::{ApiState, auth::AuthenticatedUser, dto::{MeResponse, UpdateMeRequest}};

#[utoipa::path(
    get,
    path = "/api/v1/me",
    responses(
        (status = 200, description = "Authenticated user identity", body = MeResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn me(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse {
    let user = state
        .chat_repository
        .get_or_create_user(&authenticated_user.subject)
        .await;

    let response = MeResponse {
        user_id: authenticated_user.subject,
        display_name: user.display_name.map(String::from),
        issuer: state.auth_state.config.issuer.to_string(),
        token_duration_hours: state.auth_state.config.token_duration_hours,
    };

    (StatusCode::OK, Json(response))
}

#[utoipa::path(
    patch,
    path = "/api/v1/me",
    request_body = UpdateMeRequest,
    responses(
        (status = 200, description = "Authenticated user profile updated", body = MeResponse),
        (status = 400, description = "Display name is required"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "backend-api"
)]
pub(crate) async fn update_me(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<UpdateMeRequest>,
) -> impl IntoResponse {
    let trimmed_display_name = request.display_name.trim();

    if trimmed_display_name.is_empty() {
        return StatusCode::BAD_REQUEST.into_response();
    }

    let updated_user = state
        .chat_repository
        .set_user_display_name(&authenticated_user.subject, trimmed_display_name.to_owned())
        .await;

    (
        StatusCode::OK,
        Json(MeResponse {
            user_id: updated_user.auth0_subject,
            display_name: updated_user.display_name.map(String::from),
            issuer: state.auth_state.config.issuer.to_string(),
            token_duration_hours: state.auth_state.config.token_duration_hours,
        }),
    )
        .into_response()
}

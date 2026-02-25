use axum::{Json, extract::State, http::StatusCode, response::IntoResponse};

use crate::{ApiState, auth::AuthenticatedUser, dto::MeResponse};

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
    let response = MeResponse {
        user_id: authenticated_user.subject,
        issuer: state.auth_state.config.issuer.to_string(),
        token_duration_hours: state.auth_state.config.token_duration_hours,
    };

    (StatusCode::OK, Json(response))
}

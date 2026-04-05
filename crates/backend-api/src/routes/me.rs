use axum::{Json, extract::State, http::StatusCode, response::IntoResponse};
use backend_domain::DisplayName;
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{MeResponse, UpdateMeRequest},
};

#[utoipa::path(
    get,
    path = "/api/v1/me",
    responses(
        (status = 200, description = "Authenticated user identity", body = MeResponse),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    tag = "Identity"
)]
pub(crate) async fn me<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let user = state
        .user_repository
        .find_user_by_id(authenticated_user.user_id)
        .await;

    let response = MeResponse {
        user_id: authenticated_user.user_id,
        external_reference: authenticated_user.external_reference,
        display_name: user
            .ok()
            .flatten()
            .and_then(|value| value.display_name)
            .map(String::from),
        issuer: state.auth_state.config.issuer.to_string(),
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
    tag = "Identity"
)]
pub(crate) async fn update_me<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Json(request): Json<UpdateMeRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let display_name = match DisplayName::new(request.display_name) {
        Ok(name) => name,
        Err(_) => return StatusCode::BAD_REQUEST.into_response(),
    };

    let Ok(updated_user) = state
        .user_repository
        .set_user_display_name(authenticated_user.user_id, display_name)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let Some(updated_user) = updated_user else {
        return StatusCode::NOT_FOUND.into_response();
    };

    (
        StatusCode::OK,
        Json(MeResponse {
            user_id: updated_user.id,
            external_reference: updated_user.external_reference,
            display_name: updated_user.display_name.map(String::from),
            issuer: state.auth_state.config.issuer.to_string(),
        }),
    )
        .into_response()
}

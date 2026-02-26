use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::VoiceSession;
use backend_storage::MutationResult;
use livekit_api::access_token::{AccessToken, VideoGrants};

use crate::dto::VoiceConnectResponse;

use crate::{ApiState, auth::AuthenticatedUser};

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/voice/sessions",
    responses(
        (status = 201, description = "Voice session joined", body = VoiceSession),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn join_voice_session(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let joined_session = state
        .store
        .join_voice_session(&channel_id, authenticated_user.subject)
        .await;

    match joined_session {
        Some(session) => (StatusCode::CREATED, Json(session)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    delete,
    path = "/api/v1/channels/{channel_id}/voice/sessions/me",
    responses(
        (status = 204, description = "Voice session left"),
        (status = 404, description = "Channel or participant session not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn leave_voice_session(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let mutation_result = state
        .store
        .leave_voice_session(&channel_id, &authenticated_user.subject)
        .await;

    match mutation_result {
        MutationResult::Deleted => StatusCode::NO_CONTENT.into_response(),
        MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        MutationResult::Updated => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/voice/sessions",
    responses(
        (status = 200, description = "Voice sessions listed", body = [VoiceSession]),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn list_voice_sessions(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let _ = authenticated_user;

    let sessions = state.store.list_voice_sessions(&channel_id).await;

    match sessions {
        Some(voice_sessions) => (StatusCode::OK, Json(voice_sessions)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/voice/connect",
    responses(
        (status = 200, description = "LiveKit connection details returned", body = VoiceConnectResponse),
        (status = 404, description = "Channel not found"),
        (status = 500, description = "Failed to create access token"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn connect_voice_session(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let participant_subject = authenticated_user.subject;

    let joined_session = state
        .store
        .join_voice_session(&channel_id, participant_subject.clone())
        .await;

    if joined_session.is_none() {
        return StatusCode::NOT_FOUND.into_response();
    }

    let grants = VideoGrants {
        room_join: true,
        room: channel_id.clone(),
        can_publish: true,
        can_subscribe: true,
        ..Default::default()
    };

    let access_token = match AccessToken::with_api_key(
        &state.livekit_config.api_key,
        &state.livekit_config.api_secret,
    )
    .with_identity(&participant_subject)
    .with_ttl(std::time::Duration::from_secs(
        state.livekit_config.token_ttl_seconds,
    ))
    .with_grants(grants)
    .to_jwt()
    {
        Ok(token) => token,
        Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    };

    (
        StatusCode::OK,
        Json(VoiceConnectResponse {
            livekit_url: state.livekit_config.url.clone(),
            access_token,
            channel_id,
            participant_subject,
        }),
    )
        .into_response()
}

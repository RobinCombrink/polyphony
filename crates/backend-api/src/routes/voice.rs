use crate::dto::{SetVoiceSessionMuteRequest, VoiceConnectResponse};
use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::VoiceSession;
use livekit_api::access_token::{AccessToken, VideoGrants};
use uuid::Uuid;

use crate::{ApiState, auth::AuthenticatedUser};

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
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn connect_voice_session(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
) -> impl IntoResponse {
    let participant_user_id = authenticated_user.user_id;

    if state
        .voice_repository
        .join_voice_session(channel_id, participant_user_id)
        .await
        .is_none()
    {
        return StatusCode::NOT_FOUND.into_response();
    }

    let grants = VideoGrants {
        room_join: true,
        room: channel_id.to_string(),
        can_publish: true,
        can_subscribe: true,
        ..Default::default()
    };

    let access_token = match AccessToken::with_api_key(
        &state.livekit_config.api_key,
        &state.livekit_config.api_secret,
    )
    .with_identity(&participant_user_id.to_string())
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
            channel_id: channel_id.to_string(),
            participant_user_id: participant_user_id.to_string(),
        }),
    )
        .into_response()
}

#[utoipa::path(
    patch,
    path = "/api/v1/channels/{channel_id}/voice/self",
    request_body = SetVoiceSessionMuteRequest,
    responses(
        (status = 204, description = "Voice session mute state updated"),
        (status = 404, description = "Voice channel or session not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn update_self_mute_state(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
    Json(request): Json<SetVoiceSessionMuteRequest>,
) -> impl IntoResponse {
    let mutation_result = state
        .voice_repository
        .set_voice_session_muted(channel_id, authenticated_user.user_id, request.is_muted)
        .await;

    match mutation_result {
        backend_storage::MutationResult::Updated => StatusCode::NO_CONTENT.into_response(),
        backend_storage::MutationResult::NotFound => StatusCode::NOT_FOUND.into_response(),
        backend_storage::MutationResult::Forbidden => StatusCode::FORBIDDEN.into_response(),
        backend_storage::MutationResult::Deleted => StatusCode::NO_CONTENT.into_response(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/voice/sessions",
    responses(
        (status = 200, description = "Voice sessions returned", body = [VoiceSession]),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn list_voice_sessions(
    State(state): State<ApiState>,
    _authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
) -> impl IntoResponse {
    match state.voice_repository.list_voice_sessions(channel_id).await {
        Some(voice_sessions) => (StatusCode::OK, Json(voice_sessions)).into_response(),
        None => StatusCode::NOT_FOUND.into_response(),
    }
}

use crate::dto::VoiceConnectResponse;
use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use livekit_api::access_token::{AccessToken, VideoGrants};

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
    params(("channel_id" = String, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn connect_voice_session(
    State(state): State<ApiState>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<String>,
) -> impl IntoResponse {
    let participant_subject = authenticated_user.subject;

    if state.store.list_voice_sessions(&channel_id).await.is_none() {
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

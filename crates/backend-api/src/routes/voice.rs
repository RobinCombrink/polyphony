use crate::{
    auth::TokenVerifier,
    dto::{ApiErrorResponse, CreateSessionRequest, VoiceConnectResponse},
};
use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::Channel;
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};
use livekit_api::access_token::{AccessToken, VideoGrants};
use uuid::Uuid;

use crate::{ApiState, auth::AuthenticatedUser};

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/session",
    request_body = CreateSessionRequest,
    responses(
        (status = 200, description = "LiveKit connection details returned", body = VoiceConnectResponse),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 422, description = "Requested session type does not match channel type", body = ApiErrorResponse),
        (status = 404, description = "Channel not found"),
        (status = 500, description = "Failed to create access token"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(("channel_id" = Uuid, Path, description = "Channel id")),
    tag = "backend-api"
)]
pub(crate) async fn create_session<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<Uuid>,
    Json(request): Json<CreateSessionRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let is_channel_member = match state
        .channel_repository
        .is_channel_member(channel_id, authenticated_user.user_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    if !is_channel_member {
        return StatusCode::FORBIDDEN.into_response();
    }

    let channel = match state
        .channel_repository
        .find_channel_by_id(channel_id)
        .await
    {
        Some(value) => value,
        None => return StatusCode::NOT_FOUND.into_response(),
    };

    let channel_type = channel.kind();
    if channel_type != request.session_type {
        return (
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(ApiErrorResponse::new(
                "CHANNEL_KIND_MISMATCH",
                "requested session type does not match channel type",
            )),
        )
            .into_response();
    }

    let participant_instance_id = request
        .participant_instance_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty());

    let can_publish = match channel {
        Channel::Voice { .. } => participant_instance_id.is_none(),
        Channel::Text { .. } => false,
    };

    let participant_user_id = authenticated_user.user_id;
    let participant_identity = match participant_instance_id {
        Some(instance_id) => format!("{}:{instance_id}", participant_user_id),
        None => participant_user_id.to_string(),
    };

    let grants = VideoGrants {
        room_join: true,
        room: channel_id.to_string(),
        can_publish,
        can_subscribe: true,
        can_update_own_metadata: true,
        ..Default::default()
    };

    let access_token = match AccessToken::with_api_key(
        &state.livekit_config.api_key,
        &state.livekit_config.api_secret,
    )
    .with_identity(&participant_identity)
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

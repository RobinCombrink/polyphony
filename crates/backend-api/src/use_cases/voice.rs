use axum::{Json, http::StatusCode, response::IntoResponse};
use backend_domain::{Channel, ChannelId, ChannelType, UserId};
use backend_storage::ChannelRepository;

use crate::dto::ApiErrorResponse;

use super::guards::{MembershipGateError, require_channel_membership};

pub(crate) enum CreateSessionError {
    Gate(MembershipGateError),
    ChannelKindMismatch,
    InfraError,
}

impl IntoResponse for CreateSessionError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::Gate(gate_error) => gate_error.into_response(),
            Self::ChannelKindMismatch => (
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(ApiErrorResponse::new(
                    "CHANNEL_KIND_MISMATCH",
                    "requested session type does not match channel type",
                )),
            )
                .into_response(),
            Self::InfraError => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }
}

pub(crate) async fn validate_voice_session(
    channel_repo: &impl ChannelRepository,
    channel_id: ChannelId,
    user_id: UserId,
    requested_session_type: ChannelType,
) -> Result<Channel, CreateSessionError> {
    let channel = match channel_repo.find_channel_by_id(channel_id).await {
        Ok(Some(channel)) => channel,
        Ok(None) => return Err(CreateSessionError::Gate(MembershipGateError::NotFound)),
        Err(_) => return Err(CreateSessionError::InfraError),
    };

    require_channel_membership(channel_repo, channel_id, user_id)
        .await
        .map_err(CreateSessionError::Gate)?;

    if channel.kind() != requested_session_type {
        return Err(CreateSessionError::ChannelKindMismatch);
    }

    Ok(channel)
}

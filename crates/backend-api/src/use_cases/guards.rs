use axum::{http::StatusCode, response::IntoResponse};
use backend_domain::{ChannelId, ServerId, UserId};
use backend_storage::{ChannelRepository, ServerRepository};

pub(crate) enum MembershipGateError {
    NotFound,
    NotMember,
    InfraError,
}

impl IntoResponse for MembershipGateError {
    fn into_response(self) -> axum::response::Response {
        StatusCode::from(&self).into_response()
    }
}

impl From<&MembershipGateError> for StatusCode {
    fn from(value: &MembershipGateError) -> Self {
        match value {
            MembershipGateError::NotFound => StatusCode::NOT_FOUND,
            MembershipGateError::NotMember => StatusCode::FORBIDDEN,
            MembershipGateError::InfraError => StatusCode::INTERNAL_SERVER_ERROR,
        }
    }
}

pub(crate) async fn require_channel_membership(
    channel_repo: &impl ChannelRepository,
    channel_id: ChannelId,
    user_id: UserId,
) -> Result<(), MembershipGateError> {
    match channel_repo.is_channel_member(channel_id, user_id).await {
        Ok(Some(true)) => Ok(()),
        Ok(Some(false)) => Err(MembershipGateError::NotMember),
        Ok(None) => Err(MembershipGateError::NotFound),
        Err(_) => Err(MembershipGateError::InfraError),
    }
}

pub(crate) async fn require_server_membership(
    server_repo: &impl ServerRepository,
    server_id: ServerId,
    user_id: UserId,
) -> Result<(), MembershipGateError> {
    match server_repo.is_server_member(server_id, user_id).await {
        Ok(Some(true)) => Ok(()),
        Ok(Some(false)) => Err(MembershipGateError::NotMember),
        Ok(None) => Err(MembershipGateError::NotFound),
        Err(_) => Err(MembershipGateError::InfraError),
    }
}

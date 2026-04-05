use backend_domain::{Channel, ChannelId, ChannelType, UserId};
use backend_storage::ChannelRepository;

use super::guards::{MembershipGateError, require_channel_membership};

pub(crate) enum CreateSessionError {
    Gate(MembershipGateError),
    ChannelKindMismatch,
    InfraError,
}

pub(crate) async fn validate_voice_session(
    channel_repo: &impl ChannelRepository,
    channel_id: ChannelId,
    user_id: UserId,
    requested_session_type: ChannelType,
) -> Result<Channel, CreateSessionError> {
    require_channel_membership(channel_repo, channel_id, user_id)
        .await
        .map_err(CreateSessionError::Gate)?;

    let channel = match channel_repo.find_channel_by_id(channel_id).await {
        Ok(Some(channel)) => channel,
        Ok(None) => return Err(CreateSessionError::Gate(MembershipGateError::NotFound)),
        Err(_) => return Err(CreateSessionError::InfraError),
    };

    if channel.kind() != requested_session_type {
        return Err(CreateSessionError::ChannelKindMismatch);
    }

    Ok(channel)
}

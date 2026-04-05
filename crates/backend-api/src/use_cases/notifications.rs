use backend_domain::{
    ChannelId, NotificationCategoryPreference, NotificationMuteState, ServerId, UserId,
};
use backend_storage::NotificationRepository;

use super::guards::{MembershipGateError, require_channel_membership, require_server_membership};
use backend_storage::{ChannelRepository, ServerRepository};

pub(crate) struct GlobalPreference {
    pub(crate) mute_state: NotificationMuteState,
    pub(crate) notification_category: NotificationCategoryPreference,
    pub(crate) channel_default_category: NotificationCategoryPreference,
}

pub(crate) struct ServerPreference {
    pub(crate) mute_state: NotificationMuteState,
    pub(crate) notification_category: NotificationCategoryPreference,
}

pub(crate) struct ChannelPreference {
    pub(crate) mute_state: NotificationMuteState,
    pub(crate) muted_until_epoch_seconds: Option<u64>,
    pub(crate) notification_category: NotificationCategoryPreference,
    pub(crate) inherited_from_global_default: bool,
}

pub(crate) enum NotificationPreferenceError {
    Gate(MembershipGateError),
    InfraError,
}

pub(crate) async fn get_global_preference(
    notification_repo: &impl NotificationRepository,
    user_id: UserId,
) -> Result<GlobalPreference, NotificationPreferenceError> {
    let mute_state = notification_repo
        .global_mute_state_for_user(user_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;
    let notification_category = notification_repo
        .global_notification_category_for_user(user_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;
    let channel_default_category = notification_repo
        .global_channel_default_notification_category_for_user(user_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;

    Ok(GlobalPreference {
        mute_state,
        notification_category,
        channel_default_category,
    })
}

pub(crate) async fn get_server_preference(
    server_repo: &impl ServerRepository,
    notification_repo: &impl NotificationRepository,
    server_id: ServerId,
    user_id: UserId,
) -> Result<ServerPreference, NotificationPreferenceError> {
    require_server_membership(server_repo, server_id, user_id)
        .await
        .map_err(NotificationPreferenceError::Gate)?;

    let global_category = notification_repo
        .global_notification_category_for_user(user_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;
    let server_category = notification_repo
        .server_notification_category_for_user(user_id, server_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;
    let notification_category = server_category.unwrap_or(global_category);
    let mute_state = notification_repo
        .server_mute_state_for_user(user_id, server_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;

    Ok(ServerPreference {
        mute_state,
        notification_category,
    })
}

pub(crate) async fn get_channel_preference(
    channel_repo: &impl ChannelRepository,
    notification_repo: &impl NotificationRepository,
    channel_id: ChannelId,
    user_id: UserId,
) -> Result<ChannelPreference, NotificationPreferenceError> {
    require_channel_membership(channel_repo, channel_id, user_id)
        .await
        .map_err(NotificationPreferenceError::Gate)?;

    let muted_until_epoch_seconds = notification_repo
        .channel_temporary_mute_expires_at_epoch_seconds(user_id, channel_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;
    let channel_category = notification_repo
        .channel_notification_category_for_user(user_id, channel_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;
    let global_channel_default = notification_repo
        .global_channel_default_notification_category_for_user(user_id)
        .await
        .map_err(|_| NotificationPreferenceError::InfraError)?;

    let notification_category = channel_category.unwrap_or(global_channel_default);
    let mute_state = if muted_until_epoch_seconds.is_some() {
        NotificationMuteState::Muted
    } else {
        NotificationMuteState::Unmuted
    };

    Ok(ChannelPreference {
        mute_state,
        muted_until_epoch_seconds,
        notification_category,
        inherited_from_global_default: channel_category.is_none(),
    })
}

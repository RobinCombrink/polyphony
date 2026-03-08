use backend_domain::{NotificationCategoryPreference, NotificationMuteState};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct NotificationChannelPreferenceResponse {
    pub mute_state: NotificationMuteState,
    pub muted_until_epoch_seconds: Option<u64>,
    pub notification_category: NotificationCategoryPreference,
    pub inherited_from_global_default: bool,
}

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use backend_domain::{NotificationCategoryPreference, NotificationMuteState};

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct NotificationGlobalPreferenceResponse {
    pub mute_state: NotificationMuteState,
    pub notification_category: NotificationCategoryPreference,
    pub channel_default_category: NotificationCategoryPreference,
}

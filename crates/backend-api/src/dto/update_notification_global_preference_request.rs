use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use backend_domain::{NotificationCategoryPreference, NotificationMuteState};

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct UpdateNotificationGlobalPreferenceRequest {
    pub mute_state: Option<NotificationMuteState>,
    pub notification_category: Option<NotificationCategoryPreference>,
    pub channel_default_category: Option<NotificationCategoryPreference>,
}

use backend_domain::{NotificationCategoryPreference, NotificationMuteState};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct UpdateNotificationServerPreferenceRequest {
    pub mute_state: Option<NotificationMuteState>,
    pub notification_category: Option<NotificationCategoryPreference>,
}

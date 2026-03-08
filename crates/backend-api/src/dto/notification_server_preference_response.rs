use backend_domain::{NotificationCategoryPreference, NotificationMuteState};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct NotificationServerPreferenceResponse {
    pub mute_state: NotificationMuteState,
    pub notification_category: NotificationCategoryPreference,
}

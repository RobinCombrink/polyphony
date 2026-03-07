use backend_domain::NotificationCategoryPreference;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct UpdateNotificationChannelPreferenceRequest {
    pub notification_category: NotificationCategoryPreference,
}

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct NotificationChannelPreferenceResponse {
    pub muted: bool,
    pub muted_until_epoch_seconds: Option<u64>,
}

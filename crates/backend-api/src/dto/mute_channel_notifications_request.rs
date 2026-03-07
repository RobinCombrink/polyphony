use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct MuteChannelNotificationsRequest {
    pub duration_minutes: u32,
}

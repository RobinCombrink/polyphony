use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Deserialize, Serialize, ToSchema)]
pub struct NotificationGlobalPreferenceResponse {
    pub muted: bool,
}

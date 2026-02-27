use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct MeResponse {
    pub user_id: String,
    pub display_name: Option<String>,
    pub issuer: String,
    pub token_duration_hours: u64,
}

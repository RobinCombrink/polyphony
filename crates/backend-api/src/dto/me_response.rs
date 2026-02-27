use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct MeResponse {
    pub user_id: Uuid,
    pub external_reference: String,
    pub display_name: Option<String>,
    pub issuer: String,
    pub token_duration_hours: u64,
}

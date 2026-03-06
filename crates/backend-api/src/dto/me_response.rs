use backend_domain::{ExternalReference, UserId};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct MeResponse {
    pub user_id: UserId,
    pub external_reference: ExternalReference,
    pub display_name: Option<String>,
    pub issuer: String,
    pub token_duration_hours: u64,
}

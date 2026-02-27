use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

use crate::DisplayName;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct User {
    pub id: Uuid,
    pub external_reference: String,
    pub display_name: Option<DisplayName>,
}

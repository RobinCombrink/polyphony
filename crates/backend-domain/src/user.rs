use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{DisplayName, ExternalReference, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct User {
    pub id: UserId,
    pub external_reference: ExternalReference,
    pub display_name: Option<DisplayName>,
}

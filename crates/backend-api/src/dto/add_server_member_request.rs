use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::domain::UserId;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct AddServerMemberRequest {
    pub user_id: UserId,
}

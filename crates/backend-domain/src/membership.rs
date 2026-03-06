use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{ServerId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct Membership {
    pub user_id: UserId,
    pub server_id: ServerId,
}

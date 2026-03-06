use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{ServerId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct Server {
    pub id: ServerId,
    pub name: String,
    pub owner_user_id: UserId,
}

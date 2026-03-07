use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use backend_domain::UserId;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct CreateMessageRequest {
    pub content: String,
    pub mentioned_user_id: Option<UserId>,
}

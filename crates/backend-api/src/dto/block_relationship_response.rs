use backend_domain::UserId;
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct BlockRelationshipResponse {
    pub blocked_user_id: UserId,
}

use backend_domain::UserId;
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct FriendSummaryResponse {
    pub user_id: UserId,
}

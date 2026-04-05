use backend_domain::{FriendRequest, FriendRequestId, FriendRequestState, UserId};
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct FriendRequestResponse {
    pub id: FriendRequestId,
    pub requester_user_id: UserId,
    pub addressee_user_id: UserId,
    pub state: FriendRequestState,
}

impl From<FriendRequest> for FriendRequestResponse {
    fn from(value: FriendRequest) -> Self {
        Self {
            id: value.id,
            requester_user_id: value.requester_user_id,
            addressee_user_id: value.addressee_user_id,
            state: value.state,
        }
    }
}

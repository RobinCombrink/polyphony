use serde::{Deserialize, Serialize};
use strum::{AsRefStr, Display, EnumString};
use utoipa::ToSchema;

use crate::{BlockRelationshipId, FriendRequestId, FriendshipId, UserId};

#[derive(
    Debug,
    Clone,
    Copy,
    PartialEq,
    Eq,
    Serialize,
    Deserialize,
    ToSchema,
    EnumString,
    Display,
    AsRefStr,
    sqlx::Type,
)]
#[serde(rename_all = "snake_case")]
#[strum(serialize_all = "snake_case")]
#[sqlx(type_name = "friend_request_state", rename_all = "snake_case")]
pub enum FriendRequestState {
    Pending,
    Accepted,
    Declined,
    Cancelled,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct FriendRequest {
    pub id: FriendRequestId,
    pub requester_user_id: UserId,
    pub addressee_user_id: UserId,
    pub state: FriendRequestState,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct Friendship {
    pub id: FriendshipId,
    pub user_a_id: UserId,
    pub user_b_id: UserId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct BlockRelationship {
    pub id: BlockRelationshipId,
    pub blocker_user_id: UserId,
    pub blocked_user_id: UserId,
    pub restored_friendship_id: Option<FriendshipId>,
}

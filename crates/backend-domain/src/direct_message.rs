use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{DirectMessageId, DirectMessageThreadId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct DirectMessageThread {
    pub id: DirectMessageThreadId,
    pub participant_a_user_id: UserId,
    pub participant_b_user_id: UserId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct DirectMessage {
    pub id: DirectMessageId,
    pub thread_id: DirectMessageThreadId,
    pub author_user_id: UserId,
    pub content: String,
}

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{EmoteId, MessageId, ReactionId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct MessageReaction {
    pub id: ReactionId,
    pub message_id: MessageId,
    pub user_id: UserId,
    pub emote_id: EmoteId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct ReactionSummary {
    pub emote_id: EmoteId,
    pub count: u32,
    pub reacted_by_current_user: bool,
}

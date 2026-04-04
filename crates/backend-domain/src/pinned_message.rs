use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{ChannelId, MessageId, PinnedMessageId, ServerId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct PinnedMessage {
    pub id: PinnedMessageId,
    pub server_id: ServerId,
    pub channel_id: ChannelId,
    pub message_id: MessageId,
    pub pinned_by_user_id: UserId,
    pub content: String,
    pub author_user_id: UserId,
}

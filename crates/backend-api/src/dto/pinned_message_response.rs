use backend_domain::{ChannelId, MessageId, PinnedMessage, PinnedMessageId, ServerId, UserId};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct PinnedMessageResponse {
    pub id: PinnedMessageId,
    pub server_id: ServerId,
    pub channel_id: ChannelId,
    pub message_id: MessageId,
    pub pinned_by_user_id: UserId,
    pub content: String,
    pub author_user_id: UserId,
}

impl From<PinnedMessage> for PinnedMessageResponse {
    fn from(value: PinnedMessage) -> Self {
        Self {
            id: value.id,
            server_id: value.server_id,
            channel_id: value.channel_id,
            message_id: value.message_id,
            pinned_by_user_id: value.pinned_by_user_id,
            content: value.content,
            author_user_id: value.author_user_id,
        }
    }
}

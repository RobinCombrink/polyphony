use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{ChannelId, MessageId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct Message {
    pub id: MessageId,
    pub channel_id: ChannelId,
    pub author_user_id: UserId,
    pub content: String,
}

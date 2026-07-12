use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{ChannelId, MessageId, UserId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct MessageCommon {
    pub id: MessageId,
    pub channel_id: ChannelId,
    pub author_user_id: UserId,
    pub content: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct RegularMessage {
    pub common: MessageCommon,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct MentionedMessage {
    pub common: MessageCommon,
    pub mentioned_user_id: UserId,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(tag = "type", content = "details", rename_all = "snake_case")]
pub enum Message {
    Regular(RegularMessage),
    Mentioned(MentionedMessage),
}

impl Message {
    pub fn new_regular(
        id: MessageId,
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
    ) -> Self {
        Self::Regular(RegularMessage {
            common: MessageCommon {
                id,
                channel_id,
                author_user_id,
                content,
            },
        })
    }

    pub fn new_mentioned(
        id: MessageId,
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
        mentioned_user_id: UserId,
    ) -> Self {
        Self::Mentioned(MentionedMessage {
            common: MessageCommon {
                id,
                channel_id,
                author_user_id,
                content,
            },
            mentioned_user_id,
        })
    }

    pub fn id(&self) -> MessageId {
        match self {
            Self::Regular(message) => message.common.id,
            Self::Mentioned(message) => message.common.id,
        }
    }

    pub fn channel_id(&self) -> ChannelId {
        match self {
            Self::Regular(message) => message.common.channel_id,
            Self::Mentioned(message) => message.common.channel_id,
        }
    }

    pub fn author_user_id(&self) -> UserId {
        match self {
            Self::Regular(message) => message.common.author_user_id,
            Self::Mentioned(message) => message.common.author_user_id,
        }
    }

    pub fn content(&self) -> &str {
        match self {
            Self::Regular(message) => message.common.content.as_str(),
            Self::Mentioned(message) => message.common.content.as_str(),
        }
    }

    pub fn mentioned_user_id(&self) -> Option<UserId> {
        match self {
            Self::Regular(_) => None,
            Self::Mentioned(message) => Some(message.mentioned_user_id),
        }
    }

    pub fn is_mentioned(&self) -> bool {
        match self {
            Self::Mentioned(_) => true,
            Self::Regular(_) => false,
        }
    }

    pub fn with_content(self, content: String) -> Self {
        match self {
            Self::Regular(mut message) => {
                message.common.content = content;
                Self::Regular(message)
            }
            Self::Mentioned(mut message) => {
                message.common.content = content;
                Self::Mentioned(message)
            }
        }
    }
}

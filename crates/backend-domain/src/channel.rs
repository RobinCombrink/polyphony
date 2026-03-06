use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

use crate::{ChannelId, ServerId};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum ChannelType {
    Text,
    Voice,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(tag = "channel_type", rename_all = "snake_case")]
pub enum Channel {
    Text {
        id: ChannelId,
        server_id: ServerId,
        name: String,
    },
    Voice {
        id: ChannelId,
        server_id: ServerId,
        name: String,
    },
}

impl Channel {
    pub fn new_text(id: ChannelId, server_id: ServerId, name: String) -> Self {
        Self::Text {
            id,
            server_id,
            name,
        }
    }

    pub fn new_voice(id: ChannelId, server_id: ServerId, name: String) -> Self {
        Self::Voice {
            id,
            server_id,
            name,
        }
    }

    pub fn id(&self) -> ChannelId {
        match self {
            Self::Text { id, .. } => *id,
            Self::Voice { id, .. } => *id,
        }
    }

    pub fn server_id(&self) -> ServerId {
        match self {
            Self::Text { server_id, .. } => *server_id,
            Self::Voice { server_id, .. } => *server_id,
        }
    }

    pub fn name(&self) -> &str {
        match self {
            Self::Text { name, .. } => name,
            Self::Voice { name, .. } => name,
        }
    }

    pub fn kind(&self) -> ChannelType {
        match self {
            Self::Text { .. } => ChannelType::Text,
            Self::Voice { .. } => ChannelType::Voice,
        }
    }
}

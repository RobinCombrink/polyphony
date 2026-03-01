use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

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
        id: Uuid,
        server_id: Uuid,
        name: String,
    },
    Voice {
        id: Uuid,
        server_id: Uuid,
        name: String,
    },
}

impl Channel {
    pub fn new_text(id: Uuid, server_id: Uuid, name: String) -> Self {
        Self::Text {
            id,
            server_id,
            name,
        }
    }

    pub fn new_voice(id: Uuid, server_id: Uuid, name: String) -> Self {
        Self::Voice {
            id,
            server_id,
            name,
        }
    }

    pub fn id(&self) -> Uuid {
        match self {
            Self::Text { id, .. } => *id,
            Self::Voice { id, .. } => *id,
        }
    }

    pub fn server_id(&self) -> Uuid {
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

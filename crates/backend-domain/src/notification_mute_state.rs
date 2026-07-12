use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum NotificationMuteState {
    Unmuted,
    Muted,
}

impl NotificationMuteState {
    pub fn is_muted(self) -> bool {
        match self {
            Self::Muted => true,
            Self::Unmuted => false,
        }
    }

    pub fn from_muted_flag(muted: bool) -> Self {
        if muted { Self::Muted } else { Self::Unmuted }
    }
}

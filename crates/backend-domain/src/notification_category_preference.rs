use std::fmt::{Display, Formatter};
use std::str::FromStr;

use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
#[serde(rename_all = "snake_case")]
pub enum NotificationCategoryPreference {
    AllMessages,
    #[default]
    OnlyMentions,
    None,
}

impl NotificationCategoryPreference {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::AllMessages => "all_messages",
            Self::OnlyMentions => "only_mentions",
            Self::None => "none",
        }
    }
}

impl Display for NotificationCategoryPreference {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ParseNotificationCategoryPreferenceError;

impl FromStr for NotificationCategoryPreference {
    type Err = ParseNotificationCategoryPreferenceError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.trim().to_ascii_lowercase().as_str() {
            "all_messages" => Ok(Self::AllMessages),
            "only_mentions" => Ok(Self::OnlyMentions),
            "none" => Ok(Self::None),
            _ => Err(ParseNotificationCategoryPreferenceError),
        }
    }
}

use std::fmt::{Display, Formatter};
use std::str::FromStr;

use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotificationEventType {
    MessageCreated,
}

impl NotificationEventType {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::MessageCreated => "message_created",
        }
    }
}

impl Display for NotificationEventType {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.write_str(self.as_str())
    }
}

impl From<NotificationEventType> for String {
    fn from(value: NotificationEventType) -> Self {
        value.to_string()
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ParseNotificationEventTypeError;

impl FromStr for NotificationEventType {
    type Err = ParseNotificationEventTypeError;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.trim().to_ascii_lowercase().as_str() {
            "message_created" => Ok(Self::MessageCreated),
            _ => Err(ParseNotificationEventTypeError),
        }
    }
}

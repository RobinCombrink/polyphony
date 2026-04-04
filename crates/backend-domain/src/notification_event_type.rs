use serde::{Deserialize, Serialize};
use strum::{AsRefStr, Display, EnumString};

#[derive(
    Clone,
    Copy,
    Debug,
    PartialEq,
    Eq,
    Serialize,
    Deserialize,
    EnumString,
    Display,
    AsRefStr,
    sqlx::Type,
)]
#[serde(rename_all = "snake_case")]
#[strum(serialize_all = "snake_case")]
#[sqlx(type_name = "notification_event_type", rename_all = "snake_case")]
pub enum NotificationEventType {
    UnreadMessage,
    Mentioned,
}

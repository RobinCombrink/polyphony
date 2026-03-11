use serde::{Deserialize, Serialize};
use strum::{AsRefStr, Display, EnumString};

#[derive(
    Debug,
    Clone,
    Copy,
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
#[sqlx(
    type_name = "friend_notification_event_type",
    rename_all = "snake_case"
)]
pub enum FriendNotificationEventType {
    FriendRequestReceived,
    FriendRequestAccepted,
}

use serde::{Deserialize, Serialize};
use strum::{AsRefStr, Display, EnumString};
use utoipa::ToSchema;

#[derive(
    Clone,
    Copy,
    Debug,
    Default,
    PartialEq,
    Eq,
    Serialize,
    Deserialize,
    ToSchema,
    EnumString,
    Display,
    AsRefStr,
    sqlx::Type,
)]
#[serde(rename_all = "snake_case")]
#[strum(serialize_all = "snake_case")]
#[sqlx(
    type_name = "notification_category_preference",
    rename_all = "snake_case"
)]
pub enum NotificationCategoryPreference {
    AllMessages,
    #[default]
    OnlyMentions,
    None,
}

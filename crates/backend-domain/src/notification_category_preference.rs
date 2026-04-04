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

impl NotificationCategoryPreference {
    pub fn effective_for_channel(
        global: Self,
        global_channel_default: Self,
        server: Option<Self>,
        channel: Option<Self>,
    ) -> Self {
        let scoped = channel.or(server).unwrap_or(global_channel_default);

        match (global, scoped) {
            (Self::None, _) => Self::None,
            (Self::OnlyMentions, Self::AllMessages) => Self::OnlyMentions,
            _ => scoped,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    type Pref = NotificationCategoryPreference;

    #[test]
    fn channel_override_takes_priority() {
        assert_eq!(
            Pref::effective_for_channel(
                Pref::AllMessages,
                Pref::OnlyMentions,
                Some(Pref::AllMessages),
                Some(Pref::None),
            ),
            Pref::None,
        );
    }

    #[test]
    fn server_override_when_no_channel() {
        assert_eq!(
            Pref::effective_for_channel(
                Pref::AllMessages,
                Pref::OnlyMentions,
                Some(Pref::AllMessages),
                None,
            ),
            Pref::AllMessages,
        );
    }

    #[test]
    fn falls_back_to_global_channel_default() {
        assert_eq!(
            Pref::effective_for_channel(Pref::AllMessages, Pref::OnlyMentions, None, None,),
            Pref::OnlyMentions,
        );
    }

    #[test]
    fn global_none_silences_everything() {
        assert_eq!(
            Pref::effective_for_channel(
                Pref::None,
                Pref::AllMessages,
                Some(Pref::AllMessages),
                Some(Pref::AllMessages),
            ),
            Pref::None,
        );
    }

    #[test]
    fn global_only_mentions_caps_all_messages() {
        assert_eq!(
            Pref::effective_for_channel(Pref::OnlyMentions, Pref::AllMessages, None, None,),
            Pref::OnlyMentions,
        );
    }

    #[test]
    fn global_only_mentions_allows_only_mentions_through() {
        assert_eq!(
            Pref::effective_for_channel(Pref::OnlyMentions, Pref::OnlyMentions, None, None,),
            Pref::OnlyMentions,
        );
    }

    #[test]
    fn global_only_mentions_allows_none_through() {
        assert_eq!(
            Pref::effective_for_channel(Pref::OnlyMentions, Pref::None, None, None,),
            Pref::None,
        );
    }

    #[test]
    fn global_all_messages_passes_through() {
        assert_eq!(
            Pref::effective_for_channel(Pref::AllMessages, Pref::AllMessages, None, None,),
            Pref::AllMessages,
        );
    }
}

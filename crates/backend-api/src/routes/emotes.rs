use axum::{Json, http::StatusCode, response::IntoResponse};
use backend_domain::EmoteId;

use crate::dto::EmoteResponse;

const EMOTE_CATALOG: &[(&str, &str)] = &[
    ("thumbsup", "\u{1F44D}"),
    ("thumbsdown", "\u{1F44E}"),
    ("heart", "\u{2764}\u{FE0F}"),
    ("laugh", "\u{1F602}"),
    ("smile", "\u{1F642}"),
    ("grin", "\u{1F601}"),
    ("wink", "\u{1F609}"),
    ("cry", "\u{1F622}"),
    ("sob", "\u{1F62D}"),
    ("angry", "\u{1F620}"),
    ("fire", "\u{1F525}"),
    ("rocket", "\u{1F680}"),
    ("tada", "\u{1F389}"),
    ("clap", "\u{1F44F}"),
    ("wave", "\u{1F44B}"),
    ("thinking", "\u{1F914}"),
    ("eyes", "\u{1F440}"),
    ("100", "\u{1F4AF}"),
    ("check", "\u{2705}"),
    ("x", "\u{274C}"),
    ("star", "\u{2B50}"),
    ("sparkles", "\u{2728}"),
    ("party", "\u{1F973}"),
    ("sunglasses", "\u{1F60E}"),
    ("skull", "\u{1F480}"),
    ("pray", "\u{1F64F}"),
    ("muscle", "\u{1F4AA}"),
    ("pizza", "\u{1F355}"),
    ("coffee", "\u{2615}"),
    ("beer", "\u{1F37A}"),
];

#[utoipa::path(
    get,
    path = "/api/v1/emotes",
    responses(
        (status = 200, description = "Global emote catalog", body = Vec<EmoteResponse>)
    ),
    tag = "Emotes"
)]
pub(crate) async fn list_emotes() -> impl IntoResponse {
    let emotes: Vec<EmoteResponse> = EMOTE_CATALOG
        .iter()
        .map(|(id, emoji)| EmoteResponse {
            id: EmoteId::from(*id),
            shortcode: format!(":{id}:"),
            emoji_char: (*emoji).to_owned(),
        })
        .collect();

    (StatusCode::OK, Json(emotes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn catalog_has_expected_emotes() {
        assert!(!EMOTE_CATALOG.is_empty());
        assert!(EMOTE_CATALOG.iter().any(|(id, _)| *id == "thumbsup"));
        assert!(EMOTE_CATALOG.iter().any(|(id, _)| *id == "heart"));
    }

    #[test]
    fn emote_response_has_correct_shortcode_format() {
        let (id, emoji) = EMOTE_CATALOG[0];
        let response = EmoteResponse {
            id: EmoteId::from(id),
            shortcode: format!(":{id}:"),
            emoji_char: emoji.to_owned(),
        };
        assert_eq!(response.shortcode, ":thumbsup:");
        assert_eq!(response.emoji_char, "\u{1F44D}");
    }
}

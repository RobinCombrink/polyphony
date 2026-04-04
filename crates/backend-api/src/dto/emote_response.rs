use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct EmoteResponse {
    pub id: String,
    pub shortcode: String,
    pub emoji_char: String,
}

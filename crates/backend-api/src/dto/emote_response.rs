use backend_domain::EmoteId;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct EmoteResponse {
    pub id: EmoteId,
    pub shortcode: String,
    pub emoji_char: String,
}

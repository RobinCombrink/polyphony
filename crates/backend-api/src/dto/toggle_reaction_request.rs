use backend_domain::EmoteId;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct ToggleReactionRequest {
    pub emote_id: EmoteId,
}

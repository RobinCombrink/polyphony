use backend_domain::{EmoteId, ReactionSummary};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct ReactionSummaryResponse {
    pub emote_id: EmoteId,
    pub count: u32,
    pub reacted_by_current_user: bool,
}

impl From<ReactionSummary> for ReactionSummaryResponse {
    fn from(value: ReactionSummary) -> Self {
        Self {
            emote_id: value.emote_id,
            count: value.count,
            reacted_by_current_user: value.reacted_by_current_user,
        }
    }
}

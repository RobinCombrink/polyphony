use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct LiveRoomParticipantsResponse {
    pub channel_id: String,
    pub participant_subjects: Vec<String>,
}

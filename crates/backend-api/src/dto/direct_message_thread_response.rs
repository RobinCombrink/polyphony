use backend_domain::{DirectMessageThread, DirectMessageThreadId, UserId};
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct DirectMessageThreadResponse {
    pub id: DirectMessageThreadId,
    pub participant_a_user_id: UserId,
    pub participant_b_user_id: UserId,
}

impl From<DirectMessageThread> for DirectMessageThreadResponse {
    fn from(value: DirectMessageThread) -> Self {
        Self {
            id: value.id,
            participant_a_user_id: value.participant_a_user_id,
            participant_b_user_id: value.participant_b_user_id,
        }
    }
}

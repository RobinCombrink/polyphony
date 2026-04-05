use backend_domain::{DirectMessage, DirectMessageId, DirectMessageThreadId, UserId};
use serde::Serialize;
use utoipa::ToSchema;

#[derive(Debug, Serialize, ToSchema)]
pub struct DirectMessageResponse {
    pub id: DirectMessageId,
    pub thread_id: DirectMessageThreadId,
    pub author_user_id: UserId,
    pub content: String,
}

impl From<DirectMessage> for DirectMessageResponse {
    fn from(value: DirectMessage) -> Self {
        Self {
            id: value.id,
            thread_id: value.thread_id,
            author_user_id: value.author_user_id,
            content: value.content,
        }
    }
}

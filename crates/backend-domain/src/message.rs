use serde::{Deserialize, Serialize};
use utoipa::ToSchema;
use uuid::Uuid;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct Message {
    pub id: Uuid,
    pub channel_id: Uuid,
    pub author_subject: String,
    pub content: String,
}

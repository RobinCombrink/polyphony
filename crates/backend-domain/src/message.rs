use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct Message {
    pub id: String,
    pub channel_id: String,
    pub author_subject: String,
    pub content: String,
}
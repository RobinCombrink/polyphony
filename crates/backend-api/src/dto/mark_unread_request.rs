use backend_domain::MessageId;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, Serialize, Deserialize, ToSchema)]
pub struct MarkUnreadRequest {
    pub message_id: MessageId,
}

use backend_domain::ChannelType;
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct CreateSessionRequest {
    pub session_type: ChannelType,
    pub participant_instance_id: Option<String>,
}

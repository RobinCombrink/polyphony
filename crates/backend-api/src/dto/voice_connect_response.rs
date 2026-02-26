use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct VoiceConnectResponse {
    pub livekit_url: String,
    pub access_token: String,
    pub channel_id: String,
    pub participant_subject: String,
}

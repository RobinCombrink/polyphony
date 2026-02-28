use serde::Deserialize;
use utoipa::ToSchema;

#[derive(Debug, Deserialize, ToSchema)]
pub struct SetVoiceSessionMuteRequest {
    pub is_muted: bool,
}

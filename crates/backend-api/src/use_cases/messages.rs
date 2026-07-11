use axum::{http::StatusCode, response::IntoResponse};
use backend_domain::{ChannelId, ServerId, UserId};
use backend_storage::{ChannelRepository, CreateMessageResult, MessageRepository, ServerRepository};

use super::guards::{MembershipGateError, require_channel_membership};

pub(crate) enum CreateMessageError {
    Gate(MembershipGateError),
    InfraError,
}

impl IntoResponse for CreateMessageError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::Gate(gate_error) => gate_error.into_response(),
            Self::InfraError => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }
}

pub(crate) struct CreateMessageContext {
    pub(crate) server_id: ServerId,
    pub(crate) server_name: String,
    pub(crate) channel_name: String,
}

pub(crate) struct CreateMessageOutcome {
    pub(crate) result: CreateMessageResult,
    pub(crate) context: CreateMessageContext,
}

pub(crate) async fn create_message(
    channel_repo: &impl ChannelRepository,
    server_repo: &impl ServerRepository,
    message_repo: &impl MessageRepository,
    channel_id: ChannelId,
    user_id: UserId,
    content: String,
    mentioned_user_id: Option<UserId>,
) -> Result<CreateMessageOutcome, CreateMessageError> {
    let channel = match channel_repo.find_channel_by_id(channel_id).await {
        Ok(Some(channel)) => channel,
        Ok(None) => return Err(CreateMessageError::Gate(MembershipGateError::NotFound)),
        Err(_) => return Err(CreateMessageError::InfraError),
    };

    require_channel_membership(channel_repo, channel_id, user_id)
        .await
        .map_err(CreateMessageError::Gate)?;

    let server_name = match server_repo.list_servers_for_user(user_id).await {
        Ok(servers) => match servers.into_iter().find(|s| s.id == channel.server_id()) {
            Some(server) => server.name,
            None => return Err(CreateMessageError::Gate(MembershipGateError::NotFound)),
        },
        Err(_) => return Err(CreateMessageError::InfraError),
    };

    let result = message_repo
        .create_message(channel_id, user_id, content, mentioned_user_id)
        .await
        .map_err(|_| CreateMessageError::InfraError)?;

    Ok(CreateMessageOutcome {
        context: CreateMessageContext {
            server_id: channel.server_id(),
            server_name,
            channel_name: channel.name().to_owned(),
        },
        result,
    })
}

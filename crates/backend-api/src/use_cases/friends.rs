use axum::{Json, http::StatusCode, response::IntoResponse};
use backend_domain::{ServerId, UserId};
use backend_storage::{FriendRepository, SendFriendRequestResult, ServerRepository};

use crate::dto::ApiErrorResponse;

use super::guards::{MembershipGateError, require_server_membership};

pub(crate) enum ServerContextFriendRequestError {
    ServerNotFound,
    NotSharedServer,
    InfraError,
}

impl IntoResponse for ServerContextFriendRequestError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::ServerNotFound => (
                StatusCode::NOT_FOUND,
                Json(ApiErrorResponse::new("NOT_FOUND", "server was not found")),
            )
                .into_response(),
            Self::NotSharedServer => (
                StatusCode::FORBIDDEN,
                Json(ApiErrorResponse::new(
                    "FORBIDDEN",
                    "friend request is denied because users do not share this server",
                )),
            )
                .into_response(),
            Self::InfraError => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }
}

pub(crate) async fn send_friend_request_from_server_context(
    server_repo: &impl ServerRepository,
    friend_repo: &impl FriendRepository,
    server_id: ServerId,
    requester_user_id: UserId,
    addressee_user_id: UserId,
) -> Result<SendFriendRequestResult, ServerContextFriendRequestError> {
    let requester_is_member =
        match require_server_membership(server_repo, server_id, requester_user_id).await {
            Ok(()) => true,
            Err(MembershipGateError::NotMember) => false,
            Err(MembershipGateError::NotFound | MembershipGateError::InfraError) => {
                return Err(ServerContextFriendRequestError::ServerNotFound);
            }
        };

    let addressee_is_member =
        match require_server_membership(server_repo, server_id, addressee_user_id).await {
            Ok(()) => true,
            Err(MembershipGateError::NotMember) => false,
            Err(MembershipGateError::NotFound | MembershipGateError::InfraError) => {
                return Err(ServerContextFriendRequestError::ServerNotFound);
            }
        };

    if !requester_is_member || !addressee_is_member {
        return Err(ServerContextFriendRequestError::NotSharedServer);
    }

    friend_repo
        .send_friend_request(requester_user_id, addressee_user_id)
        .await
        .map_err(|_| ServerContextFriendRequestError::InfraError)
}

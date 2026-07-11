use axum::{http::StatusCode, response::IntoResponse};
use backend_domain::{Membership, ServerId, UserId};
use backend_storage::{FriendRepository, MutationResult, ServerRepository};

pub(crate) enum InviteFriendError {
    NotFriends,
    NotFound,
    Forbidden,
    InfraError,
}

impl IntoResponse for InviteFriendError {
    fn into_response(self) -> axum::response::Response {
        match self {
            Self::NotFriends | Self::Forbidden => StatusCode::FORBIDDEN.into_response(),
            Self::NotFound => StatusCode::NOT_FOUND.into_response(),
            Self::InfraError => StatusCode::INTERNAL_SERVER_ERROR.into_response(),
        }
    }
}

pub(crate) async fn invite_friend_to_server(
    server_repo: &impl ServerRepository,
    friend_repo: &impl FriendRepository,
    server_id: ServerId,
    inviter_user_id: UserId,
    friend_user_id: UserId,
) -> Result<Membership, InviteFriendError> {
    let are_friends = friend_repo
        .are_friends(inviter_user_id, friend_user_id)
        .await
        .map_err(|_| InviteFriendError::InfraError)?;

    if !are_friends {
        return Err(InviteFriendError::NotFriends);
    }

    let mutation_result = server_repo
        .add_server_member(server_id, inviter_user_id, friend_user_id)
        .await
        .map_err(|_| InviteFriendError::InfraError)?;

    match mutation_result {
        MutationResult::Updated => Ok(Membership {
            user_id: friend_user_id,
            server_id,
        }),
        MutationResult::Forbidden => Err(InviteFriendError::Forbidden),
        MutationResult::NotFound => Err(InviteFriendError::NotFound),
        MutationResult::Deleted => Err(InviteFriendError::InfraError),
    }
}

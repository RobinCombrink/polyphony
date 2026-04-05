use backend_domain::{Membership, ServerId, UserId};
use backend_storage::{FriendRepository, MutationResult, ServerRepository};

pub(crate) enum InviteFriendError {
    NotFriends,
    NotFound,
    Forbidden,
    InfraError,
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

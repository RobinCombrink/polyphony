use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, MessageId};
use backend_storage::{
    ChannelRepository, MessageRepository, ReactionRepository, ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{ReactionSummaryResponse, ToggleReactionRequest},
    response_mapping::ToggleReactionResponse,
};

#[utoipa::path(
    post,
    path = "/api/v1/channels/{channel_id}/messages/{message_id}/reactions",
    request_body = ToggleReactionRequest,
    responses(
        (status = 200, description = "Reaction toggled (added or removed)"),
        (status = 404, description = "Message not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("channel_id" = ChannelId, Path, description = "Channel id"),
        ("message_id" = MessageId, Path, description = "Message id"),
    ),
    tag = "Reactions"
)]
pub(crate) async fn toggle_reaction<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((_channel_id, message_id)): Path<(ChannelId, MessageId)>,
    Json(request): Json<ToggleReactionRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + ReactionRepository,
    Verifier: TokenVerifier,
{
    let Ok(result) = state
        .message_repository
        .toggle_reaction(message_id, authenticated_user.user_id, &request.emote_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    ToggleReactionResponse(result).into_response()
}

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/messages/{message_id}/reactions",
    responses(
        (status = 200, description = "Reaction summaries", body = Vec<ReactionSummaryResponse>),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("channel_id" = ChannelId, Path, description = "Channel id"),
        ("message_id" = MessageId, Path, description = "Message id"),
    ),
    tag = "Reactions"
)]
pub(crate) async fn list_reactions<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((_channel_id, message_id)): Path<(ChannelId, MessageId)>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + ReactionRepository,
    Verifier: TokenVerifier,
{
    let Ok(summaries_raw) = state
        .message_repository
        .list_reaction_summaries(message_id, authenticated_user.user_id)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    let summaries: Vec<ReactionSummaryResponse> = summaries_raw
        .into_iter()
        .map(ReactionSummaryResponse::from)
        .collect();

    (StatusCode::OK, Json(summaries)).into_response()
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use backend_domain::{ChannelType, EmoteId};
    use backend_storage::{
        ChannelRepository, InMemoryRepository, MessageRepository, ReactionRepository,
        ServerRepository, ToggleReactionResult, UserRepository,
    };

    fn create_repo() -> Arc<InMemoryRepository> {
        Arc::new(InMemoryRepository::new())
    }

    #[tokio::test]
    async fn toggle_adds_reaction_to_existing_message() {
        let repo = create_repo();

        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await
            .unwrap();
        let server = repo.create_server("test".into(), user.id).await.unwrap();
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap()
            .unwrap();
        let result = repo
            .create_message(channel.id(), user.id, "hello".into(), None)
            .await
            .unwrap();
        let message_id = match result {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        let toggle = repo
            .toggle_reaction(message_id, user.id, &EmoteId::from("thumbsup"))
            .await
            .unwrap();
        assert!(matches!(toggle, ToggleReactionResult::Added));

        let summaries = repo
            .list_reaction_summaries(message_id, user.id)
            .await
            .unwrap();
        assert_eq!(summaries.len(), 1);
        assert_eq!(summaries[0].emote_id.as_ref(), "thumbsup");
        assert_eq!(summaries[0].count, 1);
        assert!(summaries[0].reacted_by_current_user);
    }

    #[tokio::test]
    async fn toggle_removes_existing_reaction() {
        let repo = create_repo();

        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await
            .unwrap();
        let server = repo.create_server("test".into(), user.id).await.unwrap();
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap()
            .unwrap();
        let result = repo
            .create_message(channel.id(), user.id, "hello".into(), None)
            .await
            .unwrap();
        let message_id = match result {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        repo.toggle_reaction(message_id, user.id, &EmoteId::from("thumbsup"))
            .await
            .unwrap();
        let toggle = repo
            .toggle_reaction(message_id, user.id, &EmoteId::from("thumbsup"))
            .await
            .unwrap();
        assert!(matches!(toggle, ToggleReactionResult::Removed));

        let summaries = repo
            .list_reaction_summaries(message_id, user.id)
            .await
            .unwrap();
        assert!(summaries.is_empty());
    }

    #[tokio::test]
    async fn toggle_returns_not_found_for_missing_message() {
        let repo = create_repo();
        let fake_message_id = backend_domain::MessageId::from(uuid::Uuid::new_v4());
        let fake_user_id = backend_domain::UserId::from(uuid::Uuid::new_v4());

        let toggle = repo
            .toggle_reaction(fake_message_id, fake_user_id, &EmoteId::from("thumbsup"))
            .await
            .unwrap();
        assert!(matches!(toggle, ToggleReactionResult::MessageNotFound));
    }

    #[tokio::test]
    async fn list_summaries_aggregates_multiple_users() {
        let repo = create_repo();

        let user1 = repo
            .get_or_create_user_by_external_reference(&"user-1".into())
            .await
            .unwrap();
        let user2 = repo
            .get_or_create_user_by_external_reference(&"user-2".into())
            .await
            .unwrap();
        let server = repo.create_server("test".into(), user1.id).await.unwrap();
        repo.add_server_member(server.id, user1.id, user2.id)
            .await
            .unwrap();
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap()
            .unwrap();
        let result = repo
            .create_message(channel.id(), user1.id, "hello".into(), None)
            .await
            .unwrap();
        let message_id = match result {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        repo.toggle_reaction(message_id, user1.id, &EmoteId::from("thumbsup"))
            .await
            .unwrap();
        repo.toggle_reaction(message_id, user2.id, &EmoteId::from("thumbsup"))
            .await
            .unwrap();

        let summaries = repo
            .list_reaction_summaries(message_id, user1.id)
            .await
            .unwrap();
        assert_eq!(summaries.len(), 1);
        assert_eq!(summaries[0].emote_id.as_ref(), "thumbsup");
        assert_eq!(summaries[0].count, 2);
        assert!(summaries[0].reacted_by_current_user);

        let summaries_user2 = repo
            .list_reaction_summaries(message_id, user2.id)
            .await
            .unwrap();
        assert!(summaries_user2[0].reacted_by_current_user);
    }
}

use axum::{
    Json,
    extract::{Path, Query, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::{ChannelId, Message};
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};
use serde::Deserialize;

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
};

#[derive(Debug, Deserialize, utoipa::IntoParams)]
pub(crate) struct SearchMessagesQuery {
    q: Option<String>,
}

#[utoipa::path(
    get,
    path = "/api/v1/channels/{channel_id}/messages/search",
    responses(
        (status = 200, description = "Search results returned", body = [Message]),
        (status = 403, description = "User is not a member of the channel server"),
        (status = 404, description = "Channel not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("channel_id" = ChannelId, Path, description = "Channel id"),
        SearchMessagesQuery,
    ),
    tag = "Messages"
)]
pub(crate) async fn search_messages<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(channel_id): Path<ChannelId>,
    Query(query): Query<SearchMessagesQuery>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let is_channel_member = match state
        .channel_repository
        .is_channel_member(channel_id, authenticated_user.user_id)
        .await
    {
        Ok(Some(value)) => value,
        Ok(None) => return StatusCode::NOT_FOUND.into_response(),
        Err(_) => return StatusCode::INTERNAL_SERVER_ERROR.into_response(),
    };

    if !is_channel_member {
        return StatusCode::FORBIDDEN.into_response();
    }

    let query_text = query.q.unwrap_or_default();
    let Ok(messages) = state
        .message_repository
        .search_messages(channel_id, &query_text)
        .await
    else {
        return StatusCode::INTERNAL_SERVER_ERROR.into_response();
    };

    (StatusCode::OK, Json(messages)).into_response()
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use backend_domain::ChannelType;
    use backend_storage::{
        ChannelRepository, CreateMessageResult, InMemoryRepository, MessageRepository,
        ServerRepository, UserRepository,
    };

    fn create_repo() -> Arc<InMemoryRepository> {
        Arc::new(InMemoryRepository::new())
    }

    async fn seed_channel(
        repo: &InMemoryRepository,
    ) -> (backend_domain::UserId, backend_domain::ChannelId) {
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
        (user.id, channel.id())
    }

    async fn post(
        repo: &InMemoryRepository,
        channel_id: backend_domain::ChannelId,
        user_id: backend_domain::UserId,
        content: &str,
    ) {
        let result = repo
            .create_message(channel_id, user_id, content.into(), None)
            .await
            .unwrap();
        assert!(matches!(result, CreateMessageResult::Created { .. }));
    }

    #[tokio::test]
    async fn search_returns_matching_messages() {
        let repo = create_repo();
        let (user_id, channel_id) = seed_channel(&repo).await;
        post(&repo, channel_id, user_id, "hello world").await;
        post(&repo, channel_id, user_id, "foo bar").await;
        post(&repo, channel_id, user_id, "hello again").await;

        let results = repo.search_messages(channel_id, "hello").await.unwrap();
        assert_eq!(results.len(), 2);
    }

    #[tokio::test]
    async fn search_is_case_insensitive() {
        let repo = create_repo();
        let (user_id, channel_id) = seed_channel(&repo).await;
        post(&repo, channel_id, user_id, "Hello World").await;

        let results = repo.search_messages(channel_id, "hello").await.unwrap();
        assert_eq!(results.len(), 1);
    }

    #[tokio::test]
    async fn search_returns_empty_when_no_match() {
        let repo = create_repo();
        let (user_id, channel_id) = seed_channel(&repo).await;
        post(&repo, channel_id, user_id, "hello world").await;

        let results = repo.search_messages(channel_id, "xyz").await.unwrap();
        assert!(results.is_empty());
    }

    #[tokio::test]
    async fn search_with_empty_query_returns_all_messages() {
        let repo = create_repo();
        let (user_id, channel_id) = seed_channel(&repo).await;
        post(&repo, channel_id, user_id, "first").await;
        post(&repo, channel_id, user_id, "second").await;

        let results = repo.search_messages(channel_id, "").await.unwrap();
        assert_eq!(results.len(), 2);
    }
}

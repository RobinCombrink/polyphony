use axum::{
    Json,
    extract::{Path, State},
    http::StatusCode,
    response::IntoResponse,
};
use backend_domain::ServerId;
use backend_storage::{
    ChannelRepository, MessageRepository, PinMessageResult, PinnedMessageRepository,
    ServerRepository, UserRepository,
};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
    dto::{PinMessageRequest, PinnedMessageResponse},
};

#[utoipa::path(
    post,
    path = "/api/v1/servers/{server_id}/pins",
    request_body = PinMessageRequest,
    responses(
        (status = 200, description = "Message pinned"),
        (status = 404, description = "Message not found"),
        (status = 409, description = "Message already pinned"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("server_id" = ServerId, Path, description = "Server id"),
    ),
    tag = "Pinned Messages"
)]
pub(crate) async fn pin_message<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
    Json(request): Json<PinMessageRequest>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + PinnedMessageRepository,
    Verifier: TokenVerifier,
{
    let user = state
        .user_repository
        .find_user_by_external_reference(&authenticated_user.external_reference)
        .await;

    let Some(user) = user else {
        return StatusCode::UNAUTHORIZED.into_response();
    };

    match state
        .message_repository
        .pin_message(server_id, request.message_id, user.id)
        .await
    {
        PinMessageResult::Pinned => StatusCode::OK.into_response(),
        PinMessageResult::AlreadyPinned => StatusCode::CONFLICT.into_response(),
        PinMessageResult::MessageNotFound => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    delete,
    path = "/api/v1/servers/{server_id}/pins/{message_id}",
    responses(
        (status = 200, description = "Message unpinned"),
        (status = 404, description = "Pin not found"),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("server_id" = ServerId, Path, description = "Server id"),
        ("message_id" = backend_domain::MessageId, Path, description = "Message id"),
    ),
    tag = "Pinned Messages"
)]
pub(crate) async fn unpin_message<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path((server_id, message_id)): Path<(ServerId, backend_domain::MessageId)>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + PinnedMessageRepository,
    Verifier: TokenVerifier,
{
    let user = state
        .user_repository
        .find_user_by_external_reference(&authenticated_user.external_reference)
        .await;

    let Some(_user) = user else {
        return StatusCode::UNAUTHORIZED.into_response();
    };

    match state
        .message_repository
        .unpin_message(server_id, message_id)
        .await
    {
        backend_storage::UnpinMessageResult::Unpinned => StatusCode::OK.into_response(),
        backend_storage::UnpinMessageResult::NotPinned => StatusCode::NOT_FOUND.into_response(),
    }
}

#[utoipa::path(
    get,
    path = "/api/v1/servers/{server_id}/pins",
    responses(
        (status = 200, description = "Pinned messages", body = Vec<PinnedMessageResponse>),
        (status = 401, description = "Authentication failed")
    ),
    security(("bearer_auth" = [])),
    params(
        ("server_id" = ServerId, Path, description = "Server id"),
    ),
    tag = "Pinned Messages"
)]
pub(crate) async fn list_pinned_messages<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
    Path(server_id): Path<ServerId>,
) -> impl IntoResponse
where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository + PinnedMessageRepository,
    Verifier: TokenVerifier,
{
    let user = state
        .user_repository
        .find_user_by_external_reference(&authenticated_user.external_reference)
        .await;

    let Some(_user) = user else {
        return StatusCode::UNAUTHORIZED.into_response();
    };

    let pinned: Vec<PinnedMessageResponse> = state
        .message_repository
        .list_pinned_messages(server_id)
        .await
        .into_iter()
        .map(PinnedMessageResponse::from)
        .collect();

    (StatusCode::OK, Json(pinned)).into_response()
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use backend_domain::ChannelType;
    use backend_storage::{
        ChannelRepository, InMemoryRepository, MessageRepository, PinMessageResult,
        PinnedMessageRepository, ServerRepository, UserRepository,
    };

    fn create_repo() -> Arc<InMemoryRepository> {
        Arc::new(InMemoryRepository::new())
    }

    #[tokio::test]
    async fn pin_adds_message_to_server_pins() {
        let repo = create_repo();
        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await;
        let server = repo.create_server("test".into(), user.id).await;
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap();
        let message_id = match repo
            .create_message(channel.id(), user.id, "important".into(), None)
            .await
        {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        let result = repo.pin_message(server.id, message_id, user.id).await;
        assert!(matches!(result, PinMessageResult::Pinned));

        let pins = repo.list_pinned_messages(server.id).await;
        assert_eq!(pins.len(), 1);
        assert_eq!(pins[0].message_id, message_id);
        assert_eq!(pins[0].content, "important");
        assert_eq!(pins[0].channel_id, channel.id());
    }

    #[tokio::test]
    async fn pin_same_message_twice_returns_already_pinned() {
        let repo = create_repo();
        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await;
        let server = repo.create_server("test".into(), user.id).await;
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap();
        let message_id = match repo
            .create_message(channel.id(), user.id, "important".into(), None)
            .await
        {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        repo.pin_message(server.id, message_id, user.id).await;
        let result = repo.pin_message(server.id, message_id, user.id).await;
        assert!(matches!(result, PinMessageResult::AlreadyPinned));
    }

    #[tokio::test]
    async fn pin_nonexistent_message_returns_not_found() {
        let repo = create_repo();
        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await;
        let server = repo.create_server("test".into(), user.id).await;
        let fake_message_id = backend_domain::MessageId::from(uuid::Uuid::new_v4());

        let result = repo.pin_message(server.id, fake_message_id, user.id).await;
        assert!(matches!(result, PinMessageResult::MessageNotFound));
    }

    #[tokio::test]
    async fn unpin_removes_pinned_message() {
        let repo = create_repo();
        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await;
        let server = repo.create_server("test".into(), user.id).await;
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap();
        let message_id = match repo
            .create_message(channel.id(), user.id, "important".into(), None)
            .await
        {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        repo.pin_message(server.id, message_id, user.id).await;
        let result = repo.unpin_message(server.id, message_id).await;
        assert!(matches!(
            result,
            backend_storage::UnpinMessageResult::Unpinned
        ));

        let pins = repo.list_pinned_messages(server.id).await;
        assert!(pins.is_empty());
    }

    #[tokio::test]
    async fn unpin_not_pinned_message_returns_not_pinned() {
        let repo = create_repo();
        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await;
        let server = repo.create_server("test".into(), user.id).await;
        let fake_message_id = backend_domain::MessageId::from(uuid::Uuid::new_v4());

        let result = repo.unpin_message(server.id, fake_message_id).await;
        assert!(matches!(
            result,
            backend_storage::UnpinMessageResult::NotPinned
        ));
    }

    #[tokio::test]
    async fn list_pinned_includes_channel_context() {
        let repo = create_repo();
        let user = repo
            .get_or_create_user_by_external_reference(&"test-user".into())
            .await;
        let server = repo.create_server("test".into(), user.id).await;
        let channel = repo
            .create_channel(server.id, "general".into(), ChannelType::Text)
            .await
            .unwrap();
        let message_id = match repo
            .create_message(channel.id(), user.id, "pinned content".into(), None)
            .await
        {
            backend_storage::CreateMessageResult::Created { message, .. } => message.id(),
            _ => panic!("Expected Created"),
        };

        repo.pin_message(server.id, message_id, user.id).await;

        let pins = repo.list_pinned_messages(server.id).await;
        assert_eq!(pins.len(), 1);
        assert_eq!(pins[0].channel_id, channel.id());
        assert_eq!(pins[0].author_user_id, user.id);
        assert_eq!(pins[0].content, "pinned content");
    }
}

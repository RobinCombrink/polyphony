#![allow(dead_code)]

use std::sync::Arc;

use async_trait::async_trait;
use axum::{
    body::Body,
    http::{Request, header},
};
use backend_api::{
    ApiState,
    auth::{Auth0Config, AuthState, AuthenticatedUser, TokenVerifier},
    config::LiveKitConfig,
    notification_hub::NotificationHub,
    storage::{InMemoryRepository, PostgresRepository},
};
use backend_storage::NotificationRepository;
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};
use serde_json::Value;
use testcontainers_modules::{
    postgres::Postgres,
    testcontainers::{ContainerAsync, runners::AsyncRunner},
};
use tower::ServiceExt;
use uuid::Uuid;

pub(crate) use backend_api::domain::{ChannelId, ExternalReference, MessageId, ServerId, UserId};

#[derive(Debug)]
pub(crate) struct PostgresTestEnv {
    _container: ContainerAsync<Postgres>,
    repository: Arc<PostgresRepository>,
}

static FEATURE_POSTGRES_TEST_ENV: tokio::sync::Mutex<Option<Arc<PostgresTestEnv>>> =
    tokio::sync::Mutex::const_new(None);

#[derive(Debug)]
pub(crate) enum TestStore {
    InMemory(Arc<InMemoryRepository>),
    Postgres(Arc<PostgresTestEnv>),
}

pub(crate) type SharedTestStore = Arc<TestStore>;

pub(crate) fn default_shared_store() -> SharedTestStore {
    Arc::new(TestStore::InMemory(Arc::new(InMemoryRepository::new())))
}

fn external_reference_for_actor(name: &str) -> ExternalReference {
    ExternalReference::from(format!("auth0|{}-{}", name.to_lowercase(), Uuid::new_v4()))
}

#[derive(Debug, Clone)]
pub(crate) struct Actor {
    pub(crate) name: String,
    pub(crate) token: String,
    pub(crate) external_reference: ExternalReference,
    pub(crate) user_id: UserId,
    pub(crate) app: axum::Router,
}

#[derive(Debug, Clone, Copy, Eq, PartialEq)]
enum TestStoreMode {
    InMemory,
    Postgres,
}

impl TestStoreMode {
    fn from_environment() -> Self {
        let mode = std::env::var("BDD_STORE")
            .unwrap_or_else(|_| "in-memory".to_owned())
            .to_lowercase();

        match mode.as_str() {
            "postgres" | "sql" | "postgresql" => Self::Postgres,
            _ => Self::InMemory,
        }
    }
}

pub(crate) fn payload_uuid(payload: &Value, key: &str) -> Uuid {
    Uuid::parse_str(payload[key].as_str().expect("uuid field to be present"))
        .expect("payload uuid to be valid")
}

pub(crate) fn payload_user_id(payload: &Value, key: &str) -> UserId {
    payload_uuid(payload, key).into()
}

pub(crate) fn payload_server_id(payload: &Value, key: &str) -> ServerId {
    payload_uuid(payload, key).into()
}

pub(crate) fn payload_channel_id(payload: &Value, key: &str) -> ChannelId {
    payload_uuid(payload, key).into()
}

pub(crate) fn payload_message_id(payload: &Value, key: &str) -> MessageId {
    payload_uuid(payload, key).into()
}

struct TestTokenVerifier {
    expected_token: String,
    user_id: UserId,
    external_reference: ExternalReference,
}

#[async_trait]
impl TokenVerifier for TestTokenVerifier {
    async fn verify(
        &self,
        bearer_token: &str,
    ) -> Result<AuthenticatedUser, backend_api::auth::AuthError> {
        if bearer_token == self.expected_token {
            return Ok(AuthenticatedUser {
                user_id: self.user_id,
                external_reference: self.external_reference.clone(),
            });
        }

        Err(backend_api::auth::AuthError::NonBearerAuthorization)
    }
}

pub(crate) async fn create_server(
    app: &axum::Router,
    server_name: &str,
) -> axum::response::Response {
    create_server_with_token(app, server_name, "valid-token").await
}

pub(crate) async fn create_server_with_token(
    app: &axum::Router,
    server_name: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/servers")
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "name": server_name }).to_string(),
                ))
                .expect("create server request to be valid"),
        )
        .await
        .expect("create server response from app")
}

pub(crate) async fn create_channel(
    app: &axum::Router,
    server_id: &ServerId,
    channel_name: &str,
) -> axum::response::Response {
    create_channel_with_token(app, server_id, channel_name, "text", "valid-token").await
}

pub(crate) async fn create_voice_channel(
    app: &axum::Router,
    server_id: &ServerId,
    channel_name: &str,
) -> axum::response::Response {
    create_channel_with_token(app, server_id, channel_name, "voice", "valid-token").await
}

pub(crate) async fn create_channel_with_token(
    app: &axum::Router,
    server_id: &ServerId,
    channel_name: &str,
    channel_type: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/servers/{server_id}/channels"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "name": channel_name, "channel_type": channel_type })
                        .to_string(),
                ))
                .expect("create channel request to be valid"),
        )
        .await
        .expect("create channel response from app")
}

pub(crate) async fn delete_channel(
    app: &axum::Router,
    channel_id: &ChannelId,
) -> axum::response::Response {
    delete_channel_with_token(app, channel_id, "valid-token").await
}

pub(crate) async fn update_channel(
    app: &axum::Router,
    channel_id: &ChannelId,
    channel_name: &str,
) -> axum::response::Response {
    update_channel_with_token(app, channel_id, channel_name, "valid-token").await
}

pub(crate) async fn update_channel_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    channel_name: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}"))
                .method("PATCH")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "name": channel_name }).to_string(),
                ))
                .expect("update channel request to be valid"),
        )
        .await
        .expect("update channel response from app")
}

pub(crate) async fn delete_channel_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}"))
                .method("DELETE")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("delete channel request to be valid"),
        )
        .await
        .expect("delete channel response from app")
}

pub(crate) async fn add_server_member(
    app: &axum::Router,
    server_id: &ServerId,
    user_id: &UserId,
) -> axum::response::Response {
    add_server_member_with_token(app, server_id, user_id, "valid-token").await
}

pub(crate) async fn add_server_member_with_token(
    app: &axum::Router,
    server_id: &ServerId,
    user_id: &UserId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/servers/{server_id}/members"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "user_id": user_id }).to_string(),
                ))
                .expect("add server member request to be valid"),
        )
        .await
        .expect("add server member response from app")
}

pub(crate) async fn delete_server(
    app: &axum::Router,
    server_id: &ServerId,
) -> axum::response::Response {
    delete_server_with_token(app, server_id, "valid-token").await
}

pub(crate) async fn delete_server_with_token(
    app: &axum::Router,
    server_id: &ServerId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/servers/{server_id}"))
                .method("DELETE")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("delete server request to be valid"),
        )
        .await
        .expect("delete server response from app")
}

pub(crate) async fn create_message(
    app: &axum::Router,
    channel_id: &ChannelId,
    content: &str,
) -> axum::response::Response {
    create_message_with_token(app, channel_id, content, "valid-token").await
}

pub(crate) async fn create_message_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    content: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/messages"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "content": content }).to_string(),
                ))
                .expect("create message request to be valid"),
        )
        .await
        .expect("create message response from app")
}

pub(crate) async fn update_message(
    app: &axum::Router,
    channel_id: &ChannelId,
    message_id: &MessageId,
    content: &str,
) -> axum::response::Response {
    update_message_with_token(app, channel_id, message_id, content, "valid-token").await
}

pub(crate) async fn update_message_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    message_id: &MessageId,
    content: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/channels/{channel_id}/messages/{message_id}"
                ))
                .method("PATCH")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "content": content }).to_string(),
                ))
                .expect("update message request to be valid"),
        )
        .await
        .expect("update message response from app")
}

pub(crate) async fn delete_message(
    app: &axum::Router,
    channel_id: &ChannelId,
    message_id: &MessageId,
) -> axum::response::Response {
    delete_message_with_token(app, channel_id, message_id, "valid-token").await
}

pub(crate) async fn delete_message_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    message_id: &MessageId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/channels/{channel_id}/messages/{message_id}"
                ))
                .method("DELETE")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("delete message request to be valid"),
        )
        .await
        .expect("delete message response from app")
}

pub(crate) async fn list_messages(
    app: &axum::Router,
    channel_id: &ChannelId,
) -> axum::response::Response {
    list_messages_with_token(app, channel_id, "valid-token").await
}

pub(crate) async fn list_messages_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/messages"))
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("list messages request to be valid"),
        )
        .await
        .expect("list messages response from app")
}

pub(crate) async fn list_servers(app: &axum::Router) -> axum::response::Response {
    list_servers_with_token(app, "valid-token").await
}

pub(crate) async fn list_servers_with_token(
    app: &axum::Router,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/servers")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("list servers request to be valid"),
        )
        .await
        .expect("list servers response from app")
}

pub(crate) async fn list_channels(
    app: &axum::Router,
    server_id: &ServerId,
) -> axum::response::Response {
    list_channels_with_token(app, server_id, "valid-token").await
}

pub(crate) async fn list_channels_with_token(
    app: &axum::Router,
    server_id: &ServerId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/servers/{server_id}/channels"))
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("list channels request to be valid"),
        )
        .await
        .expect("list channels response from app")
}

pub(crate) async fn connect_voice_session(
    app: &axum::Router,
    channel_id: &ChannelId,
) -> axum::response::Response {
    connect_voice_session_with_token(app, channel_id, "valid-token").await
}

pub(crate) async fn connect_voice_session_with_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    bearer_token: &str,
) -> axum::response::Response {
    connect_channel_session_with_type_and_token(app, channel_id, "voice", bearer_token).await
}

pub(crate) async fn connect_channel_session_with_type(
    app: &axum::Router,
    channel_id: &ChannelId,
    session_type: &str,
) -> axum::response::Response {
    connect_channel_session_with_type_and_token(app, channel_id, session_type, "valid-token").await
}

pub(crate) async fn connect_channel_session_with_type_and_token(
    app: &axum::Router,
    channel_id: &ChannelId,
    session_type: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/session"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "session_type": session_type }).to_string(),
                ))
                .expect("connect voice session request to be valid"),
        )
        .await
        .expect("connect voice session response from app")
}

pub(crate) async fn get_me_with_token(
    app: &axum::Router,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("get me request to be valid"),
        )
        .await
        .expect("get me response from app")
}

pub(crate) async fn get_user_by_id_with_token(
    app: &axum::Router,
    user_id: &UserId,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/users/{user_id}"))
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("get user by id request to be valid"),
        )
        .await
        .expect("get user by id response from app")
}

pub(crate) async fn patch_me_display_name_with_token(
    app: &axum::Router,
    display_name: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .method("PATCH")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "display_name": display_name }).to_string(),
                ))
                .expect("patch me request to be valid"),
        )
        .await
        .expect("patch me response from app")
}

pub(crate) async fn response_payload_json(response: axum::response::Response) -> Value {
    serde_json::from_slice(
        &axum::body::to_bytes(response.into_body(), 1024 * 1024)
            .await
            .expect("response payload bytes"),
    )
    .expect("valid json payload")
}

fn seeded_state_with_store<Repo>(
    external_reference: &ExternalReference,
    token: &str,
    user_id: UserId,
    repository: Arc<Repo>,
    notification_hub: Arc<NotificationHub>,
) -> ApiState<Repo, Repo, Repo, Repo, TestTokenVerifier>
where
    Repo: UserRepository + ServerRepository + ChannelRepository + MessageRepository,
{
    let auth_config = Auth0Config::default();

    let token_verifier = Arc::new(TestTokenVerifier {
        expected_token: token.to_owned(),
        user_id,
        external_reference: external_reference.clone(),
    });

    let user_store = repository.clone();
    let server_store = repository.clone();
    let channel_store = repository.clone();
    let message_store = repository;

    let mut state = ApiState::new(
        Arc::new(AuthState::new(auth_config, token_verifier)),
        user_store,
        server_store,
        channel_store,
        message_store,
        Arc::new(LiveKitConfig::default()),
    );

    state.notification_hub = notification_hub;
    state
}

pub(crate) fn seeded_app_with_store_and_notification_hub(
    external_reference: impl AsRef<str>,
    token: &str,
    repository: SharedTestStore,
    notification_hub: Arc<NotificationHub>,
) -> axum::Router {
    let user_id: UserId = Uuid::new_v4().into();
    let external_reference = ExternalReference::from(external_reference.as_ref());

    match repository.as_ref() {
        TestStore::InMemory(store) => backend_api::build_app(seeded_state_with_store(
            &external_reference,
            token,
            user_id,
            Arc::clone(store),
            Arc::clone(&notification_hub),
        )),
        TestStore::Postgres(store) => backend_api::build_app(seeded_state_with_store(
            &external_reference,
            token,
            user_id,
            Arc::clone(&store.repository),
            Arc::clone(&notification_hub),
        )),
    }
}

pub(crate) fn seeded_app_with_store(
    external_reference: impl AsRef<str>,
    token: &str,
    repository: SharedTestStore,
) -> axum::Router {
    seeded_app_with_store_and_notification_hub(
        external_reference,
        token,
        repository,
        Arc::new(NotificationHub::default()),
    )
}

pub(crate) async fn create_actor_with_notification_hub(
    name: &str,
    token: &str,
    repository: SharedTestStore,
    notification_hub: Arc<NotificationHub>,
) -> Actor {
    let external_reference = external_reference_for_actor(name);
    let app = seeded_app_with_store_and_notification_hub(
        &external_reference,
        token,
        repository,
        notification_hub,
    );
    let me_payload = response_payload_json(get_me_with_token(&app, token).await).await;

    Actor {
        name: name.to_owned(),
        token: token.to_owned(),
        external_reference,
        user_id: payload_user_id(&me_payload, "user_id"),
        app,
    }
}

pub(crate) async fn create_actor(name: &str, token: &str, repository: SharedTestStore) -> Actor {
    let external_reference = external_reference_for_actor(name);
    let app = seeded_app_with_store(&external_reference, token, repository);
    let me_payload = response_payload_json(get_me_with_token(&app, token).await).await;

    Actor {
        name: name.to_owned(),
        token: token.to_owned(),
        external_reference,
        user_id: payload_user_id(&me_payload, "user_id"),
        app,
    }
}

pub(crate) async fn seeded_app(external_reference: &str, token: &str) -> axum::Router {
    seeded_app_with_store(external_reference, token, fresh_shared_store().await)
}

pub(crate) async fn fresh_shared_store() -> SharedTestStore {
    match TestStoreMode::from_environment() {
        TestStoreMode::InMemory => {
            Arc::new(TestStore::InMemory(Arc::new(InMemoryRepository::new())))
        }
        TestStoreMode::Postgres => Arc::new(TestStore::Postgres(feature_postgres_test_env().await)),
    }
}

pub(crate) async fn prime_feature_test_store() {
    if TestStoreMode::from_environment() == TestStoreMode::Postgres {
        let _ = feature_postgres_test_env().await;
    }
}

pub(crate) async fn shutdown_feature_test_store() {
    let mut guard = FEATURE_POSTGRES_TEST_ENV.lock().await;
    *guard = None;
}

pub(crate) async fn unread_count_for_channel(
    repository: &SharedTestStore,
    user_id: UserId,
    channel_id: ChannelId,
) -> u64 {
    match repository.as_ref() {
        TestStore::InMemory(store) => store.unread_count_for_channel(user_id, channel_id).await,
        TestStore::Postgres(store) => {
            store
                .repository
                .unread_count_for_channel(user_id, channel_id)
                .await
        }
    }
}

pub(crate) async fn outbox_count_for_message_recipient(
    repository: &SharedTestStore,
    message_id: MessageId,
    recipient_user_id: UserId,
) -> u64 {
    match repository.as_ref() {
        TestStore::InMemory(store) => {
            store
                .outbox_count_for_message_recipient(message_id, recipient_user_id)
                .await
        }
        TestStore::Postgres(store) => {
            store
                .repository
                .outbox_count_for_message_recipient(message_id, recipient_user_id)
                .await
        }
    }
}

pub(crate) async fn outbox_total_count_for_recipient(
    repository: &SharedTestStore,
    recipient_user_id: UserId,
) -> u64 {
    match repository.as_ref() {
        TestStore::InMemory(store) => {
            store
                .outbox_total_count_for_recipient(recipient_user_id)
                .await
        }
        TestStore::Postgres(store) => {
            store
                .repository
                .outbox_total_count_for_recipient(recipient_user_id)
                .await
        }
    }
}

async fn feature_postgres_test_env() -> Arc<PostgresTestEnv> {
    {
        let guard = FEATURE_POSTGRES_TEST_ENV.lock().await;
        if let Some(env) = guard.as_ref() {
            return Arc::clone(env);
        }
    }

    let env = Arc::new(postgres_test_env().await);
    let mut guard = FEATURE_POSTGRES_TEST_ENV.lock().await;
    match guard.as_ref() {
        Some(existing) => Arc::clone(existing),
        None => {
            *guard = Some(Arc::clone(&env));
            env
        }
    }
}

async fn postgres_test_env() -> PostgresTestEnv {
    const POLYPHONY: &str = "polyphony";
    const POSTGRES: &str = "postgres";
    let container = Postgres::default()
        .with_db_name(POLYPHONY)
        .with_user(POSTGRES)
        .with_password(POSTGRES)
        .start()
        .await
        .expect("postgres container to start");
    let host = container
        .get_host()
        .await
        .expect("postgres host")
        .to_string();
    let port = container
        .get_host_port_ipv4(5432)
        .await
        .expect("postgres mapped port");

    let repository = Arc::new(
        PostgresRepository::connect(&host, port, POLYPHONY, POSTGRES, POSTGRES, 5)
            .await
            .expect("postgres repository initialization to succeed"),
    );

    PostgresTestEnv {
        _container: container,
        repository,
    }
}

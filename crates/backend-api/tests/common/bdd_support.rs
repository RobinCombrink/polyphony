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
    storage::{
        ChannelRepository, InMemoryRepository, MessageRepository, ServerRepository, UserRepository,
        VoiceRepository,
    },
};
use serde_json::Value;
use tower::ServiceExt;
use url::Url;
use uuid::Uuid;

struct TestTokenVerifier {
    expected_token: String,
    external_reference: String,
}

#[async_trait]
impl TokenVerifier for TestTokenVerifier {
    async fn verify(
        &self,
        bearer_token: &str,
    ) -> Result<AuthenticatedUser, backend_api::auth::AuthError> {
        if bearer_token == self.expected_token {
            return Ok(AuthenticatedUser {
                user_id: Uuid::nil(),
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
    server_id: &str,
    channel_name: &str,
) -> axum::response::Response {
    create_channel_with_token(app, server_id, channel_name, "valid-token").await
}

pub(crate) async fn create_channel_with_token(
    app: &axum::Router,
    server_id: &str,
    channel_name: &str,
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
                    serde_json::json!({ "name": channel_name }).to_string(),
                ))
                .expect("create channel request to be valid"),
        )
        .await
        .expect("create channel response from app")
}

pub(crate) async fn delete_channel(
    app: &axum::Router,
    channel_id: &str,
) -> axum::response::Response {
    delete_channel_with_token(app, channel_id, "valid-token").await
}

pub(crate) async fn update_channel(
    app: &axum::Router,
    channel_id: &str,
    channel_name: &str,
) -> axum::response::Response {
    update_channel_with_token(app, channel_id, channel_name, "valid-token").await
}

pub(crate) async fn update_channel_with_token(
    app: &axum::Router,
    channel_id: &str,
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
    channel_id: &str,
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
    server_id: &str,
    user_id: &str,
) -> axum::response::Response {
    add_server_member_with_token(app, server_id, user_id, "valid-token").await
}

pub(crate) async fn add_server_member_with_token(
    app: &axum::Router,
    server_id: &str,
    user_id: &str,
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

pub(crate) async fn delete_server(app: &axum::Router, server_id: &str) -> axum::response::Response {
    delete_server_with_token(app, server_id, "valid-token").await
}

pub(crate) async fn delete_server_with_token(
    app: &axum::Router,
    server_id: &str,
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
    channel_id: &str,
    content: &str,
) -> axum::response::Response {
    create_message_with_token(app, channel_id, content, "valid-token").await
}

pub(crate) async fn create_message_with_token(
    app: &axum::Router,
    channel_id: &str,
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
    channel_id: &str,
    message_id: &str,
    content: &str,
) -> axum::response::Response {
    update_message_with_token(app, channel_id, message_id, content, "valid-token").await
}

pub(crate) async fn update_message_with_token(
    app: &axum::Router,
    channel_id: &str,
    message_id: &str,
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
    channel_id: &str,
    message_id: &str,
) -> axum::response::Response {
    delete_message_with_token(app, channel_id, message_id, "valid-token").await
}

pub(crate) async fn delete_message_with_token(
    app: &axum::Router,
    channel_id: &str,
    message_id: &str,
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
    channel_id: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/messages"))
                .header(header::AUTHORIZATION, "Bearer valid-token")
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

pub(crate) async fn list_channels(app: &axum::Router, server_id: &str) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/servers/{server_id}/channels"))
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .body(Body::empty())
                .expect("list channels request to be valid"),
        )
        .await
        .expect("list channels response from app")
}

pub(crate) async fn connect_voice_session(
    app: &axum::Router,
    channel_id: &str,
) -> axum::response::Response {
    connect_voice_session_with_token(app, channel_id, "valid-token").await
}

pub(crate) async fn connect_voice_session_with_token(
    app: &axum::Router,
    channel_id: &str,
    bearer_token: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/voice/connect"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {bearer_token}"))
                .body(Body::empty())
                .expect("connect voice session request to be valid"),
        )
        .await
        .expect("connect voice session response from app")
}

pub(crate) async fn list_voice_sessions(
    app: &axum::Router,
    channel_id: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/voice/sessions"))
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .body(Body::empty())
                .expect("list voice sessions request to be valid"),
        )
        .await
        .expect("list voice sessions response from app")
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
    user_id: &str,
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

pub(crate) fn seeded_state(external_reference: &str, token: &str) -> ApiState {
    seeded_state_with_store(
        external_reference,
        token,
        Arc::new(InMemoryRepository::new()),
    )
}

pub(crate) fn seeded_state_with_store(
    external_reference: &str,
    token: &str,
    repository: Arc<InMemoryRepository>,
) -> ApiState {
    let auth_config = Auth0Config {
        issuer: Url::parse("https://example-dev.us.auth0.com/").expect("valid issuer url"),
        audience: "polyphony-api".to_owned(),
        token_duration_hours: 18,
    };

    let token_verifier = Arc::new(TestTokenVerifier {
        expected_token: token.to_owned(),
        external_reference: external_reference.to_owned(),
    });

    let user_store: Arc<dyn UserRepository> = repository.clone();
    let server_store: Arc<dyn ServerRepository> = repository.clone();
    let channel_store: Arc<dyn ChannelRepository> = repository.clone();
    let voice_store: Arc<dyn VoiceRepository> = repository.clone();
    let message_store: Arc<dyn MessageRepository> = repository;

    ApiState {
        auth_state: Arc::new(AuthState::new(auth_config, token_verifier)),
        user_repository: user_store,
        server_repository: server_store,
        channel_repository: channel_store,
        voice_repository: voice_store,
        message_repository: message_store,
        livekit_config: Arc::new(LiveKitConfig::default()),
    }
}

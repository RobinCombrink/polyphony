mod entity_seeder;

use std::sync::Arc;

use async_trait::async_trait;
use axum::{
    body::Body,
    http::{Request, StatusCode, header},
};
use backend_api::{
    ApiState,
    auth::{Auth0Config, AuthState, AuthenticatedUser, TokenVerifier},
    build_app,
    storage::InMemoryChatRepository,
};
use entity_seeder::EntitySeeder;
use serde_json::Value;
use tower::ServiceExt;
use url::Url;

struct TestTokenVerifier {
    expected_token: String,
    subject: String,
}

#[async_trait]
impl TokenVerifier for TestTokenVerifier {
    async fn verify(
        &self,
        bearer_token: &str,
    ) -> Result<AuthenticatedUser, backend_api::auth::AuthError> {
        if bearer_token == self.expected_token {
            return Ok(AuthenticatedUser {
                subject: self.subject.clone(),
            });
        }

        Err(backend_api::auth::AuthError::NonBearerAuthorization)
    }
}

#[tokio::test]
async fn given_backend_started_when_health_requested_then_status_is_200() {
    let state = seeded_state("auth0|health-user", "health-token");
    let app = build_app(state);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .expect("health request to be valid"),
        )
        .await
        .expect("health response from app");

    assert_eq!(response.status(), StatusCode::OK);
}

#[tokio::test]
async fn given_seeded_user_when_authenticated_me_requested_then_subject_matches_seed() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let expected_subject = seeded_user.auth0_subject.clone();
    assert!(!seeded_user.display_name.is_empty());

    let state = seeded_state(&expected_subject, "valid-token");
    let app = build_app(state);

    let response = app
        .oneshot(
            Request::builder()
                .uri("/api/v1/me")
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .body(Body::empty())
                .expect("me request to be valid"),
        )
        .await
        .expect("me response from app");

    assert_eq!(response.status(), StatusCode::OK);

    let body = axum::body::to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("response body bytes");
    let payload: Value = serde_json::from_slice(&body).expect("valid json payload");

    assert_eq!(payload["user_id"].as_str(), Some(expected_subject.as_str()));
}

#[tokio::test]
async fn given_authenticated_user_when_create_server_then_created_status_and_server_id_returned() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let seeded_server = entity_seeder.server();

    let state = seeded_state(&seeded_user.auth0_subject, "valid-token");
    let app = build_app(state);

    let create_server_response = create_server(&app, &seeded_server.name).await;

    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    assert!(create_server_payload["id"].as_str().is_some());
}

#[tokio::test]
async fn given_existing_server_when_create_channel_then_created_status_and_channel_id_returned() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let seeded_server = entity_seeder.server();
    let seeded_channel = entity_seeder.channel(&seeded_server.id);

    let state = seeded_state(&seeded_user.auth0_subject, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &seeded_server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_response =
        create_channel(&app, &created_server_id, &seeded_channel.name).await;

    assert_eq!(create_channel_response.status(), StatusCode::CREATED);

    let create_channel_payload = response_payload_json(create_channel_response).await;
    assert_eq!(
        create_channel_payload["server_id"].as_str(),
        Some(created_server_id.as_str())
    );
    assert!(create_channel_payload["id"].as_str().is_some());
}

#[tokio::test]
async fn given_existing_channel_when_create_message_then_message_is_listed_for_channel() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let seeded_server = entity_seeder.server();
    let seeded_channel = entity_seeder.channel(&seeded_server.id);
    let seeded_message = entity_seeder.message(&seeded_channel.id, &seeded_user.auth0_subject);

    let state = seeded_state(&seeded_user.auth0_subject, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &seeded_server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_payload =
        response_payload_json(create_channel(&app, &created_server_id, &seeded_channel.name).await)
            .await;

    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let create_message_response =
        create_message(&app, &created_channel_id, &seeded_message.content).await;

    assert_eq!(create_message_response.status(), StatusCode::CREATED);

    let list_messages_response = app
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{created_channel_id}/messages"))
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .body(Body::empty())
                .expect("list messages request to be valid"),
        )
        .await
        .expect("list messages response from app");

    assert_eq!(list_messages_response.status(), StatusCode::OK);

    let list_messages_payload: Value = serde_json::from_slice(
        &axum::body::to_bytes(list_messages_response.into_body(), 1024 * 1024)
            .await
            .expect("list messages payload bytes"),
    )
    .expect("valid list messages json payload");

    let listed_messages = list_messages_payload
        .as_array()
        .expect("messages payload to be array");

    assert_eq!(listed_messages.len(), 1);
    assert_eq!(
        listed_messages[0]["content"].as_str(),
        Some(seeded_message.content.as_str())
    );
}

async fn create_server(app: &axum::Router, server_name: &str) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/servers")
                .method("POST")
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "name": server_name }).to_string(),
                ))
                .expect("create server request to be valid"),
        )
        .await
        .expect("create server response from app")
}

async fn create_channel(
    app: &axum::Router,
    server_id: &str,
    channel_name: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/servers/{server_id}/channels"))
                .method("POST")
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "name": channel_name }).to_string(),
                ))
                .expect("create channel request to be valid"),
        )
        .await
        .expect("create channel response from app")
}

async fn create_message(
    app: &axum::Router,
    channel_id: &str,
    content: &str,
) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/channels/{channel_id}/messages"))
                .method("POST")
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "content": content }).to_string(),
                ))
                .expect("create message request to be valid"),
        )
        .await
        .expect("create message response from app")
}

async fn response_payload_json(response: axum::response::Response) -> Value {
    serde_json::from_slice(
        &axum::body::to_bytes(response.into_body(), 1024 * 1024)
            .await
            .expect("response payload bytes"),
    )
    .expect("valid json payload")
}

fn seeded_state(subject: &str, token: &str) -> ApiState {
    let auth_config = Auth0Config {
        issuer: Url::parse("https://example-dev.us.auth0.com/").expect("valid issuer url"),
        audience: "polyphony-api".to_owned(),
        token_duration_hours: 18,
    };

    let token_verifier = Arc::new(TestTokenVerifier {
        expected_token: token.to_owned(),
        subject: subject.to_owned(),
    });

    ApiState {
        auth_state: Arc::new(AuthState::new(auth_config, token_verifier)),
        store: Arc::new(InMemoryChatRepository::new()),
    }
}

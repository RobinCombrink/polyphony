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
    storage::{ChatRepository, InMemoryChatRepository},
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
async fn given_existing_server_when_list_servers_then_seeded_server_is_in_response() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let seeded_server = entity_seeder.server();

    let state = seeded_state(&seeded_user.auth0_subject, "valid-token");
    let app = build_app(state);

    let create_server_response = create_server(&app, &seeded_server.name).await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let list_servers_response = list_servers(&app).await;
    assert_eq!(list_servers_response.status(), StatusCode::OK);

    let list_servers_payload = response_payload_json(list_servers_response).await;
    let listed_servers = list_servers_payload
        .as_array()
        .expect("server list payload to be array");

    assert_eq!(listed_servers.len(), 1);
    assert_eq!(
        listed_servers[0]["name"].as_str(),
        Some(seeded_server.name.as_str())
    );
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

#[tokio::test]
async fn given_existing_message_when_update_message_then_updated_content_is_listed() {
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

    let create_channel_payload =
        response_payload_json(create_channel(&app, &created_server_id, &seeded_channel.name).await)
            .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let create_message_payload =
        response_payload_json(create_message(&app, &created_channel_id, "original message").await)
            .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let update_response = update_message(
        &app,
        &created_channel_id,
        &created_message_id,
        "updated message",
    )
    .await;

    assert_eq!(update_response.status(), StatusCode::OK);

    let list_messages_payload =
        response_payload_json(list_messages(&app, &created_channel_id).await).await;

    let listed_messages = list_messages_payload
        .as_array()
        .expect("messages payload to be array");

    assert_eq!(listed_messages.len(), 1);
    assert_eq!(
        listed_messages[0]["content"].as_str(),
        Some("updated message")
    );
}

#[tokio::test]
async fn given_existing_message_when_delete_message_then_message_is_removed_from_list() {
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

    let create_channel_payload =
        response_payload_json(create_channel(&app, &created_server_id, &seeded_channel.name).await)
            .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let create_message_payload =
        response_payload_json(create_message(&app, &created_channel_id, "to be deleted").await)
            .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let delete_response = delete_message(&app, &created_channel_id, &created_message_id).await;
    assert_eq!(delete_response.status(), StatusCode::NO_CONTENT);

    let list_messages_payload =
        response_payload_json(list_messages(&app, &created_channel_id).await).await;

    let listed_messages = list_messages_payload
        .as_array()
        .expect("messages payload to be array");

    assert_eq!(listed_messages.len(), 0);
}

#[tokio::test]
async fn given_message_owned_by_another_user_when_update_message_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let seeded_server = entity_seeder.server();
    let seeded_channel = entity_seeder.channel(&seeded_server.id);

    let owner_subject = "auth0|owner-user";
    let other_subject = "auth0|other-user";
    let shared_store: Arc<dyn ChatRepository> = Arc::new(InMemoryChatRepository::new());

    let owner_app = build_app(seeded_state_with_store(
        owner_subject,
        "owner-token",
        Arc::clone(&shared_store),
    ));

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &seeded_server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &created_server_id,
            &seeded_channel.name,
            "owner-token",
        )
        .await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let create_message_payload = response_payload_json(
        create_message_with_token(
            &owner_app,
            &created_channel_id,
            "message by owner",
            "owner-token",
        )
        .await,
    )
    .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let other_user_app = build_app(seeded_state_with_store(
        other_subject,
        "other-token",
        shared_store,
    ));

    let update_response = update_message_with_token(
        &other_user_app,
        &created_channel_id,
        &created_message_id,
        "attempted edit",
        "other-token",
    )
    .await;

    assert_eq!(update_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_message_owned_by_another_user_when_delete_message_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let seeded_server = entity_seeder.server();
    let seeded_channel = entity_seeder.channel(&seeded_server.id);

    let owner_subject = "auth0|owner-user";
    let other_subject = "auth0|other-user";
    let shared_store: Arc<dyn ChatRepository> = Arc::new(InMemoryChatRepository::new());

    let owner_app = build_app(seeded_state_with_store(
        owner_subject,
        "owner-token",
        Arc::clone(&shared_store),
    ));

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &seeded_server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &created_server_id,
            &seeded_channel.name,
            "owner-token",
        )
        .await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let create_message_payload = response_payload_json(
        create_message_with_token(
            &owner_app,
            &created_channel_id,
            "message by owner",
            "owner-token",
        )
        .await,
    )
    .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let other_user_app = build_app(seeded_state_with_store(
        other_subject,
        "other-token",
        shared_store,
    ));

    let delete_response = delete_message_with_token(
        &other_user_app,
        &created_channel_id,
        &created_message_id,
        "other-token",
    )
    .await;

    assert_eq!(delete_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_existing_channel_when_list_channels_then_seeded_channel_is_in_response() {
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

    let list_channels_response = list_channels(&app, &created_server_id).await;
    assert_eq!(list_channels_response.status(), StatusCode::OK);

    let list_channels_payload = response_payload_json(list_channels_response).await;
    let listed_channels = list_channels_payload
        .as_array()
        .expect("channel list payload to be array");

    assert_eq!(listed_channels.len(), 1);
    assert_eq!(
        listed_channels[0]["name"].as_str(),
        Some(seeded_channel.name.as_str())
    );
}

async fn create_server(app: &axum::Router, server_name: &str) -> axum::response::Response {
    create_server_with_token(app, server_name, "valid-token").await
}

async fn create_server_with_token(
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

async fn create_channel(
    app: &axum::Router,
    server_id: &str,
    channel_name: &str,
) -> axum::response::Response {
    create_channel_with_token(app, server_id, channel_name, "valid-token").await
}

async fn create_channel_with_token(
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

async fn create_message(
    app: &axum::Router,
    channel_id: &str,
    content: &str,
) -> axum::response::Response {
    create_message_with_token(app, channel_id, content, "valid-token").await
}

async fn create_message_with_token(
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

async fn update_message(
    app: &axum::Router,
    channel_id: &str,
    message_id: &str,
    content: &str,
) -> axum::response::Response {
    update_message_with_token(app, channel_id, message_id, content, "valid-token").await
}

async fn update_message_with_token(
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

async fn delete_message(
    app: &axum::Router,
    channel_id: &str,
    message_id: &str,
) -> axum::response::Response {
    delete_message_with_token(app, channel_id, message_id, "valid-token").await
}

async fn delete_message_with_token(
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

async fn list_messages(app: &axum::Router, channel_id: &str) -> axum::response::Response {
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

async fn list_servers(app: &axum::Router) -> axum::response::Response {
    app.clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/servers")
                .header(header::AUTHORIZATION, "Bearer valid-token")
                .body(Body::empty())
                .expect("list servers request to be valid"),
        )
        .await
        .expect("list servers response from app")
}

async fn list_channels(app: &axum::Router, server_id: &str) -> axum::response::Response {
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

async fn response_payload_json(response: axum::response::Response) -> Value {
    serde_json::from_slice(
        &axum::body::to_bytes(response.into_body(), 1024 * 1024)
            .await
            .expect("response payload bytes"),
    )
    .expect("valid json payload")
}

fn seeded_state(subject: &str, token: &str) -> ApiState {
    seeded_state_with_store(subject, token, Arc::new(InMemoryChatRepository::new()))
}

fn seeded_state_with_store(subject: &str, token: &str, store: Arc<dyn ChatRepository>) -> ApiState {
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
        store,
    }
}

mod common;

use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use common::bdd_support::{
    SharedTestStore, default_shared_store, fresh_shared_store, get_me_with_token,
    prime_feature_test_store, response_payload_json, seeded_app_with_store,
    shutdown_feature_test_store,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use tower::ServiceExt;

const FEATURE_PATH: &str = "../../features/auth_and_health.feature";
const VALID_TOKEN: &str = "valid-token";
const EXTERNAL_REFERENCE: &str = "auth0|health-identity-user";

#[derive(Debug, cucumber::World)]
struct AuthAndHealthWorld {
    app: axum::Router,
    shared_store: SharedTestStore,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
}

impl Default for AuthAndHealthWorld {
    fn default() -> Self {
        Self {
            app: axum::Router::new(),
            shared_store: default_shared_store(),
            latest_status: None,
            latest_payload: None,
        }
    }
}

impl AuthAndHealthWorld {
    fn app_ref(&self) -> &axum::Router {
        &self.app
    }

    fn latest_status(&self) -> StatusCode {
        self.latest_status.expect("latest status to be set")
    }

    fn latest_payload_ref(&self) -> &Value {
        self.latest_payload
            .as_ref()
            .expect("latest payload to be set")
    }
}

#[given("the backend service is running")]
async fn the_backend_service_is_running(world: &mut AuthAndHealthWorld) {
    let shared = fresh_shared_store().await;
    world.app = seeded_app_with_store(EXTERNAL_REFERENCE, VALID_TOKEN, shared.clone());
    world.shared_store = shared;
    world.latest_status = None;
    world.latest_payload = None;
}

#[when("I check service health")]
async fn i_check_service_health(world: &mut AuthAndHealthWorld) {
    let response = world
        .app_ref()
        .clone()
        .oneshot(
            Request::builder()
                .uri("/health")
                .body(Body::empty())
                .expect("health request to be valid"),
        )
        .await
        .expect("health response from app");

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[then("the service is reported as healthy")]
async fn the_service_is_reported_as_healthy(world: &mut AuthAndHealthWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
    assert_eq!(world.latest_payload_ref()["status"].as_str(), Some("ok"));
}

#[then("the service identity is visible")]
async fn the_service_identity_is_visible(world: &mut AuthAndHealthWorld) {
    assert_eq!(
        world.latest_payload_ref()["service"].as_str(),
        Some("backend-api")
    );
}

#[given("an authenticated user exists")]
async fn an_authenticated_user_exists(world: &mut AuthAndHealthWorld) {
    let shared = fresh_shared_store().await;
    world.app = seeded_app_with_store(EXTERNAL_REFERENCE, VALID_TOKEN, shared.clone());
    world.shared_store = shared;
    world.latest_status = None;
    world.latest_payload = None;
}

#[when("the user views their own identity")]
async fn the_user_views_their_own_identity(world: &mut AuthAndHealthWorld) {
    let response = get_me_with_token(world.app_ref(), VALID_TOKEN).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[then("identity details are returned")]
async fn identity_details_are_returned(world: &mut AuthAndHealthWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
    assert!(world.latest_payload_ref()["user_id"].as_str().is_some());
}

#[then("the identity includes the user's external reference")]
async fn the_identity_includes_the_users_external_reference(world: &mut AuthAndHealthWorld) {
    assert_eq!(
        world.latest_payload_ref()["external_reference"].as_str(),
        Some(EXTERNAL_REFERENCE)
    );
}

#[then("the identity has no display name yet")]
async fn the_identity_has_no_display_name_yet(world: &mut AuthAndHealthWorld) {
    assert!(world.latest_payload_ref()["display_name"].is_null());
}

#[tokio::test]
async fn auth_and_health_feature() {
    prime_feature_test_store().await;
    AuthAndHealthWorld::cucumber()
        .run_and_exit(FEATURE_PATH)
        .await;
    shutdown_feature_test_store().await;
}

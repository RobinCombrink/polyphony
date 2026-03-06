mod common;

use std::sync::LazyLock;

use axum::http::StatusCode;
use common::bdd_support::{
    SharedTestStore, UserId, default_shared_store, fresh_shared_store, get_me_with_token,
    get_user_by_id_with_token, patch_me_display_name_with_token, payload_user_id,
    prime_feature_test_store, response_payload_json, seeded_app_with_store,
    shutdown_feature_test_store,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use uuid::Uuid;

const VALID_TOKEN: &str = "valid-token";
const INVALID_TOKEN: &str = "wrong-token";
const EXTERNAL_REFERENCE: &str = "auth0|bdd-user";
const UPDATED_DISPLAY_NAME: &str = "Polyphony User";
static MISSING_USER_ID: LazyLock<UserId> = LazyLock::new(|| Uuid::new_v4().into());

#[derive(Debug, cucumber::World)]
struct IdentityWorld {
    app: axum::Router,
    shared_store: SharedTestStore,
    user_id: Option<UserId>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
}

impl Default for IdentityWorld {
    fn default() -> Self {
        Self {
            app: axum::Router::new(),
            shared_store: default_shared_store(),
            user_id: None,
            latest_status: None,
            latest_payload: None,
        }
    }
}

impl IdentityWorld {
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

    fn user_id_ref(&self) -> &UserId {
        self.user_id.as_ref().expect("user id to be set")
    }
}

#[given("an authenticated user exists")]
async fn an_authenticated_user_exists(world: &mut IdentityWorld) {
    let shared = fresh_shared_store().await;
    world.app = seeded_app_with_store(EXTERNAL_REFERENCE, VALID_TOKEN, shared.clone());
    world.shared_store = shared;
    world.user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
}

#[when("I update my display name")]
async fn i_update_my_display_name(world: &mut IdentityWorld) {
    let response =
        patch_me_display_name_with_token(world.app_ref(), UPDATED_DISPLAY_NAME, VALID_TOKEN).await;

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[then("the update succeeds")]
async fn the_update_succeeds(world: &mut IdentityWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
}

#[then("the returned profile includes the updated display name")]
async fn the_returned_profile_includes_the_updated_display_name(world: &mut IdentityWorld) {
    assert_eq!(
        world.latest_payload_ref()["display_name"].as_str(),
        Some(UPDATED_DISPLAY_NAME)
    );
}

#[then("viewing my identity again includes the updated display name")]
async fn viewing_my_identity_again_includes_the_updated_display_name(world: &mut IdentityWorld) {
    let response = get_me_with_token(world.app_ref(), VALID_TOKEN).await;
    let status = response.status();
    let payload = response_payload_json(response).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(payload["display_name"].as_str(), Some(UPDATED_DISPLAY_NAME));
}

#[given("the authenticated user has an updated display name")]
async fn the_authenticated_user_has_an_updated_display_name(world: &mut IdentityWorld) {
    let response =
        patch_me_display_name_with_token(world.app_ref(), UPDATED_DISPLAY_NAME, VALID_TOKEN).await;
    assert_eq!(response.status(), StatusCode::OK);

    let me_response = get_me_with_token(world.app_ref(), VALID_TOKEN).await;
    assert_eq!(me_response.status(), StatusCode::OK);

    let me_payload = response_payload_json(me_response).await;
    world.user_id = Some(payload_user_id(&me_payload, "user_id"));
}

#[when("I look up that user by id")]
async fn i_look_up_that_user_by_id(world: &mut IdentityWorld) {
    let response =
        get_user_by_id_with_token(world.app_ref(), world.user_id_ref(), VALID_TOKEN).await;

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[then("the lookup succeeds")]
async fn the_lookup_succeeds(world: &mut IdentityWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
}

#[then("the result includes the user id and display name")]
async fn the_result_includes_the_user_id_and_display_name(world: &mut IdentityWorld) {
    let payload = world.latest_payload_ref();
    let response_user_id = payload_user_id(payload, "id");

    assert_eq!(response_user_id, *world.user_id_ref());
    assert_eq!(payload["display_name"].as_str(), Some(UPDATED_DISPLAY_NAME));
}

#[when("I look up a user id that does not exist")]
async fn i_look_up_a_user_id_that_does_not_exist(world: &mut IdentityWorld) {
    let response = get_user_by_id_with_token(world.app_ref(), &MISSING_USER_ID, VALID_TOKEN).await;

    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[then("the user is reported as not found")]
async fn the_user_is_reported_as_not_found(world: &mut IdentityWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[when("identity lookup is attempted without valid authentication")]
async fn identity_lookup_is_attempted_without_valid_authentication(world: &mut IdentityWorld) {
    let response =
        get_user_by_id_with_token(world.app_ref(), &MISSING_USER_ID, INVALID_TOKEN).await;

    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[then("identity lookup access is denied")]
async fn identity_lookup_access_is_denied(world: &mut IdentityWorld) {
    assert_eq!(world.latest_status(), StatusCode::UNAUTHORIZED);
}

#[tokio::test]
async fn identity_and_users_feature() {
    prime_feature_test_store().await;
    IdentityWorld::cucumber()
        .run_and_exit("../../features/identity_and_users.feature")
        .await;
    shutdown_feature_test_store().await;
}

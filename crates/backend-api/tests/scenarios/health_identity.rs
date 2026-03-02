use axum::{
    body::Body,
    http::{Request, StatusCode},
};
use backend_api::build_app;
use serde_json::Value;
use tower::ServiceExt;
use uuid::Uuid;

#[path = "../common.rs"]
mod common;

use common::{
    bdd_support::{
        get_me_with_token, get_user_by_id_with_token, patch_me_display_name_with_token,
        seeded_state,
    },
    entity_seeder::EntitySeeder,
};

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
async fn given_seeded_user_when_authenticated_me_requested_then_identity_matches_seed() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let expected_subject = seeded_user.external_reference.clone();

    let state = seeded_state(&expected_subject, "valid-token");
    let app = build_app(state);

    let response = get_me_with_token(&app, "valid-token").await;

    assert_eq!(response.status(), StatusCode::OK);

    let body = axum::body::to_bytes(response.into_body(), 1024 * 1024)
        .await
        .expect("response body bytes");
    let payload: Value = serde_json::from_slice(&body).expect("valid json payload");

    assert!(Uuid::parse_str(payload["user_id"].as_str().expect("user id string")).is_ok());
    assert_eq!(
        payload["external_reference"].as_str(),
        Some(expected_subject.as_str())
    );
    assert!(payload["display_name"].is_null());
}

#[tokio::test]
async fn given_authenticated_user_when_updating_display_name_then_me_returns_updated_display_name()
{
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let expected_subject = seeded_user.external_reference.clone();
    let updated_display_name = "Polyphony User";

    let state = seeded_state(&expected_subject, "valid-token");
    let app = build_app(state);

    let patch_response =
        patch_me_display_name_with_token(&app, updated_display_name, "valid-token").await;

    assert_eq!(patch_response.status(), StatusCode::OK);

    let patch_payload = common::bdd_support::response_payload_json(patch_response).await;
    assert_eq!(
        patch_payload["display_name"].as_str(),
        Some(updated_display_name)
    );

    let me_response = get_me_with_token(&app, "valid-token").await;
    assert_eq!(me_response.status(), StatusCode::OK);

    let me_payload = common::bdd_support::response_payload_json(me_response).await;
    assert!(Uuid::parse_str(me_payload["user_id"].as_str().expect("user id string")).is_ok());
    assert_eq!(
        me_payload["external_reference"].as_str(),
        Some(expected_subject.as_str())
    );
    assert_eq!(
        me_payload["display_name"].as_str(),
        Some(updated_display_name)
    );
}

#[tokio::test]
async fn given_existing_user_when_lookup_by_id_then_returns_minimal_profile() {
    let entity_seeder = EntitySeeder;
    let seeded_user = entity_seeder.user();
    let expected_subject = seeded_user.external_reference.clone();

    let state = seeded_state(&expected_subject, "valid-token");
    let app = build_app(state);

    let _ = get_me_with_token(&app, "valid-token").await;

    let update_response =
        patch_me_display_name_with_token(&app, "Lookup Name", "valid-token").await;
    assert_eq!(update_response.status(), StatusCode::OK);

    let me_payload =
        common::bdd_support::response_payload_json(get_me_with_token(&app, "valid-token").await)
            .await;
    let user_id = me_payload["user_id"]
        .as_str()
        .expect("user id to be present")
        .to_owned();

    let response = get_user_by_id_with_token(&app, &user_id, "valid-token").await;
    assert_eq!(response.status(), StatusCode::OK);

    let payload = common::bdd_support::response_payload_json(response).await;
    assert_eq!(payload["id"].as_str(), Some(user_id.as_str()));
    assert_eq!(payload["display_name"].as_str(), Some("Lookup Name"));
    assert!(payload.get("issuer").is_none());
    assert!(payload.get("token_duration_hours").is_none());
}

#[tokio::test]
async fn given_missing_user_when_lookup_by_id_then_returns_not_found() {
    let state = seeded_state("auth0|lookup-user", "valid-token");
    let app = build_app(state);

    let response =
        get_user_by_id_with_token(&app, "00000000-0000-0000-0000-000000000001", "valid-token")
            .await;

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_invalid_token_when_lookup_by_id_then_returns_unauthorized() {
    let state = seeded_state("auth0|lookup-user", "valid-token");
    let app = build_app(state);

    let response =
        get_user_by_id_with_token(&app, "00000000-0000-0000-0000-000000000001", "wrong-token")
            .await;

    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
}

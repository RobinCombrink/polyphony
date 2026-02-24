mod entity_seeder;

use std::sync::Arc;

use async_trait::async_trait;
use axum::{
    body::Body,
    http::{Request, StatusCode, header},
};
use backend_api::{
    ApiState, build_app,
    auth::{Auth0Config, AuthState, AuthenticatedUser, TokenVerifier},
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
    }
}

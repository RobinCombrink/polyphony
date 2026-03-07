use std::sync::Arc;

use axum::{
    extract::{FromRef, FromRequestParts},
    http::{StatusCode, request::Parts},
    response::{IntoResponse, Response},
};
use backend_domain::{ExternalReference, UserId};
use backend_storage::UserRepository;
use http::header::AUTHORIZATION;
use jwt_authorizer::{Authorizer, JwtAuthorizer, Validation};
use serde::Deserialize;
use thiserror::Error;
use url::Url;
use uuid::Uuid;

#[derive(Clone)]
pub struct AuthState<Verifier>
where
    Verifier: TokenVerifier,
{
    pub config: Auth0Config,
    pub token_verifier: Arc<Verifier>,
}

impl<Verifier> AuthState<Verifier>
where
    Verifier: TokenVerifier,
{
    pub fn new(config: Auth0Config, token_verifier: Arc<Verifier>) -> Self {
        Self {
            config,
            token_verifier,
        }
    }
}

impl<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>
    FromRef<crate::ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>
    for Arc<AuthState<Verifier>>
where
    UserRepo: backend_storage::UserRepository,
    ServerRepo: backend_storage::ServerRepository,
    ChannelRepo: backend_storage::ChannelRepository,
    MessageRepo: backend_storage::MessageRepository,
    Verifier: TokenVerifier,
{
    fn from_ref(
        input: &crate::ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
    ) -> Self {
        input.auth_state.clone()
    }
}

#[derive(Clone, Debug)]
pub struct Auth0Config {
    pub issuer: Url,
    pub audience: String,
}

impl Default for Auth0Config {
    fn default() -> Self {
        Self {
            issuer: Url::parse("https://dev-polyphony.eu.auth0.com/")
                .expect("default issuer to be valid URL"),
            audience: "https://app.polyphony.com".to_owned(),
        }
    }
}

impl Auth0Config {
    pub fn from_environment() -> Self {
        let default_config = Self::default();

        let issuer =
            std::env::var("AUTH0_ISSUER").unwrap_or_else(|_| default_config.issuer.to_string());

        let audience =
            std::env::var("AUTH0_AUDIENCE").unwrap_or_else(|_| default_config.audience.clone());

        Self {
            issuer: Url::parse(&issuer)
                .expect("AUTH0_ISSUER must be a valid URL with trailing slash"),
            audience,
        }
    }
}

#[derive(Clone, Debug)]
pub struct AuthenticatedUser {
    pub user_id: UserId,
    pub external_reference: ExternalReference,
}

#[async_trait::async_trait]
pub trait TokenVerifier: Send + Sync {
    async fn verify(&self, bearer_token: &str) -> Result<AuthenticatedUser, AuthError>;
}

pub struct JwksTokenVerifier {
    authorizer: Authorizer<AuthClaims>,
}

impl JwksTokenVerifier {
    pub async fn new(config: Auth0Config) -> Result<Self, jwt_authorizer::error::InitError> {
        let validation = Validation::new()
            .iss(&[config.issuer.as_str()])
            .aud(&[config.audience.as_str()]);

        let authorizer = JwtAuthorizer::from_oidc(config.issuer.as_str())
            .validation(validation)
            .build()
            .await?;

        Ok(Self { authorizer })
    }
}

#[derive(Clone, Debug, Deserialize)]
struct AuthClaims {
    sub: String,
}

#[async_trait::async_trait]
impl TokenVerifier for JwksTokenVerifier {
    async fn verify(&self, bearer_token: &str) -> Result<AuthenticatedUser, AuthError> {
        let token_data = self
            .authorizer
            .check_auth(bearer_token)
            .await
            .map_err(|error| AuthError::InvalidToken(error.to_string()))?;

        let authenticated_user = AuthenticatedUser {
            user_id: Uuid::nil().into(),
            external_reference: token_data.claims.sub.into(),
        };

        Ok(authenticated_user)
    }
}

#[derive(Debug, Error)]
pub enum AuthError {
    #[error("missing authorization header")]
    MissingAuthorizationHeader,
    #[error("authorization header is not bearer token")]
    NonBearerAuthorization,
    #[error("invalid token: {0}")]
    InvalidToken(String),
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let body = serde_json::json!({
            "error": self.to_string(),
        });

        (StatusCode::UNAUTHORIZED, axum::Json(body)).into_response()
    }
}

impl<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>
    FromRequestParts<crate::ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>
    for AuthenticatedUser
where
    UserRepo: UserRepository,
    ServerRepo: backend_storage::ServerRepository,
    ChannelRepo: backend_storage::ChannelRepository,
    MessageRepo: backend_storage::MessageRepository,
    Verifier: TokenVerifier,
{
    type Rejection = AuthError;

    fn from_request_parts(
        parts: &mut Parts,
        state: &crate::ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
    ) -> impl std::future::Future<Output = Result<Self, Self::Rejection>> + Send {
        let auth_state = state.auth_state.clone();
        let user_repository = state.user_repository.clone();

        let authorization_header = parts
            .headers
            .get(AUTHORIZATION)
            .ok_or(AuthError::MissingAuthorizationHeader)
            .and_then(|header_value| {
                header_value
                    .to_str()
                    .map_err(|_| AuthError::NonBearerAuthorization)
            })
            .and_then(parse_bearer_token);

        async move {
            let bearer_token = authorization_header?;
            let verified_user = auth_state.token_verifier.verify(&bearer_token).await?;
            let user = user_repository
                .get_or_create_user_by_external_reference(&verified_user.external_reference)
                .await;

            Ok(AuthenticatedUser {
                user_id: user.id,
                external_reference: verified_user.external_reference,
            })
        }
    }
}

fn parse_bearer_token(authorization_value: &str) -> Result<String, AuthError> {
    let bearer_prefix = "Bearer ";

    if !authorization_value.starts_with(bearer_prefix) {
        return Err(AuthError::NonBearerAuthorization);
    }

    Ok(authorization_value
        .trim_start_matches(bearer_prefix)
        .to_owned())
}

#[cfg(test)]
mod tests {
    use super::parse_bearer_token;

    #[test]
    fn parse_bearer_token_extracts_token() {
        let token = parse_bearer_token("Bearer test-token")
            .expect("token should be extracted from bearer header");

        assert_eq!(token, "test-token");
    }
}

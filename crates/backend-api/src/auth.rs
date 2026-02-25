use std::{collections::HashMap, sync::Arc};

use axum::{
    extract::{FromRef, FromRequestParts},
    http::{StatusCode, request::Parts},
    response::{IntoResponse, Response},
};
use http::header::AUTHORIZATION;
use jsonwebtoken::{Algorithm, DecodingKey, TokenData, Validation, decode, decode_header};
use serde::{Deserialize, Serialize};
use thiserror::Error;
use url::Url;

#[derive(Clone)]
pub struct AuthState {
    pub config: Auth0Config,
    pub token_verifier: Arc<dyn TokenVerifier>,
}

impl AuthState {
    pub fn new(config: Auth0Config, token_verifier: Arc<dyn TokenVerifier>) -> Self {
        Self {
            config,
            token_verifier,
        }
    }
}

impl FromRef<crate::ApiState> for Arc<AuthState> {
    fn from_ref(input: &crate::ApiState) -> Self {
        input.auth_state.clone()
    }
}

#[derive(Clone, Debug)]
pub struct Auth0Config {
    pub issuer: Url,
    pub audience: String,
    pub token_duration_hours: u64,
}

impl Default for Auth0Config {
    fn default() -> Self {
        Self {
            issuer: Url::parse("https://dev-polyphony.eu.auth0.com/")
                .expect("default issuer to be valid URL"),
            audience: "polyphony-api".to_owned(),
            token_duration_hours: 18,
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

        let token_duration_hours = std::env::var("AUTH0_ACCESS_TOKEN_DURATION_HOURS")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(default_config.token_duration_hours);

        Self {
            issuer: Url::parse(&issuer)
                .expect("AUTH0_ISSUER must be a valid URL with trailing slash"),
            audience,
            token_duration_hours,
        }
    }
}

#[derive(Clone, Debug)]
pub struct AuthenticatedUser {
    pub subject: String,
}

#[async_trait::async_trait]
pub trait TokenVerifier: Send + Sync {
    async fn verify(&self, bearer_token: &str) -> Result<AuthenticatedUser, AuthError>;
}

#[derive(Clone)]
pub struct JwksTokenVerifier {
    config: Auth0Config,
}

impl JwksTokenVerifier {
    pub fn new(config: Auth0Config) -> Self {
        Self { config }
    }
}

#[derive(Debug, Deserialize, Serialize)]
struct AuthClaims {
    sub: String,
}

#[derive(Debug, Deserialize)]
struct JwksDocument {
    keys: Vec<JwkKey>,
}

#[derive(Debug, Deserialize)]
struct JwkKey {
    kid: String,
    n: String,
    e: String,
    kty: String,
}

#[async_trait::async_trait]
impl TokenVerifier for JwksTokenVerifier {
    async fn verify(&self, bearer_token: &str) -> Result<AuthenticatedUser, AuthError> {
        let token_header = decode_header(bearer_token).map_err(AuthError::InvalidToken)?;
        let key_id = token_header.kid.ok_or(AuthError::MissingKeyId)?;

        let jwks_uri = self
            .config
            .issuer
            .join(".well-known/jwks.json")
            .map_err(|_| AuthError::InvalidIssuer)?;

        let jwks_document: JwksDocument = reqwest::get(jwks_uri.as_str())
            .await
            .map_err(|_| AuthError::JwksFetchFailed)?
            .json()
            .await
            .map_err(|_| AuthError::JwksParseFailed)?;

        let signing_keys = jwks_document
            .keys
            .into_iter()
            .filter(|key| key.kty == "RSA")
            .map(|key| (key.kid.clone(), key))
            .collect::<HashMap<_, _>>();

        let selected_key = signing_keys.get(&key_id).ok_or(AuthError::UnknownKeyId)?;

        let decoding_key = DecodingKey::from_rsa_components(&selected_key.n, &selected_key.e)
            .map_err(AuthError::InvalidToken)?;

        let mut validation = Validation::new(Algorithm::RS256);
        validation.set_issuer(&[self.config.issuer.as_str()]);
        validation.set_audience(&[self.config.audience.as_str()]);

        let token_data: TokenData<AuthClaims> =
            decode(bearer_token, &decoding_key, &validation).map_err(AuthError::InvalidToken)?;

        let authenticated_user = AuthenticatedUser {
            subject: token_data.claims.sub,
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
    #[error("token header missing key id")]
    MissingKeyId,
    #[error("invalid issuer URL")]
    InvalidIssuer,
    #[error("failed to fetch jwks")]
    JwksFetchFailed,
    #[error("failed to parse jwks")]
    JwksParseFailed,
    #[error("jwks key id not found")]
    UnknownKeyId,
    #[error("invalid token")]
    InvalidToken(#[from] jsonwebtoken::errors::Error),
}

impl IntoResponse for AuthError {
    fn into_response(self) -> Response {
        let body = serde_json::json!({
            "error": self.to_string(),
        });

        (StatusCode::UNAUTHORIZED, axum::Json(body)).into_response()
    }
}

impl<S> FromRequestParts<S> for AuthenticatedUser
where
    Arc<AuthState>: FromRef<S>,
    S: Send + Sync,
{
    type Rejection = AuthError;

    fn from_request_parts(
        parts: &mut Parts,
        state: &S,
    ) -> impl std::future::Future<Output = Result<Self, Self::Rejection>> + Send {
        let auth_state = Arc::<AuthState>::from_ref(state);

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
            auth_state.token_verifier.verify(&bearer_token).await
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
    use super::AuthClaims;
    use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Header, Validation, decode, encode};

    #[test]
    fn jsonwebtoken_crypto_provider_is_usable() {
        let claims = AuthClaims {
            sub: "test-user".to_owned(),
        };

        let token = encode(
            &Header::new(Algorithm::HS256),
            &claims,
            &EncodingKey::from_secret(b"test-secret"),
        )
        .expect("token encoding to succeed");

        let mut validation = Validation::new(Algorithm::HS256);
        validation.validate_exp = false;

        let token_data = decode::<AuthClaims>(
            &token,
            &DecodingKey::from_secret(b"test-secret"),
            &validation,
        )
        .expect("token decoding to succeed");

        assert_eq!(token_data.claims.sub, "test-user");
    }
}

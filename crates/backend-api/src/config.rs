use std::{net::SocketAddr, str::FromStr};

use thiserror::Error;

use crate::auth::Auth0Config;

const ENV_RUNTIME: &str = "BACKEND_API_RUNTIME_ENV";
const ENV_BIND_ADDRESS: &str = "BACKEND_API_BIND";
const ENV_CORS_ALLOWED_ORIGINS: &str = "BACKEND_API_CORS_ALLOWED_ORIGINS";
const ENV_HTTP_REQUEST_LOGGING_ENABLED: &str = "BACKEND_API_HTTP_REQUEST_LOGGING_ENABLED";
const ENV_HTTP_REQUEST_LOGGING_LEVEL: &str = "BACKEND_API_HTTP_REQUEST_LOGGING_LEVEL";
const ENV_AUTH0_ISSUER: &str = "AUTH0_ISSUER";
const ENV_AUTH0_AUDIENCE: &str = "AUTH0_AUDIENCE";
const ENV_POSTGRES_HOST: &str = "POSTGRES_HOST";
const ENV_POSTGRES_PORT: &str = "POSTGRES_PORT";
const ENV_POSTGRES_DATABASE: &str = "POSTGRES_DATABASE";
const ENV_POSTGRES_USERNAME: &str = "POSTGRES_USERNAME";
const ENV_POSTGRES_PASSWORD: &str = "POSTGRES_PASSWORD";
const ENV_LIVEKIT_URL: &str = "LIVEKIT_URL";
const ENV_LIVEKIT_API_KEY: &str = "LIVEKIT_API_KEY";
const ENV_LIVEKIT_API_SECRET: &str = "LIVEKIT_API_SECRET";

const REQUIRED_NON_LOCAL_ENV_VARS: &[&str] = &[
    ENV_RUNTIME,
    ENV_BIND_ADDRESS,
    ENV_CORS_ALLOWED_ORIGINS,
    ENV_AUTH0_ISSUER,
    ENV_AUTH0_AUDIENCE,
    ENV_POSTGRES_HOST,
    ENV_POSTGRES_PORT,
    ENV_POSTGRES_DATABASE,
    ENV_POSTGRES_USERNAME,
    ENV_POSTGRES_PASSWORD,
    ENV_LIVEKIT_URL,
    ENV_LIVEKIT_API_KEY,
    ENV_LIVEKIT_API_SECRET,
];

#[derive(Clone, Debug)]
pub struct BackendApiConfig {
    pub runtime_environment: RuntimeEnvironment,
    pub bind_address: SocketAddr,
    pub auth0: Auth0Config,
    pub livekit: LiveKitConfig,
    pub postgres: PostgresConfig,
    pub http_request_logging: HttpRequestLoggingConfig,
}

impl Default for BackendApiConfig {
    fn default() -> Self {
        Self {
            runtime_environment: RuntimeEnvironment::default(),
            bind_address: SocketAddr::from(([127, 0, 0, 1], 5067)),
            auth0: Auth0Config::default(),
            livekit: LiveKitConfig::default(),
            postgres: PostgresConfig::default(),
            http_request_logging: HttpRequestLoggingConfig::default(),
        }
    }
}

impl BackendApiConfig {
    pub fn from_environment() -> Self {
        let default_config = Self::default();
        let runtime_environment = RuntimeEnvironment::from_environment();

        let bind_address = std::env::var(ENV_BIND_ADDRESS)
            .ok()
            .and_then(|value| value.parse::<SocketAddr>().ok())
            .unwrap_or(default_config.bind_address);

        let auth0 = Auth0Config::from_environment();
        let livekit = LiveKitConfig::from_environment();
        let postgres = PostgresConfig::from_environment();
        let http_request_logging = HttpRequestLoggingConfig::from_environment();

        Self {
            runtime_environment,
            bind_address,
            auth0,
            livekit,
            postgres,
            http_request_logging,
        }
    }

    pub fn load_and_validate_from_environment() -> Result<Self, ConfigValidationError> {
        let config = Self::from_environment();
        config.validate()?;
        Ok(config)
    }

    pub fn validate(&self) -> Result<(), ConfigValidationError> {
        self.validate_for_runtime_with_lookup(|name| std::env::var(name).ok())
    }

    fn validate_for_runtime_with_lookup(
        &self,
        lookup: impl Fn(&str) -> Option<String>,
    ) -> Result<(), ConfigValidationError> {
        if !self.runtime_environment.requires_explicit_environment() {
            return Ok(());
        }

        let missing_required_vars = REQUIRED_NON_LOCAL_ENV_VARS
            .iter()
            .filter(|name| {
                lookup(name)
                    .map(|value| value.trim().is_empty())
                    .unwrap_or(true)
            })
            .copied()
            .collect::<Vec<_>>();

        if !missing_required_vars.is_empty() {
            return Err(ConfigValidationError::MissingRequiredEnvironmentVariables(
                missing_required_vars.join(", "),
            ));
        }

        if !self.runtime_environment.is_production() {
            return Ok(());
        }

        let lookup = lookup(ENV_CORS_ALLOWED_ORIGINS).unwrap_or_default();

        let configured_cors_origins = lookup
            .split(',')
            .map(str::trim)
            .filter(|origin| !origin.is_empty())
            .collect::<Vec<_>>();

        let localhost_origins = configured_cors_origins
            .iter()
            .filter(|origin| origin.contains("localhost") || origin.contains("127.0.0.1"))
            .copied()
            .collect::<Vec<_>>();

        if !localhost_origins.is_empty() {
            return Err(ConfigValidationError::InvalidProductionCorsOrigins(
                localhost_origins.join(", "),
            ));
        }

        Ok(())
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum RuntimeEnvironment {
    #[default]
    Local,
    Dev,
    Production,
}

impl RuntimeEnvironment {
    pub fn from_environment() -> Self {
        std::env::var(ENV_RUNTIME)
            .ok()
            .as_deref()
            .and_then(|value| RuntimeEnvironment::from_str(value).ok())
            .unwrap_or_default()
    }

    pub fn is_production(self) -> bool {
        matches!(self, Self::Production)
    }

    pub fn requires_explicit_environment(self) -> bool {
        !matches!(self, Self::Local)
    }
}

impl FromStr for RuntimeEnvironment {
    type Err = ();

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value.trim().to_ascii_lowercase().as_str() {
            "local" => Ok(Self::Local),
            "dev" | "development" => Ok(Self::Dev),
            "prod" | "production" => Ok(Self::Production),
            _ => Err(()),
        }
    }
}

#[derive(Debug, Error, PartialEq, Eq)]
pub enum ConfigValidationError {
    #[error("missing required environment variables for non-local runtime: {0}")]
    MissingRequiredEnvironmentVariables(String),
    #[error("production CORS origins cannot include localhost addresses: {0}")]
    InvalidProductionCorsOrigins(String),
}

#[derive(Clone, Copy, Debug)]
pub struct HttpRequestLoggingConfig {
    pub enabled: bool,
    pub level: HttpRequestLogLevel,
}

impl Default for HttpRequestLoggingConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            level: HttpRequestLogLevel::Info,
        }
    }
}

impl HttpRequestLoggingConfig {
    pub fn from_environment() -> Self {
        let default_config = Self::default();

        let enabled = std::env::var(ENV_HTTP_REQUEST_LOGGING_ENABLED)
            .ok()
            .and_then(|value| match value.trim().to_ascii_lowercase().as_str() {
                "1" | "true" | "yes" | "on" => Some(true),
                "0" | "false" | "no" | "off" => Some(false),
                _ => None,
            })
            .unwrap_or(default_config.enabled);

        let level = std::env::var(ENV_HTTP_REQUEST_LOGGING_LEVEL)
            .ok()
            .and_then(|value| HttpRequestLogLevel::from_str(&value).ok())
            .unwrap_or(default_config.level);

        Self { enabled, level }
    }
}

#[derive(Clone, Copy, Debug)]
pub enum HttpRequestLogLevel {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
}

impl FromStr for HttpRequestLogLevel {
    type Err = ();

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s.trim().to_ascii_lowercase().as_str() {
            "trace" => Ok(Self::Trace),
            "debug" => Ok(Self::Debug),
            "info" => Ok(Self::Info),
            "warn" | "warning" => Ok(Self::Warn),
            "error" => Ok(Self::Error),
            _ => Err(()),
        }
    }
}

impl HttpRequestLogLevel {
    pub fn as_tracing_level(self) -> tracing::Level {
        match self {
            Self::Trace => tracing::Level::TRACE,
            Self::Debug => tracing::Level::DEBUG,
            Self::Info => tracing::Level::INFO,
            Self::Warn => tracing::Level::WARN,
            Self::Error => tracing::Level::ERROR,
        }
    }

    pub fn as_env_directive(self) -> &'static str {
        match self {
            Self::Trace => "trace",
            Self::Debug => "debug",
            Self::Info => "info",
            Self::Warn => "warn",
            Self::Error => "error",
        }
    }
}

#[derive(Clone, Debug)]
pub struct PostgresConfig {
    pub host: String,
    pub port: u16,
    pub database: String,
    pub username: String,
    pub password: String,
    pub max_connections: u32,
}

impl Default for PostgresConfig {
    fn default() -> Self {
        Self {
            host: "127.0.0.1".to_owned(),
            port: 5432,
            database: "polyphony".to_owned(),
            username: "polyphony".to_owned(),
            password: "polyphony".to_owned(),
            max_connections: 100,
        }
    }
}

impl PostgresConfig {
    pub fn from_environment() -> Self {
        let default_config = Self::default();

        let host = std::env::var(ENV_POSTGRES_HOST).unwrap_or(default_config.host);
        let port = std::env::var(ENV_POSTGRES_PORT)
            .ok()
            .and_then(|value| value.parse::<u16>().ok())
            .unwrap_or(default_config.port);
        let database = std::env::var(ENV_POSTGRES_DATABASE).unwrap_or(default_config.database);
        let username = std::env::var(ENV_POSTGRES_USERNAME).unwrap_or(default_config.username);
        let password = std::env::var(ENV_POSTGRES_PASSWORD).unwrap_or(default_config.password);
        let max_connections = std::env::var("POSTGRES_MAX_CONNECTIONS")
            .ok()
            .and_then(|value| value.parse::<u32>().ok())
            .unwrap_or(default_config.max_connections);

        Self {
            host,
            port,
            database,
            username,
            password,
            max_connections,
        }
    }
}

#[derive(Clone, Debug)]
pub struct LiveKitConfig {
    pub url: String,
    pub api_key: String,
    pub api_secret: String,
    pub token_ttl_seconds: u64,
}

impl Default for LiveKitConfig {
    fn default() -> Self {
        let url = "ws://127.0.0.1:7880".to_owned();

        Self {
            url,
            api_key: "devkey".to_owned(),
            api_secret: "secret".to_owned(),
            token_ttl_seconds: 3600,
        }
    }
}

impl LiveKitConfig {
    pub fn from_environment() -> Self {
        let default_config = Self::default();

        let url = std::env::var(ENV_LIVEKIT_URL).unwrap_or(default_config.url);
        let api_key = std::env::var(ENV_LIVEKIT_API_KEY).unwrap_or(default_config.api_key);
        let api_secret = std::env::var(ENV_LIVEKIT_API_SECRET).unwrap_or(default_config.api_secret);
        let token_ttl_seconds = std::env::var("LIVEKIT_TOKEN_TTL_SECONDS")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(default_config.token_ttl_seconds);

        Self {
            url,
            api_key,
            api_secret,
            token_ttl_seconds,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::collections::HashMap;

    use super::{
        BackendApiConfig, ConfigValidationError, ENV_AUTH0_AUDIENCE, ENV_AUTH0_ISSUER,
        ENV_BIND_ADDRESS, ENV_CORS_ALLOWED_ORIGINS, ENV_LIVEKIT_API_KEY, ENV_LIVEKIT_API_SECRET,
        ENV_LIVEKIT_URL, ENV_POSTGRES_DATABASE, ENV_POSTGRES_HOST, ENV_POSTGRES_PASSWORD,
        ENV_POSTGRES_PORT, ENV_POSTGRES_USERNAME, ENV_RUNTIME, HttpRequestLoggingConfig,
        LiveKitConfig, PostgresConfig, RuntimeEnvironment,
    };
    use crate::auth::Auth0Config;

    #[test]
    fn production_validation_fails_when_required_variables_are_missing() {
        let config = production_config();
        let lookup = HashMap::<String, String>::new();

        let validation = config.validate_for_runtime_with_lookup(|name| lookup.get(name).cloned());

        assert!(matches!(
            validation,
            Err(ConfigValidationError::MissingRequiredEnvironmentVariables(
                _
            ))
        ));
    }

    #[test]
    fn dev_validation_fails_when_required_variables_are_missing() {
        let mut config = production_config();
        config.runtime_environment = RuntimeEnvironment::Dev;
        let lookup = HashMap::<String, String>::new();

        let validation = config.validate_for_runtime_with_lookup(|name| lookup.get(name).cloned());

        assert!(matches!(
            validation,
            Err(ConfigValidationError::MissingRequiredEnvironmentVariables(
                _
            ))
        ));
    }

    #[test]
    fn production_validation_fails_when_localhost_cors_origin_is_used() {
        let config = production_config();
        let mut lookup = required_production_lookup();
        lookup.insert(
            "BACKEND_API_CORS_ALLOWED_ORIGINS".to_owned(),
            "https://app.polyphony.com,http://localhost:3000".to_owned(),
        );

        let validation = config.validate_for_runtime_with_lookup(|name| lookup.get(name).cloned());

        assert!(matches!(
            validation,
            Err(ConfigValidationError::InvalidProductionCorsOrigins(_))
        ));
    }

    #[test]
    fn production_validation_passes_with_required_values() {
        let config = production_config();
        let lookup = required_production_lookup();

        let validation = config.validate_for_runtime_with_lookup(|name| lookup.get(name).cloned());

        assert!(validation.is_ok());
    }

    fn production_config() -> BackendApiConfig {
        BackendApiConfig {
            runtime_environment: RuntimeEnvironment::Production,
            bind_address: "0.0.0.0:5067".parse().expect("bind address should parse"),
            auth0: Auth0Config {
                issuer: "https://prod-polyphony.eu.auth0.com/"
                    .parse()
                    .expect("issuer should parse"),
                audience: "https://api.polyphony.com".to_owned(),
                token_duration_hours: 18,
            },
            livekit: LiveKitConfig {
                url: "ws://livekit:7880".to_owned(),
                api_key: "prod-livekit-key".to_owned(),
                api_secret: "prod-livekit-secret".to_owned(),
                token_ttl_seconds: 3600,
            },
            postgres: PostgresConfig {
                host: "postgres".to_owned(),
                port: 5432,
                database: "polyphony".to_owned(),
                username: "polyphony".to_owned(),
                password: "production-db-password".to_owned(),
                max_connections: 100,
            },
            http_request_logging: HttpRequestLoggingConfig::default(),
        }
    }

    fn required_production_lookup() -> HashMap<String, String> {
        HashMap::from([
            (ENV_RUNTIME.to_owned(), "production".to_owned()),
            (ENV_BIND_ADDRESS.to_owned(), "0.0.0.0:5067".to_owned()),
            (
                ENV_CORS_ALLOWED_ORIGINS.to_owned(),
                "https://app.polyphony.com".to_owned(),
            ),
            (
                ENV_AUTH0_ISSUER.to_owned(),
                "https://prod-polyphony.eu.auth0.com/".to_owned(),
            ),
            (
                ENV_AUTH0_AUDIENCE.to_owned(),
                "https://api.polyphony.com".to_owned(),
            ),
            (ENV_POSTGRES_HOST.to_owned(), "postgres".to_owned()),
            (ENV_POSTGRES_PORT.to_owned(), "5432".to_owned()),
            (ENV_POSTGRES_DATABASE.to_owned(), "polyphony".to_owned()),
            (ENV_POSTGRES_USERNAME.to_owned(), "polyphony".to_owned()),
            (
                ENV_POSTGRES_PASSWORD.to_owned(),
                "production-db-password".to_owned(),
            ),
            (
                ENV_LIVEKIT_URL.to_owned(),
                "wss://livekit.polyphony.com".to_owned(),
            ),
            (
                ENV_LIVEKIT_API_KEY.to_owned(),
                "prod-livekit-key".to_owned(),
            ),
            (
                ENV_LIVEKIT_API_SECRET.to_owned(),
                "prod-livekit-secret".to_owned(),
            ),
        ])
    }
}

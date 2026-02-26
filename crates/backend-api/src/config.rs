use std::net::SocketAddr;

use crate::auth::Auth0Config;

#[derive(Clone, Debug)]
pub struct BackendApiConfig {
    pub bind_address: SocketAddr,
    pub auth0: Auth0Config,
    pub livekit: LiveKitConfig,
}

impl Default for BackendApiConfig {
    fn default() -> Self {
        Self {
            bind_address: SocketAddr::from(([127, 0, 0, 1], 5067)),
            auth0: Auth0Config::default(),
            livekit: LiveKitConfig::default(),
        }
    }
}

impl BackendApiConfig {
    pub fn from_environment() -> Self {
        let default_config = Self::default();

        let bind_address = std::env::var("BACKEND_API_BIND")
            .ok()
            .and_then(|value| value.parse::<SocketAddr>().ok())
            .unwrap_or(default_config.bind_address);

        let auth0 = Auth0Config::from_environment();
        let livekit = LiveKitConfig::from_environment();

        Self {
            bind_address,
            auth0,
            livekit,
        }
    }
}

#[derive(Clone, Debug)]
pub struct LiveKitConfig {
    pub url: String,
    pub server_api_url: String,
    pub api_key: String,
    pub api_secret: String,
    pub token_ttl_seconds: u64,
}

impl Default for LiveKitConfig {
    fn default() -> Self {
        let url = "ws://127.0.0.1:7880".to_owned();

        Self {
            server_api_url: url
                .replace("wss://", "https://")
                .replace("ws://", "http://"),
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

        let url = std::env::var("LIVEKIT_URL").unwrap_or(default_config.url);
        let server_api_url =
            std::env::var("LIVEKIT_SERVER_API_URL").unwrap_or(default_config.server_api_url);
        let api_key = std::env::var("LIVEKIT_API_KEY").unwrap_or(default_config.api_key);
        let api_secret = std::env::var("LIVEKIT_API_SECRET").unwrap_or(default_config.api_secret);
        let token_ttl_seconds = std::env::var("LIVEKIT_TOKEN_TTL_SECONDS")
            .ok()
            .and_then(|value| value.parse::<u64>().ok())
            .unwrap_or(default_config.token_ttl_seconds);

        Self {
            url,
            server_api_url,
            api_key,
            api_secret,
            token_ttl_seconds,
        }
    }
}

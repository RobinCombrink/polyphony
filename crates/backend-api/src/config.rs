use std::net::SocketAddr;

use crate::auth::Auth0Config;

#[derive(Clone, Debug)]
pub struct BackendApiConfig {
    pub bind_address: SocketAddr,
    pub auth0: Auth0Config,
}

impl Default for BackendApiConfig {
    fn default() -> Self {
        Self {
            bind_address: SocketAddr::from(([127, 0, 0, 1], 5067)),
            auth0: Auth0Config::default(),
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

        Self {
            bind_address,
            auth0,
        }
    }
}

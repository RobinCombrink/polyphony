use anyhow::Result;
use opentelemetry::trace::TracerProvider as _;
use opentelemetry_sdk::trace::SdkTracerProvider;
use tracing_subscriber::{EnvFilter, layer::SubscriberExt, util::SubscriberInitExt};

use crate::config::HttpRequestLoggingConfig;

pub fn init_open_telemetry() -> Result<()> {
    let tracer_provider = SdkTracerProvider::builder().build();
    let tracer = tracer_provider.tracer("backend-api");

    let filter_layer = EnvFilter::try_from_default_env().unwrap_or_else(|_| {
        let http_request_logging = HttpRequestLoggingConfig::from_environment();
        let tower_http_level = if http_request_logging.enabled {
            http_request_logging.level.as_env_directive()
        } else {
            "off"
        };

        EnvFilter::new(format!(
            "info,backend_api=debug,tower_http={tower_http_level}"
        ))
    });

    tracing_subscriber::registry()
        .with(filter_layer)
        .with(tracing_subscriber::fmt::layer())
        .with(tracing_opentelemetry::layer().with_tracer(tracer))
        .init();

    Ok(())
}

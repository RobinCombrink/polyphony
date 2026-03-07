use anyhow::Result;
use tracing::info;

#[tokio::main]
async fn main() -> Result<()> {
    let backend_config =
        backend_api::config::BackendApiConfig::load_and_validate_from_environment()?;

    backend_api::observability::init_open_telemetry()?;

    let bind_address = backend_config.bind_address;
    let app = backend_api::build_app_with_runtime_settings(
        backend_api::default_api_state_with_config(backend_config.clone()).await,
        backend_config.http_request_logging,
        backend_config.allowed_cors_origins(),
    );

    info!(%bind_address, "backend-api listening");

    let listener = tokio::net::TcpListener::bind(bind_address).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

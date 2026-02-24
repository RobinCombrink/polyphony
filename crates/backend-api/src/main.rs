use anyhow::Result;
use tracing::info;

#[tokio::main]
async fn main() -> Result<()> {
    backend_api::observability::init_open_telemetry()?;

    let bind_address = backend_api::default_bind_address();
    let app = backend_api::build_app(backend_api::default_api_state());

    info!(%bind_address, "backend-api listening");

    let listener = tokio::net::TcpListener::bind(bind_address).await?;
    axum::serve(listener, app).await?;

    Ok(())
}

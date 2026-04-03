use axum::{Json, response::IntoResponse};

use crate::dto::HealthResponse;

#[utoipa::path(
    get,
    path = "/health",
    responses(
        (status = 200, description = "Backend API health status", body = HealthResponse)
    ),
    tag = "Health"
)]
pub(crate) async fn health() -> impl IntoResponse {
    Json(HealthResponse {
        status: "ok",
        service: "backend-api",
    })
}

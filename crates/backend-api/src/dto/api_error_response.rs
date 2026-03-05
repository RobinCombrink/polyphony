use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct ApiErrorResponse {
    pub error_code: String,
    pub error: String,
}

impl ApiErrorResponse {
    pub fn new(error_code: &str, error: &str) -> Self {
        Self {
            error_code: error_code.to_owned(),
            error: error.to_owned(),
        }
    }
}

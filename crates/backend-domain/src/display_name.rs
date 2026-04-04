use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

const MAX_DISPLAY_NAME_LENGTH: usize = 100;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DisplayNameError {
    Empty,
    TooLong { max: usize },
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize, ToSchema)]
pub struct DisplayName(String);

impl DisplayName {
    pub fn new(value: String) -> Result<Self, DisplayNameError> {
        let trimmed = value.trim().to_owned();
        if trimmed.is_empty() {
            return Err(DisplayNameError::Empty);
        }
        if trimmed.len() > MAX_DISPLAY_NAME_LENGTH {
            return Err(DisplayNameError::TooLong {
                max: MAX_DISPLAY_NAME_LENGTH,
            });
        }
        Ok(Self(trimmed))
    }
}

impl From<DisplayName> for String {
    fn from(value: DisplayName) -> Self {
        value.0
    }
}

use serde::Deserialize;

#[derive(Debug, Deserialize)]
pub struct SearchDirectMessagesQuery {
    pub q: Option<String>,
}

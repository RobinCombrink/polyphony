#[derive(Debug, Clone, PartialEq, Eq)]
pub struct User {
    pub auth0_subject: String,
    pub display_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MutationResult {
    Updated,
    Deleted,
    NotFound,
    Forbidden,
}

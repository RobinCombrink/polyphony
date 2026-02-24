use rand::{Rng as _, distr::Alphanumeric};
use backend_api::domain::User;

#[derive(Debug, Default)]
pub struct EntitySeeder;

impl EntitySeeder {
    pub fn user(&self) -> User {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        User {
            auth0_subject: format!("auth0|user_{random_segment}"),
            display_name: format!("User-{random_segment}"),
        }
    }
}

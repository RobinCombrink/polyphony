#![allow(dead_code)]

use backend_api::domain::{Channel, DisplayName, Message, Server, User};
use rand::{Rng as _, distr::Alphanumeric};
use uuid::Uuid;

#[derive(Debug, Clone)]
pub struct ChatFixture {
    pub user: User,
    pub server: Server,
    pub channel: Channel,
    pub message: Message,
}

#[derive(Debug, Default)]
pub struct EntitySeeder;

impl EntitySeeder {
    pub fn chat_fixture(&self) -> ChatFixture {
        let user = self.user();
        let server = self.server();
        let channel = self.channel(&server.id);
        let message = self.message(&channel.id, &user.auth0_subject);

        ChatFixture {
            user,
            server,
            channel,
            message,
        }
    }

    pub fn user(&self) -> User {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        User {
            auth0_subject: format!("auth0|user_{random_segment}"),
            display_name: Some(DisplayName::new(format!("User-{random_segment}"))),
        }
    }

    pub fn server(&self) -> Server {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Server {
            id: Uuid::new_v4().to_string(),
            name: format!("Server-{random_segment}"),
            owner_subject: format!("auth0|owner_{random_segment}"),
        }
    }

    pub fn channel(&self, server_id: &str) -> Channel {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Channel {
            id: format!("chn-seeded-{random_segment}"),
            server_id: server_id.to_owned(),
            name: format!("Channel-{random_segment}"),
        }
    }

    pub fn message(&self, channel_id: &str, author_subject: &str) -> Message {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Message {
            id: format!("msg-seeded-{random_segment}"),
            channel_id: channel_id.to_owned(),
            author_subject: author_subject.to_owned(),
            content: format!("Message-{random_segment}"),
        }
    }
}

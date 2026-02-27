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
        let channel = self.channel(server.id);
        let message = self.message(channel.id, &user.auth0_subject);

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
            id: Uuid::new_v4(),
            name: format!("Server-{random_segment}"),
            owner_subject: format!("auth0|owner_{random_segment}"),
        }
    }

    pub fn channel(&self, server_id: Uuid) -> Channel {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Channel {
            id: Uuid::new_v4(),
            server_id,
            name: format!("Channel-{random_segment}"),
        }
    }

    pub fn message(&self, channel_id: Uuid, author_subject: &str) -> Message {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Message {
            id: format!("msg-seeded-{random_segment}"),
            channel_id,
            author_subject: author_subject.to_owned(),
            content: format!("Message-{random_segment}"),
        }
    }
}

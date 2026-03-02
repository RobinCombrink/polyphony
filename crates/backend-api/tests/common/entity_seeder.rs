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
        let server = self.server(user.id);
        let channel = self.text_channel(server.id);
        let message = self.message(channel.id(), user.id);

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
            id: Uuid::new_v4(),
            external_reference: format!("auth0|user_{random_segment}"),
            display_name: Some(DisplayName::new(format!("User-{random_segment}"))),
        }
    }

    pub fn server(&self, owner_user_id: Uuid) -> Server {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Server {
            id: Uuid::new_v4(),
            name: format!("Server-{random_segment}"),
            owner_user_id,
        }
    }

    pub fn text_channel(&self, server_id: Uuid) -> Channel {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Channel::new_text(
            Uuid::new_v4(),
            server_id,
            format!("Channel-{random_segment}"),
        )
    }

    pub fn voice_channel(&self, server_id: Uuid) -> Channel {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Channel::new_voice(
            Uuid::new_v4(),
            server_id,
            format!("Voice-Channel-{random_segment}"),
        )
    }

    pub fn message(&self, channel_id: Uuid, author_user_id: Uuid) -> Message {
        let random_segment = rand::rng()
            .sample_iter(Alphanumeric)
            .take(8)
            .map(char::from)
            .collect::<String>()
            .to_lowercase();

        Message {
            id: Uuid::new_v4(),
            channel_id,
            author_user_id,
            content: format!("Message-{random_segment}"),
        }
    }
}

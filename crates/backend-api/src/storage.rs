use std::collections::HashMap;

use async_trait::async_trait;
use tokio::sync::RwLock;

use crate::domain::{Channel, Message, Server};

#[derive(Debug, Default)]
struct InMemoryStore {
    next_server_id: u64,
    next_channel_id: u64,
    next_message_id: u64,
    servers: HashMap<String, Server>,
    channels: HashMap<String, Channel>,
    messages_by_channel: HashMap<String, Vec<Message>>,
}

#[async_trait]
pub trait ChatRepository: Send + Sync {
    async fn create_server(&self, name: String, owner_subject: String) -> Server;
    async fn list_servers_for_user(&self, owner_subject: &str) -> Vec<Server>;
    async fn create_channel(&self, server_id: &str, name: String) -> Option<Channel>;
    async fn list_channels_for_server(&self, server_id: &str) -> Option<Vec<Channel>>;
    async fn create_message(
        &self,
        channel_id: &str,
        author_subject: String,
        content: String,
    ) -> Option<Message>;
    async fn list_messages(&self, channel_id: &str) -> Vec<Message>;
}

#[derive(Debug, Default)]
pub struct InMemoryChatRepository {
    store: RwLock<InMemoryStore>,
}

impl InMemoryChatRepository {
    pub fn new() -> Self {
        Self {
            store: RwLock::new(InMemoryStore::default()),
        }
    }
}

impl InMemoryStore {
    fn create_server(&mut self, name: String, owner_subject: String) -> Server {
        self.next_server_id += 1;
        let server = Server {
            id: format!("srv-{}", self.next_server_id),
            name,
            owner_subject,
        };

        self.servers.insert(server.id.clone(), server.clone());
        server
    }

    fn create_channel(&mut self, server_id: &str, name: String) -> Option<Channel> {
        if !self.servers.contains_key(server_id) {
            return None;
        }

        self.next_channel_id += 1;
        let channel = Channel {
            id: format!("chn-{}", self.next_channel_id),
            server_id: server_id.to_owned(),
            name,
        };

        self.channels.insert(channel.id.clone(), channel.clone());
        Some(channel)
    }

    fn create_message(
        &mut self,
        channel_id: &str,
        author_subject: String,
        content: String,
    ) -> Option<Message> {
        if !self.channels.contains_key(channel_id) {
            return None;
        }

        self.next_message_id += 1;
        let message = Message {
            id: format!("msg-{}", self.next_message_id),
            channel_id: channel_id.to_owned(),
            author_subject,
            content,
        };

        self.messages_by_channel
            .entry(channel_id.to_owned())
            .or_default()
            .push(message.clone());

        Some(message)
    }

    fn list_messages(&self, channel_id: &str) -> Vec<Message> {
        self.messages_by_channel
            .get(channel_id)
            .cloned()
            .unwrap_or_default()
    }
}

#[async_trait]
impl ChatRepository for InMemoryChatRepository {
    async fn create_server(&self, name: String, owner_subject: String) -> Server {
        let mut store = self.store.write().await;
        store.create_server(name, owner_subject)
    }

    async fn list_servers_for_user(&self, owner_subject: &str) -> Vec<Server> {
        let store = self.store.read().await;
        store
            .servers
            .values()
            .filter(|server| server.owner_subject == owner_subject)
            .cloned()
            .collect::<Vec<_>>()
    }

    async fn create_channel(&self, server_id: &str, name: String) -> Option<Channel> {
        let mut store = self.store.write().await;
        store.create_channel(server_id, name)
    }

    async fn list_channels_for_server(&self, server_id: &str) -> Option<Vec<Channel>> {
        let store = self.store.read().await;

        if !store.servers.contains_key(server_id) {
            return None;
        }

        let channels = store
            .channels
            .values()
            .filter(|channel| channel.server_id == server_id)
            .cloned()
            .collect::<Vec<_>>();

        Some(channels)
    }

    async fn create_message(
        &self,
        channel_id: &str,
        author_subject: String,
        content: String,
    ) -> Option<Message> {
        let mut store = self.store.write().await;
        store.create_message(channel_id, author_subject, content)
    }

    async fn list_messages(&self, channel_id: &str) -> Vec<Message> {
        let store = self.store.read().await;
        store.list_messages(channel_id)
    }
}

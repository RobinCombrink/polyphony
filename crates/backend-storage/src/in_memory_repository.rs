use async_trait::async_trait;
use backend_domain::{Channel, ChannelType, Membership, Message, Server, User};
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::{
    ChannelRepository, CreateMessageResult, InMemoryStore, MessageRepository, MutationResult,
    ServerRepository,
    UserRepository,
};

#[derive(Debug, Default)]
pub struct InMemoryRepository {
    store: RwLock<InMemoryStore>,
}

impl InMemoryRepository {
    pub fn new() -> Self {
        Self {
            store: RwLock::new(InMemoryStore::default()),
        }
    }
}

#[async_trait]
impl MessageRepository for InMemoryRepository {
    async fn create_message(
        &self,
        channel_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> CreateMessageResult {
        let mut store = self.store.write().await;
        store.create_message(channel_id, author_user_id, content)
    }

    async fn update_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.update_message(channel_id, message_id, author_user_id, content)
    }

    async fn delete_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_message(channel_id, message_id, author_user_id)
    }

    async fn list_messages(&self, channel_id: Uuid) -> Vec<Message> {
        let store = self.store.read().await;
        store.list_messages(channel_id)
    }
}

#[async_trait]
impl UserRepository for InMemoryRepository {
    async fn find_user_by_id(&self, user_id: Uuid) -> Option<User> {
        let store = self.store.read().await;
        store.find_user_by_id(user_id)
    }

    async fn find_user_by_external_reference(&self, external_reference: &str) -> Option<User> {
        let store = self.store.read().await;
        store.find_user_by_external_reference(external_reference)
    }

    async fn get_or_create_user_by_external_reference(&self, external_reference: &str) -> User {
        let mut store = self.store.write().await;
        store.get_or_create_user_by_external_reference(external_reference)
    }

    async fn set_user_display_name(&self, user_id: Uuid, display_name: String) -> Option<User> {
        let mut store = self.store.write().await;
        store.set_user_display_name(user_id, display_name)
    }
}

#[async_trait]
impl ServerRepository for InMemoryRepository {
    async fn create_server(&self, name: String, owner_user_id: Uuid) -> Server {
        let mut store = self.store.write().await;
        store.create_server(name, owner_user_id)
    }

    async fn list_servers_for_user(&self, user_id: Uuid) -> Vec<Server> {
        let store = self.store.read().await;
        store
            .servers
            .values()
            .filter(|server| {
                store
                    .server_members_by_id
                    .get(&server.id)
                    .is_some_and(|members| members.contains(&user_id))
            })
            .cloned()
            .collect::<Vec<_>>()
    }

    async fn is_server_member(&self, server_id: Uuid, user_id: Uuid) -> Option<bool> {
        let store = self.store.read().await;
        store.is_server_member(server_id, user_id)
    }

    async fn add_server_member(
        &self,
        server_id: Uuid,
        actor_user_id: Uuid,
        user_id: Uuid,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.add_server_member(server_id, actor_user_id, user_id)
    }

    async fn delete_server(&self, server_id: Uuid, actor_user_id: Uuid) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_server(server_id, actor_user_id)
    }

    async fn list_server_members(&self, server_id: Uuid) -> Option<Vec<Membership>> {
        let store = self.store.read().await;
        store.list_server_members(server_id)
    }
}

#[async_trait]
impl ChannelRepository for InMemoryRepository {
    async fn create_channel(
        &self,
        server_id: Uuid,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel> {
        let mut store = self.store.write().await;
        store.create_channel(server_id, name, channel_type)
    }

    async fn update_channel_name(
        &self,
        channel_id: Uuid,
        actor_user_id: Uuid,
        name: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.update_channel_name(channel_id, actor_user_id, name)
    }

    async fn delete_channel(&self, channel_id: Uuid, actor_user_id: Uuid) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_channel(channel_id, actor_user_id)
    }

    async fn list_channels_for_server(&self, server_id: Uuid) -> Option<Vec<Channel>> {
        let store = self.store.read().await;

        if !store.servers.contains_key(&server_id) {
            return None;
        }

        let channels = store
            .channels
            .values()
            .filter(|channel| channel.server_id() == server_id)
            .cloned()
            .collect::<Vec<_>>();

        Some(channels)
    }

    async fn find_channel_by_id(&self, channel_id: Uuid) -> Option<Channel> {
        let store = self.store.read().await;
        store.channels.get(&channel_id).cloned()
    }

    async fn is_channel_member(&self, channel_id: Uuid, user_id: Uuid) -> Option<bool> {
        let store = self.store.read().await;
        store.is_channel_member(channel_id, user_id)
    }
}

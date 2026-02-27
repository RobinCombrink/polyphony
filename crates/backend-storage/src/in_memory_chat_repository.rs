use async_trait::async_trait;
use backend_domain::{Channel, Membership, Message, Server, User, VoiceSession};
use tokio::sync::RwLock;
use uuid::Uuid;

use crate::{ChatRepository, InMemoryStore, MessageRepository, MutationResult};

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

#[async_trait]
impl MessageRepository for InMemoryChatRepository {
    async fn create_message(
        &self,
        channel_id: Uuid,
        author_subject: String,
        content: String,
    ) -> Option<Message> {
        let mut store = self.store.write().await;
        store.create_message(channel_id, author_subject, content)
    }

    async fn update_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_subject: &str,
        content: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.update_message(channel_id, message_id, author_subject, content)
    }

    async fn delete_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_subject: &str,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_message(channel_id, message_id, author_subject)
    }

    async fn list_messages(&self, channel_id: Uuid) -> Vec<Message> {
        let store = self.store.read().await;
        store.list_messages(channel_id)
    }
}

#[async_trait]
impl ChatRepository for InMemoryChatRepository {
    async fn find_user_by_subject(&self, auth0_subject: &str) -> Option<User> {
        let store = self.store.read().await;
        store.find_user_by_subject(auth0_subject)
    }

    async fn get_or_create_user(&self, auth0_subject: &str) -> User {
        let mut store = self.store.write().await;
        store.get_or_create_user(auth0_subject)
    }

    async fn set_user_display_name(&self, auth0_subject: &str, display_name: String) -> User {
        let mut store = self.store.write().await;
        store.set_user_display_name(auth0_subject, display_name)
    }

    async fn create_server(&self, name: String, owner_subject: String) -> Server {
        let mut store = self.store.write().await;
        store.create_server(name, owner_subject)
    }

    async fn list_servers_for_user(&self, owner_subject: &str) -> Vec<Server> {
        let store = self.store.read().await;
        store
            .servers
            .values()
            .filter(|server| {
                store
                    .server_members_by_id
                    .get(&server.id)
                    .is_some_and(|members| members.iter().any(|subject| subject == owner_subject))
            })
            .cloned()
            .collect::<Vec<_>>()
    }

    async fn add_server_member(
        &self,
        server_id: Uuid,
        actor_subject: &str,
        user_subject: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.add_server_member(server_id, actor_subject, user_subject)
    }

    async fn delete_server(&self, server_id: Uuid, actor_subject: &str) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_server(server_id, actor_subject)
    }

    async fn list_server_members(&self, server_id: Uuid) -> Option<Vec<Membership>> {
        let store = self.store.read().await;
        store.list_server_members(server_id)
    }

    async fn create_channel(&self, server_id: Uuid, name: String) -> Option<Channel> {
        let mut store = self.store.write().await;
        store.create_channel(server_id, name)
    }

    async fn delete_channel(&self, channel_id: Uuid, actor_subject: &str) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_channel(channel_id, actor_subject)
    }

    async fn list_channels_for_server(&self, server_id: Uuid) -> Option<Vec<Channel>> {
        let store = self.store.read().await;

        if !store.servers.contains_key(&server_id) {
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

    async fn join_voice_session(
        &self,
        channel_id: Uuid,
        participant_subject: String,
    ) -> Option<VoiceSession> {
        let mut store = self.store.write().await;
        store.join_voice_session(channel_id, participant_subject)
    }

    async fn leave_voice_session(
        &self,
        channel_id: Uuid,
        participant_subject: &str,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.leave_voice_session(channel_id, participant_subject)
    }

    async fn list_voice_sessions(&self, channel_id: Uuid) -> Option<Vec<VoiceSession>> {
        let store = self.store.read().await;
        store.list_voice_sessions(channel_id)
    }
}

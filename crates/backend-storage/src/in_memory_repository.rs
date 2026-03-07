use async_trait::async_trait;
use backend_domain::{
    Channel, ChannelId, ChannelType, ExternalReference, Membership, Message, MessageId, Server,
    ServerId, User, UserId,
};
use tokio::sync::RwLock;

use crate::{
    ChannelRepository, CreateMessageResult, InMemoryStore, MessageRepository, MutationResult,
    NotificationRepository, ServerRepository, UserRepository,
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
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
    ) -> CreateMessageResult {
        let mut store = self.store.write().await;
        store.create_message(channel_id, author_user_id, content)
    }

    async fn update_message(
        &self,
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
        content: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.update_message(channel_id, message_id, author_user_id, content)
    }

    async fn delete_message(
        &self,
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_message(channel_id, message_id, author_user_id)
    }

    async fn list_messages(&self, channel_id: ChannelId) -> Vec<Message> {
        let store = self.store.read().await;
        store.list_messages(channel_id)
    }
}

#[async_trait]
impl UserRepository for InMemoryRepository {
    async fn find_user_by_id(&self, user_id: UserId) -> Option<User> {
        let store = self.store.read().await;
        store.find_user_by_id(user_id)
    }

    async fn find_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> Option<User> {
        let store = self.store.read().await;
        store.find_user_by_external_reference(external_reference)
    }

    async fn get_or_create_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> User {
        let mut store = self.store.write().await;
        store.get_or_create_user_by_external_reference(external_reference)
    }

    async fn set_user_display_name(&self, user_id: UserId, display_name: String) -> Option<User> {
        let mut store = self.store.write().await;
        store.set_user_display_name(user_id, display_name)
    }
}

#[async_trait]
impl ServerRepository for InMemoryRepository {
    async fn create_server(&self, name: String, owner_user_id: UserId) -> Server {
        let mut store = self.store.write().await;
        store.create_server(name, owner_user_id)
    }

    async fn list_servers_for_user(&self, user_id: UserId) -> Vec<Server> {
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

    async fn is_server_member(&self, server_id: ServerId, user_id: UserId) -> Option<bool> {
        let store = self.store.read().await;
        store.is_server_member(server_id, user_id)
    }

    async fn add_server_member(
        &self,
        server_id: ServerId,
        actor_user_id: UserId,
        user_id: UserId,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.add_server_member(server_id, actor_user_id, user_id)
    }

    async fn delete_server(&self, server_id: ServerId, actor_user_id: UserId) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_server(server_id, actor_user_id)
    }

    async fn list_server_members(&self, server_id: ServerId) -> Option<Vec<Membership>> {
        let store = self.store.read().await;
        store.list_server_members(server_id)
    }
}

#[async_trait]
impl ChannelRepository for InMemoryRepository {
    async fn create_channel(
        &self,
        server_id: ServerId,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel> {
        let mut store = self.store.write().await;
        store.create_channel(server_id, name, channel_type)
    }

    async fn update_channel_name(
        &self,
        channel_id: ChannelId,
        actor_user_id: UserId,
        name: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.update_channel_name(channel_id, actor_user_id, name)
    }

    async fn delete_channel(&self, channel_id: ChannelId, actor_user_id: UserId) -> MutationResult {
        let mut store = self.store.write().await;
        store.delete_channel(channel_id, actor_user_id)
    }

    async fn list_channels_for_server(&self, server_id: ServerId) -> Option<Vec<Channel>> {
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

    async fn find_channel_by_id(&self, channel_id: ChannelId) -> Option<Channel> {
        let store = self.store.read().await;
        store.channels.get(&channel_id).cloned()
    }

    async fn is_channel_member(&self, channel_id: ChannelId, user_id: UserId) -> Option<bool> {
        let store = self.store.read().await;
        store.is_channel_member(channel_id, user_id)
    }
}

#[async_trait]
impl NotificationRepository for InMemoryRepository {
    async fn unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId) -> u64 {
        let store = self.store.read().await;
        store
            .unread_counts_by_user_channel
            .get(&(user_id, channel_id))
            .copied()
            .unwrap_or(0)
    }

    async fn total_unread_count_for_user(&self, user_id: UserId) -> u64 {
        let store = self.store.read().await;
        store
            .unread_counts_by_user_channel
            .iter()
            .filter_map(|((entry_user_id, _), unread_count)| {
                if *entry_user_id == user_id {
                    Some(*unread_count)
                } else {
                    None
                }
            })
            .sum::<u64>()
    }

    async fn clear_unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId) {
        let mut store = self.store.write().await;
        store
            .unread_counts_by_user_channel
            .remove(&(user_id, channel_id));
    }

    async fn set_globally_muted_for_user(&self, user_id: UserId, muted: bool) {
        let mut store = self.store.write().await;
        store.set_globally_muted_for_user(user_id, muted);
    }

    async fn set_server_muted_for_user(&self, user_id: UserId, server_id: ServerId, muted: bool) {
        let mut store = self.store.write().await;
        store.set_server_muted_for_user(user_id, server_id, muted);
    }

    async fn set_channel_temporarily_muted_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        duration_minutes: u32,
    ) {
        let mut store = self.store.write().await;
        store.set_channel_temporarily_muted_for_user(user_id, channel_id, duration_minutes);
    }

    async fn expire_channel_mute_for_user(&self, user_id: UserId, channel_id: ChannelId) {
        let mut store = self.store.write().await;
        store.expire_channel_mute_for_user(user_id, channel_id);
    }

    async fn outbox_count_for_message_recipient(
        &self,
        message_id: MessageId,
        recipient_user_id: UserId,
    ) -> u64 {
        let store = self.store.read().await;
        let count = store
            .notification_outbox
            .iter()
            .filter(|(stored_message_id, _, stored_recipient_user_id, _)| {
                *stored_message_id == message_id && *stored_recipient_user_id == recipient_user_id
            })
            .count();

        u64::try_from(count).unwrap_or(0)
    }

    async fn outbox_total_count_for_recipient(&self, recipient_user_id: UserId) -> u64 {
        let store = self.store.read().await;
        let count = store
            .notification_outbox
            .iter()
            .filter(|(_, _, stored_recipient_user_id, _)| {
                *stored_recipient_user_id == recipient_user_id
            })
            .count();

        u64::try_from(count).unwrap_or(0)
    }
}

use async_trait::async_trait;
use backend_domain::{
    BlockRelationship, Channel, ChannelId, ChannelType, DirectMessage, DirectMessageThread,
    DirectMessageThreadId, DisplayName, EmoteId, ExternalReference, FriendNotificationEventType,
    FriendRequest, FriendRequestId, FriendRequestState, Friendship, Membership, Message, MessageId,
    NotificationCategoryPreference, NotificationMuteState, PinnedMessage, ReactionSummary, Server,
    ServerId, User, UserId,
};
use tokio::sync::RwLock;

use crate::{
    BlockRepository, BlockUserResult, ChannelRepository, CreateMessageResult,
    DirectMessageRepository, FriendRepository, InMemoryStore, MarkUnreadFromMessageResult,
    MessageRepository, MutationResult, NotificationRepository, OpenOrGetDirectMessageThreadResult,
    PinMessageResult, PinnedMessageRepository, ReactionRepository, SendDirectMessageResult,
    SendFriendRequestResult, ServerRepository, ToggleReactionResult, UnpinMessageResult,
    UpdateFriendRequestResult, UserRepository,
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
        mentioned_user_id: Option<UserId>,
    ) -> CreateMessageResult {
        let mut store = self.store.write().await;
        store.create_message(channel_id, author_user_id, content, mentioned_user_id)
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

    async fn search_messages(&self, channel_id: ChannelId, query: &str) -> Vec<Message> {
        let store = self.store.read().await;
        store.search_messages(channel_id, query)
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

    async fn set_user_display_name(&self, user_id: UserId, display_name: DisplayName) -> Option<User> {
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

    async fn update_server_name(
        &self,
        server_id: ServerId,
        actor_user_id: UserId,
        name: String,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.update_server_name(server_id, actor_user_id, name)
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

    async fn mark_unread_from_message(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        message_id: MessageId,
    ) -> MarkUnreadFromMessageResult {
        let mut store = self.store.write().await;

        let messages = match store.messages_by_channel.get(&channel_id) {
            Some(msgs) => msgs,
            None => return MarkUnreadFromMessageResult::MessageNotFound,
        };

        let target_index = match messages.iter().position(|m| m.id() == message_id) {
            Some(idx) => idx,
            None => return MarkUnreadFromMessageResult::MessageNotFound,
        };

        let unread_count = u64::try_from(messages.len() - target_index).unwrap_or(0);
        store
            .unread_counts_by_user_channel
            .insert((user_id, channel_id), unread_count);

        MarkUnreadFromMessageResult::Updated
    }

    async fn global_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference {
        let store = self.store.read().await;
        store.global_notification_category_for_user(user_id)
    }

    async fn global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference {
        let store = self.store.read().await;
        store.global_channel_default_notification_category_for_user(user_id)
    }

    async fn server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> Option<NotificationCategoryPreference> {
        let store = self.store.read().await;
        store.server_notification_category_for_user(user_id, server_id)
    }

    async fn channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<NotificationCategoryPreference> {
        let store = self.store.read().await;
        store.channel_notification_category_for_user(user_id, channel_id)
    }

    async fn set_global_notification_category_for_user(
        &self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    ) {
        let mut store = self.store.write().await;
        store.set_global_notification_category_for_user(user_id, category);
    }

    async fn set_global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    ) {
        let mut store = self.store.write().await;
        store.set_global_channel_default_notification_category_for_user(user_id, category);
    }

    async fn set_server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
        category: NotificationCategoryPreference,
    ) {
        let mut store = self.store.write().await;
        store.set_server_notification_category_for_user(user_id, server_id, category);
    }

    async fn set_channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        category: NotificationCategoryPreference,
    ) {
        let mut store = self.store.write().await;
        store.set_channel_notification_category_for_user(user_id, channel_id, category);
    }

    async fn clear_channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) {
        let mut store = self.store.write().await;
        store.clear_channel_notification_category_for_user(user_id, channel_id);
    }

    async fn global_mute_state_for_user(&self, user_id: UserId) -> NotificationMuteState {
        let store = self.store.read().await;
        store.global_mute_state_for_user(user_id)
    }

    async fn server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> NotificationMuteState {
        let store = self.store.read().await;
        store.server_mute_state_for_user(user_id, server_id)
    }

    async fn set_global_mute_state_for_user(
        &self,
        user_id: UserId,
        mute_state: NotificationMuteState,
    ) {
        let mut store = self.store.write().await;
        store.set_global_mute_state_for_user(user_id, mute_state);
    }

    async fn set_server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
        mute_state: NotificationMuteState,
    ) {
        let mut store = self.store.write().await;
        store.set_server_mute_state_for_user(user_id, server_id, mute_state);
    }

    async fn channel_temporary_mute_expires_at_epoch_seconds(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<u64> {
        let store = self.store.read().await;
        store.channel_temporary_mute_expires_at_epoch_seconds(user_id, channel_id)
    }

    async fn set_channel_temporary_mute_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        duration_minutes: u32,
    ) {
        let mut store = self.store.write().await;
        store.set_channel_temporary_mute_for_user(user_id, channel_id, duration_minutes);
    }

    async fn clear_channel_temporary_mute_for_user(&self, user_id: UserId, channel_id: ChannelId) {
        let mut store = self.store.write().await;
        store.clear_channel_temporary_mute_for_user(user_id, channel_id);
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
            .filter(|(stored_message_id, _, stored_recipient_user_id, _, _)| {
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
            .filter(|(_, _, stored_recipient_user_id, _, _)| {
                *stored_recipient_user_id == recipient_user_id
            })
            .count();

        u64::try_from(count).unwrap_or(0)
    }

    async fn outbox_count_for_friend_notification(
        &self,
        recipient_user_id: UserId,
        actor_user_id: UserId,
        event_type: FriendNotificationEventType,
    ) -> u64 {
        let store = self.store.read().await;
        let count = store
            .friend_notification_outbox
            .iter()
            .filter(
                |(_, stored_recipient_user_id, stored_actor_user_id, stored_event_type)| {
                    *stored_recipient_user_id == recipient_user_id
                        && *stored_actor_user_id == actor_user_id
                        && *stored_event_type == event_type
                },
            )
            .count();

        u64::try_from(count).unwrap_or(0)
    }
}

#[async_trait]
impl FriendRepository for InMemoryRepository {
    async fn send_friend_request(
        &self,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    ) -> SendFriendRequestResult {
        let mut store = self.store.write().await;
        store.send_friend_request(requester_user_id, addressee_user_id)
    }

    async fn set_friend_request_state(
        &self,
        actor_user_id: UserId,
        friend_request_id: FriendRequestId,
        state: FriendRequestState,
    ) -> UpdateFriendRequestResult {
        let mut store = self.store.write().await;
        store.set_friend_request_state(actor_user_id, friend_request_id, state)
    }

    async fn list_friendships_for_user(&self, user_id: UserId) -> Vec<Friendship> {
        let store = self.store.read().await;
        store.list_friendships_for_user(user_id)
    }

    async fn list_pending_incoming_friend_requests(&self, user_id: UserId) -> Vec<FriendRequest> {
        let store = self.store.read().await;
        store.list_pending_incoming_friend_requests(user_id)
    }

    async fn list_pending_outgoing_friend_requests(&self, user_id: UserId) -> Vec<FriendRequest> {
        let store = self.store.read().await;
        store.list_pending_outgoing_friend_requests(user_id)
    }

    async fn are_friends(&self, user_id: UserId, other_user_id: UserId) -> bool {
        let store = self.store.read().await;
        store.are_friends(user_id, other_user_id)
    }
}

#[async_trait]
impl BlockRepository for InMemoryRepository {
    async fn block_user(
        &self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> BlockUserResult {
        let mut store = self.store.write().await;
        store.block_user(blocker_user_id, blocked_user_id)
    }

    async fn unblock_user(
        &self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> MutationResult {
        let mut store = self.store.write().await;
        store.unblock_user(blocker_user_id, blocked_user_id)
    }

    async fn list_blocked_users(&self, blocker_user_id: UserId) -> Vec<BlockRelationship> {
        let store = self.store.read().await;
        store.list_blocked_users(blocker_user_id)
    }

    async fn users_are_blocked(&self, user_id: UserId, other_user_id: UserId) -> bool {
        let store = self.store.read().await;
        store.users_are_blocked(user_id, other_user_id)
    }
}

#[async_trait]
impl DirectMessageRepository for InMemoryRepository {
    async fn open_or_get_direct_message_thread(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
    ) -> OpenOrGetDirectMessageThreadResult {
        let mut store = self.store.write().await;
        store.open_or_get_direct_message_thread(actor_user_id, other_user_id)
    }

    async fn list_direct_message_threads_for_user(
        &self,
        user_id: UserId,
    ) -> Vec<DirectMessageThread> {
        let store = self.store.read().await;
        store.list_direct_message_threads_for_user(user_id)
    }

    async fn send_direct_message(
        &self,
        actor_user_id: UserId,
        thread_id: DirectMessageThreadId,
        content: String,
    ) -> SendDirectMessageResult {
        let mut store = self.store.write().await;
        store.send_direct_message(actor_user_id, thread_id, content)
    }

    async fn list_direct_messages(
        &self,
        actor_user_id: UserId,
        thread_id: DirectMessageThreadId,
    ) -> Option<Vec<DirectMessage>> {
        let store = self.store.read().await;
        store.list_direct_messages(actor_user_id, thread_id)
    }

    async fn search_direct_messages_for_person(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
        query: &str,
    ) -> Option<Vec<DirectMessage>> {
        let store = self.store.read().await;
        store.search_direct_messages_for_person(actor_user_id, other_user_id, query)
    }
}

#[async_trait]
impl ReactionRepository for InMemoryRepository {
    async fn toggle_reaction(
        &self,
        message_id: MessageId,
        user_id: UserId,
        emote_id: &EmoteId,
    ) -> ToggleReactionResult {
        let mut store = self.store.write().await;
        store.toggle_reaction(message_id, user_id, emote_id)
    }

    async fn list_reaction_summaries(
        &self,
        message_id: MessageId,
        current_user_id: UserId,
    ) -> Vec<ReactionSummary> {
        let store = self.store.read().await;
        store.list_reaction_summaries(message_id, current_user_id)
    }
}

#[async_trait]
impl PinnedMessageRepository for InMemoryRepository {
    async fn pin_message(
        &self,
        server_id: ServerId,
        message_id: MessageId,
        pinned_by_user_id: UserId,
    ) -> PinMessageResult {
        let mut store = self.store.write().await;
        store.pin_message(server_id, message_id, pinned_by_user_id)
    }

    async fn unpin_message(
        &self,
        server_id: ServerId,
        message_id: MessageId,
    ) -> UnpinMessageResult {
        let mut store = self.store.write().await;
        store.unpin_message(server_id, message_id)
    }

    async fn list_pinned_messages(&self, server_id: ServerId) -> Vec<PinnedMessage> {
        let store = self.store.read().await;
        store.list_pinned_messages(server_id)
    }
}

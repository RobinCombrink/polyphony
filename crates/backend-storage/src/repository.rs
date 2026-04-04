use async_trait::async_trait;
use backend_domain::{
    BlockRelationship, Channel, ChannelId, ChannelType, DirectMessage, DirectMessageThread,
    DisplayName, EmoteId, ExternalReference, FriendNotificationEventType, FriendRequest,
    FriendRequestId, FriendRequestState, Friendship, Membership, Message, MessageId,
    NotificationCategoryPreference, NotificationMuteState, PinnedMessage, ReactionSummary, Server,
    ServerId, User, UserId,
};

use crate::MutationResult;

pub enum CreateMessageResult {
    Created {
        message: Message,
        notified_user_ids: Vec<UserId>,
    },
    Forbidden,
    ChannelKindMismatch,
    NotFound,
}

pub enum SendFriendRequestResult {
    Created(FriendRequest),
    AlreadyFriends,
    AlreadyPending,
    Blocked,
    Forbidden,
    NotFound,
}

pub enum UpdateFriendRequestResult {
    Updated(FriendRequest),
    Forbidden,
    NotFound,
    InvalidState,
}

pub enum BlockUserResult {
    Created(BlockRelationship),
    AlreadyBlocked,
    Forbidden,
    NotFound,
}

pub enum OpenOrGetDirectMessageThreadResult {
    Opened(DirectMessageThread),
    Blocked,
    Forbidden,
    NotFound,
}

pub enum SendDirectMessageResult {
    Created(DirectMessage),
    Blocked,
    Forbidden,
    NotFound,
}

pub enum MarkUnreadFromMessageResult {
    Updated,
    MessageNotFound,
}

#[async_trait]
pub trait NotificationRepository: Send + Sync {
    async fn unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId) -> u64;
    async fn total_unread_count_for_user(&self, user_id: UserId) -> u64;
    async fn clear_unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId);
    async fn mark_unread_from_message(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        message_id: MessageId,
    ) -> MarkUnreadFromMessageResult;
    async fn global_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference;
    async fn global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference;
    async fn server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> Option<NotificationCategoryPreference>;
    async fn channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<NotificationCategoryPreference>;
    async fn set_global_notification_category_for_user(
        &self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    );
    async fn set_global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    );
    async fn set_server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
        category: NotificationCategoryPreference,
    );
    async fn set_channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        category: NotificationCategoryPreference,
    );
    async fn clear_channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    );

    async fn global_mute_state_for_user(&self, user_id: UserId) -> NotificationMuteState;
    async fn server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> NotificationMuteState;
    async fn set_global_mute_state_for_user(
        &self,
        user_id: UserId,
        mute_state: NotificationMuteState,
    );
    async fn set_server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
        mute_state: NotificationMuteState,
    );
    async fn channel_temporary_mute_expires_at_epoch_seconds(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<u64>;
    async fn set_channel_temporary_mute_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        duration_minutes: u32,
    );
    async fn clear_channel_temporary_mute_for_user(&self, user_id: UserId, channel_id: ChannelId);
    async fn outbox_count_for_message_recipient(
        &self,
        message_id: MessageId,
        recipient_user_id: UserId,
    ) -> u64;
    async fn outbox_total_count_for_recipient(&self, recipient_user_id: UserId) -> u64;
    async fn outbox_count_for_friend_notification(
        &self,
        recipient_user_id: UserId,
        actor_user_id: UserId,
        event_type: FriendNotificationEventType,
    ) -> u64;
}

#[async_trait]
pub trait MessageRepository: Send + Sync {
    async fn create_message(
        &self,
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
        mentioned_user_id: Option<UserId>,
    ) -> CreateMessageResult;
    async fn update_message(
        &self,
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
        content: String,
    ) -> MutationResult;
    async fn delete_message(
        &self,
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
    ) -> MutationResult;
    async fn list_messages(&self, channel_id: ChannelId) -> Vec<Message>;
    async fn search_messages(&self, channel_id: ChannelId, query: &str) -> Vec<Message>;
}

#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find_user_by_id(&self, user_id: UserId) -> Option<User>;
    async fn find_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> Option<User>;
    async fn get_or_create_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> User;
    async fn set_user_display_name(&self, user_id: UserId, display_name: DisplayName) -> Option<User>;
}

#[async_trait]
pub trait ServerRepository: Send + Sync {
    async fn create_server(&self, name: String, owner_user_id: UserId) -> Server;
    async fn list_servers_for_user(&self, user_id: UserId) -> Vec<Server>;
    async fn is_server_member(&self, server_id: ServerId, user_id: UserId) -> Option<bool>;
    async fn add_server_member(
        &self,
        server_id: ServerId,
        actor_user_id: UserId,
        user_id: UserId,
    ) -> MutationResult;
    async fn update_server_name(
        &self,
        server_id: ServerId,
        actor_user_id: UserId,
        name: String,
    ) -> MutationResult;
    async fn delete_server(&self, server_id: ServerId, actor_user_id: UserId) -> MutationResult;
    async fn list_server_members(&self, server_id: ServerId) -> Option<Vec<Membership>>;
}

#[async_trait]
pub trait ChannelRepository: Send + Sync {
    async fn create_channel(
        &self,
        server_id: ServerId,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel>;
    async fn update_channel_name(
        &self,
        channel_id: ChannelId,
        actor_user_id: UserId,
        name: String,
    ) -> MutationResult;
    async fn delete_channel(&self, channel_id: ChannelId, actor_user_id: UserId) -> MutationResult;
    async fn list_channels_for_server(&self, server_id: ServerId) -> Option<Vec<Channel>>;
    async fn find_channel_by_id(&self, channel_id: ChannelId) -> Option<Channel>;
    async fn is_channel_member(&self, channel_id: ChannelId, user_id: UserId) -> Option<bool>;
}

#[async_trait]
pub trait FriendRepository: Send + Sync {
    async fn send_friend_request(
        &self,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    ) -> SendFriendRequestResult;
    async fn set_friend_request_state(
        &self,
        actor_user_id: UserId,
        friend_request_id: FriendRequestId,
        state: FriendRequestState,
    ) -> UpdateFriendRequestResult;
    async fn list_friendships_for_user(&self, user_id: UserId) -> Vec<Friendship>;
    async fn list_pending_incoming_friend_requests(&self, user_id: UserId) -> Vec<FriendRequest>;
    async fn list_pending_outgoing_friend_requests(&self, user_id: UserId) -> Vec<FriendRequest>;
    async fn are_friends(&self, user_id: UserId, other_user_id: UserId) -> bool;
}

#[async_trait]
pub trait BlockRepository: Send + Sync {
    async fn block_user(&self, blocker_user_id: UserId, blocked_user_id: UserId)
    -> BlockUserResult;
    async fn unblock_user(
        &self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> MutationResult;
    async fn list_blocked_users(&self, blocker_user_id: UserId) -> Vec<BlockRelationship>;
    async fn users_are_blocked(&self, user_id: UserId, other_user_id: UserId) -> bool;
}

#[async_trait]
pub trait DirectMessageRepository: Send + Sync {
    async fn open_or_get_direct_message_thread(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
    ) -> OpenOrGetDirectMessageThreadResult;
    async fn list_direct_message_threads_for_user(
        &self,
        user_id: UserId,
    ) -> Vec<DirectMessageThread>;
    async fn send_direct_message(
        &self,
        actor_user_id: UserId,
        thread_id: backend_domain::DirectMessageThreadId,
        content: String,
    ) -> SendDirectMessageResult;
    async fn list_direct_messages(
        &self,
        actor_user_id: UserId,
        thread_id: backend_domain::DirectMessageThreadId,
    ) -> Option<Vec<DirectMessage>>;
    async fn search_direct_messages_for_person(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
        query: &str,
    ) -> Option<Vec<DirectMessage>>;
}

pub enum ToggleReactionResult {
    Added,
    Removed,
    MessageNotFound,
}

#[async_trait]
pub trait ReactionRepository: Send + Sync {
    async fn toggle_reaction(
        &self,
        message_id: MessageId,
        user_id: UserId,
        emote_id: &EmoteId,
    ) -> ToggleReactionResult;

    async fn list_reaction_summaries(
        &self,
        message_id: MessageId,
        current_user_id: UserId,
    ) -> Vec<ReactionSummary>;
}

pub enum PinMessageResult {
    Pinned,
    AlreadyPinned,
    MessageNotFound,
}

pub enum UnpinMessageResult {
    Unpinned,
    NotPinned,
}

#[async_trait]
pub trait PinnedMessageRepository: Send + Sync {
    async fn pin_message(
        &self,
        server_id: ServerId,
        message_id: MessageId,
        pinned_by_user_id: UserId,
    ) -> PinMessageResult;

    async fn unpin_message(&self, server_id: ServerId, message_id: MessageId)
    -> UnpinMessageResult;

    async fn list_pinned_messages(&self, server_id: ServerId) -> Vec<PinnedMessage>;
}

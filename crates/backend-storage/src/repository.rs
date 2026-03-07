use async_trait::async_trait;
use backend_domain::{
    Channel, ChannelId, ChannelType, ExternalReference, Membership, Message, MessageId,
    NotificationCategoryPreference, NotificationMuteState, Server, ServerId, User, UserId,
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

#[async_trait]
pub trait NotificationRepository: Send + Sync {
    async fn unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId) -> u64;
    async fn total_unread_count_for_user(&self, user_id: UserId) -> u64;
    async fn clear_unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId);
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
    async fn set_user_display_name(&self, user_id: UserId, display_name: String) -> Option<User>;
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

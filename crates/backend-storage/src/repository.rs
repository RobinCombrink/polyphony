use async_trait::async_trait;
use backend_domain::{
    Channel, ChannelId, ChannelType, ExternalReference, Membership, Message, MessageId, Server,
    ServerId, User, UserId,
};

use crate::MutationResult;

pub enum CreateMessageResult {
    Created(Message),
    Forbidden,
    ChannelKindMismatch,
    NotFound,
}

#[async_trait]
pub trait MessageRepository: Send + Sync {
    async fn create_message(
        &self,
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
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

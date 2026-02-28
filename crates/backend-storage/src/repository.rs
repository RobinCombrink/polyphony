use async_trait::async_trait;
use backend_domain::{Channel, Membership, Message, Server, User, VoiceSession};
use uuid::Uuid;

use crate::MutationResult;

#[async_trait]
pub trait MessageRepository: Send + Sync {
    async fn create_message(
        &self,
        channel_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> Option<Message>;
    async fn update_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> MutationResult;
    async fn delete_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
    ) -> MutationResult;
    async fn list_messages(&self, channel_id: Uuid) -> Vec<Message>;
}

#[async_trait]
pub trait UserRepository: Send + Sync {
    async fn find_user_by_id(&self, user_id: Uuid) -> Option<User>;
    async fn find_user_by_external_reference(&self, external_reference: &str) -> Option<User>;
    async fn get_or_create_user_by_external_reference(&self, external_reference: &str) -> User;
    async fn set_user_display_name(&self, user_id: Uuid, display_name: String) -> Option<User>;
}

#[async_trait]
pub trait ServerRepository: Send + Sync {
    async fn create_server(&self, name: String, owner_user_id: Uuid) -> Server;
    async fn list_servers_for_user(&self, user_id: Uuid) -> Vec<Server>;
    async fn add_server_member(
        &self,
        server_id: Uuid,
        actor_user_id: Uuid,
        user_id: Uuid,
    ) -> MutationResult;
    async fn delete_server(&self, server_id: Uuid, actor_user_id: Uuid) -> MutationResult;
    async fn list_server_members(&self, server_id: Uuid) -> Option<Vec<Membership>>;
}

#[async_trait]
pub trait ChatRepository: Send + Sync {
    async fn create_channel(&self, server_id: Uuid, name: String) -> Option<Channel>;
    async fn delete_channel(&self, channel_id: Uuid, actor_user_id: Uuid) -> MutationResult;
    async fn list_channels_for_server(&self, server_id: Uuid) -> Option<Vec<Channel>>;
    async fn join_voice_session(
        &self,
        channel_id: Uuid,
        participant_user_id: Uuid,
    ) -> Option<VoiceSession>;
    async fn leave_voice_session(
        &self,
        channel_id: Uuid,
        participant_user_id: Uuid,
    ) -> MutationResult;
    async fn set_voice_session_muted(
        &self,
        channel_id: Uuid,
        participant_user_id: Uuid,
        is_muted: bool,
    ) -> MutationResult;
    async fn list_voice_sessions(&self, channel_id: Uuid) -> Option<Vec<VoiceSession>>;
}

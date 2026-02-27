use async_trait::async_trait;
use backend_domain::{Channel, Membership, Message, Server, User, VoiceSession};

use crate::MutationResult;

#[async_trait]
pub trait ChatRepository: Send + Sync {
    async fn get_or_create_user(&self, auth0_subject: &str) -> User;
    async fn set_user_display_name(&self, auth0_subject: &str, display_name: String) -> User;
    async fn create_server(&self, name: String, owner_subject: String) -> Server;
    async fn list_servers_for_user(&self, owner_subject: &str) -> Vec<Server>;
    async fn add_server_member(
        &self,
        server_id: &str,
        actor_subject: &str,
        user_subject: String,
    ) -> MutationResult;
    async fn list_server_members(&self, server_id: &str) -> Option<Vec<Membership>>;
    async fn create_channel(&self, server_id: &str, name: String) -> Option<Channel>;
    async fn list_channels_for_server(&self, server_id: &str) -> Option<Vec<Channel>>;
    async fn create_message(
        &self,
        channel_id: &str,
        author_subject: String,
        content: String,
    ) -> Option<Message>;
    async fn update_message(
        &self,
        channel_id: &str,
        message_id: &str,
        author_subject: &str,
        content: String,
    ) -> MutationResult;
    async fn delete_message(
        &self,
        channel_id: &str,
        message_id: &str,
        author_subject: &str,
    ) -> MutationResult;
    async fn list_messages(&self, channel_id: &str) -> Vec<Message>;
    async fn join_voice_session(
        &self,
        channel_id: &str,
        participant_subject: String,
    ) -> Option<VoiceSession>;
    async fn leave_voice_session(
        &self,
        channel_id: &str,
        participant_subject: &str,
    ) -> MutationResult;
    async fn list_voice_sessions(&self, channel_id: &str) -> Option<Vec<VoiceSession>>;
}

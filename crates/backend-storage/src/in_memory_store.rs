use std::collections::HashMap;

use backend_domain::{Channel, ChannelType, DisplayName, Membership, Message, Server, User};
use uuid::Uuid;

use crate::MutationResult;

#[derive(Debug, Default)]
pub(crate) struct InMemoryStore {
    pub(crate) users_by_id: HashMap<Uuid, User>,
    pub(crate) user_id_by_external_reference: HashMap<String, Uuid>,
    pub(crate) servers: HashMap<Uuid, Server>,
    pub(crate) server_members_by_id: HashMap<Uuid, Vec<Uuid>>,
    pub(crate) channels: HashMap<Uuid, Channel>,
    pub(crate) messages_by_channel: HashMap<Uuid, Vec<Message>>,
}

impl InMemoryStore {
    pub(crate) fn find_user_by_id(&self, user_id: Uuid) -> Option<User> {
        self.users_by_id.get(&user_id).cloned()
    }

    pub(crate) fn find_user_by_external_reference(&self, external_reference: &str) -> Option<User> {
        let user_id = self.user_id_by_external_reference.get(external_reference)?;
        self.users_by_id.get(user_id).cloned()
    }

    pub(crate) fn get_or_create_user_by_external_reference(
        &mut self,
        external_reference: &str,
    ) -> User {
        if let Some(existing_user) = self.find_user_by_external_reference(external_reference) {
            return existing_user.clone();
        }

        let user = User {
            id: Uuid::new_v4(),
            external_reference: external_reference.to_owned(),
            display_name: None,
        };

        self.user_id_by_external_reference
            .insert(external_reference.to_owned(), user.id);
        self.users_by_id.insert(user.id, user.clone());

        user
    }

    pub(crate) fn set_user_display_name(
        &mut self,
        user_id: Uuid,
        display_name: String,
    ) -> Option<User> {
        let mut user = self.find_user_by_id(user_id)?;
        user.display_name = Some(DisplayName::new(display_name));
        self.users_by_id.insert(user_id, user.clone());
        Some(user)
    }

    pub(crate) fn create_server(&mut self, name: String, owner_user_id: Uuid) -> Server {
        let server_id = Uuid::new_v4();
        let server = Server {
            id: server_id,
            name,
            owner_user_id,
        };

        self.servers.insert(server.id, server.clone());
        self.server_members_by_id
            .insert(server.id, vec![owner_user_id]);
        server
    }

    pub(crate) fn add_server_member(
        &mut self,
        server_id: Uuid,
        actor_user_id: Uuid,
        user_id: Uuid,
    ) -> MutationResult {
        let server = match self.servers.get(&server_id) {
            Some(existing_server) => existing_server,
            None => return MutationResult::NotFound,
        };

        if server.owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        let members = self
            .server_members_by_id
            .entry(server_id)
            .or_insert_with(|| vec![server.owner_user_id]);

        if !members.contains(&user_id) {
            members.push(user_id);
        }

        MutationResult::Updated
    }

    pub(crate) fn delete_server(&mut self, server_id: Uuid, actor_user_id: Uuid) -> MutationResult {
        let server = match self.servers.get(&server_id) {
            Some(existing_server) => existing_server,
            None => return MutationResult::NotFound,
        };

        if server.owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        self.servers.remove(&server_id);
        self.server_members_by_id.remove(&server_id);

        let channel_ids = self
            .channels
            .values()
            .filter(|channel| channel.server_id() == server_id)
            .map(Channel::id)
            .collect::<Vec<_>>();

        for channel_id in channel_ids {
            self.channels.remove(&channel_id);
            self.messages_by_channel.remove(&channel_id);
        }

        MutationResult::Deleted
    }

    pub(crate) fn list_server_members(&self, server_id: Uuid) -> Option<Vec<Membership>> {
        if !self.servers.contains_key(&server_id) {
            return None;
        }

        let members = self
            .server_members_by_id
            .get(&server_id)
            .map(|user_ids| {
                user_ids
                    .iter()
                    .map(|user_id| Membership {
                        user_id: *user_id,
                        server_id,
                    })
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();

        Some(members)
    }

    pub(crate) fn create_channel(
        &mut self,
        server_id: Uuid,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel> {
        if !self.servers.contains_key(&server_id) {
            return None;
        }

        let channel_id = Uuid::new_v4();
        let channel = match channel_type {
            ChannelType::Text => Channel::new_text(channel_id, server_id, name),
            ChannelType::Voice => Channel::new_voice(channel_id, server_id, name),
        };

        self.channels.insert(channel.id(), channel.clone());
        Some(channel)
    }

    pub(crate) fn update_channel_name(
        &mut self,
        channel_id: Uuid,
        actor_user_id: Uuid,
        name: String,
    ) -> MutationResult {
        let server_id = if let Some(existing_channel) = self.channels.get(&channel_id) {
            existing_channel.server_id()
        } else {
            return MutationResult::NotFound;
        };

        let server = match self.servers.get(&server_id) {
            Some(existing_server) => existing_server,
            None => return MutationResult::NotFound,
        };

        if server.owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        match self.channels.get_mut(&channel_id) {
            Some(Channel::Text {
                name: channel_name, ..
            })
            | Some(Channel::Voice {
                name: channel_name, ..
            }) => {
                *channel_name = name;
                MutationResult::Updated
            }
            None => MutationResult::NotFound,
        }
    }

    pub(crate) fn delete_channel(
        &mut self,
        channel_id: Uuid,
        actor_user_id: Uuid,
    ) -> MutationResult {
        let server_id = if let Some(existing_channel) = self.channels.get(&channel_id) {
            existing_channel.server_id()
        } else {
            return MutationResult::NotFound;
        };

        let server = match self.servers.get(&server_id) {
            Some(existing_server) => existing_server,
            None => return MutationResult::NotFound,
        };

        if server.owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        self.channels.remove(&channel_id);
        self.messages_by_channel.remove(&channel_id);

        MutationResult::Deleted
    }

    pub(crate) fn create_message(
        &mut self,
        channel_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> Option<Message> {
        let channel_type = self.channels.get(&channel_id).map(Channel::kind);
        if channel_type != Some(ChannelType::Text) {
            return None;
        }

        let message = Message {
            id: Uuid::new_v4(),
            channel_id,
            author_user_id,
            content,
        };

        self.messages_by_channel
            .entry(channel_id)
            .or_default()
            .push(message.clone());

        Some(message)
    }

    pub(crate) fn list_messages(&self, channel_id: Uuid) -> Vec<Message> {
        self.messages_by_channel
            .get(&channel_id)
            .cloned()
            .unwrap_or_default()
    }

    pub(crate) fn update_message(
        &mut self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> MutationResult {
        let messages = match self.messages_by_channel.get_mut(&channel_id) {
            Some(existing_messages) => existing_messages,
            None => return MutationResult::NotFound,
        };

        let maybe_message = messages.iter_mut().find(|message| message.id == message_id);

        match maybe_message {
            Some(message) if message.author_user_id == author_user_id => {
                message.content = content;
                MutationResult::Updated
            }
            Some(_) => MutationResult::Forbidden,
            None => MutationResult::NotFound,
        }
    }

    pub(crate) fn delete_message(
        &mut self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
    ) -> MutationResult {
        let messages = match self.messages_by_channel.get_mut(&channel_id) {
            Some(existing_messages) => existing_messages,
            None => return MutationResult::NotFound,
        };

        let message_index = messages.iter().position(|message| message.id == message_id);

        match message_index {
            Some(index) if messages[index].author_user_id == author_user_id => {
                messages.remove(index);
                MutationResult::Deleted
            }
            Some(_) => MutationResult::Forbidden,
            None => MutationResult::NotFound,
        }
    }

}

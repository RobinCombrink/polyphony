use std::collections::HashMap;

use backend_domain::{
    Channel, ChannelId, ChannelType, DisplayName, ExternalReference, Membership, Message,
    MessageId, Server, ServerId, User, UserId,
};
use uuid::Uuid;

use crate::{CreateMessageResult, MutationResult};

#[derive(Debug, Default)]
pub(crate) struct InMemoryStore {
    pub(crate) users_by_id: HashMap<UserId, User>,
    pub(crate) user_id_by_external_reference: HashMap<ExternalReference, UserId>,
    pub(crate) servers: HashMap<ServerId, Server>,
    pub(crate) server_members_by_id: HashMap<ServerId, Vec<UserId>>,
    pub(crate) channels: HashMap<ChannelId, Channel>,
    pub(crate) messages_by_channel: HashMap<ChannelId, Vec<Message>>,
    pub(crate) notification_outbox: Vec<(MessageId, ChannelId, UserId, UserId)>,
    pub(crate) unread_counts_by_user_channel: HashMap<(UserId, ChannelId), u64>,
}

impl InMemoryStore {
    pub(crate) fn is_server_member(&self, server_id: ServerId, user_id: UserId) -> Option<bool> {
        if !self.servers.contains_key(&server_id) {
            return None;
        }

        let is_member = self
            .server_members_by_id
            .get(&server_id)
            .is_some_and(|members| members.contains(&user_id));

        Some(is_member)
    }

    pub(crate) fn is_channel_member(&self, channel_id: ChannelId, user_id: UserId) -> Option<bool> {
        let server_id = self.channels.get(&channel_id).map(Channel::server_id)?;
        self.is_server_member(server_id, user_id)
    }

    pub(crate) fn find_user_by_id(&self, user_id: UserId) -> Option<User> {
        self.users_by_id.get(&user_id).cloned()
    }

    pub(crate) fn find_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> Option<User> {
        let user_id = self.user_id_by_external_reference.get(external_reference)?;
        self.users_by_id.get(user_id).cloned()
    }

    pub(crate) fn get_or_create_user_by_external_reference(
        &mut self,
        external_reference: &ExternalReference,
    ) -> User {
        if let Some(existing_user) = self.find_user_by_external_reference(external_reference) {
            return existing_user.clone();
        }

        let user = User {
            id: Uuid::new_v4().into(),
            external_reference: external_reference.clone(),
            display_name: None,
        };

        self.user_id_by_external_reference
            .insert(external_reference.clone(), user.id);
        self.users_by_id.insert(user.id, user.clone());

        user
    }

    pub(crate) fn set_user_display_name(
        &mut self,
        user_id: UserId,
        display_name: String,
    ) -> Option<User> {
        let mut user = self.find_user_by_id(user_id)?;
        user.display_name = Some(DisplayName::new(display_name));
        self.users_by_id.insert(user_id, user.clone());
        Some(user)
    }

    pub(crate) fn create_server(&mut self, name: String, owner_user_id: UserId) -> Server {
        let server_id: ServerId = Uuid::new_v4().into();
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
        server_id: ServerId,
        actor_user_id: UserId,
        user_id: UserId,
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

    pub(crate) fn delete_server(
        &mut self,
        server_id: ServerId,
        actor_user_id: UserId,
    ) -> MutationResult {
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

    pub(crate) fn list_server_members(&self, server_id: ServerId) -> Option<Vec<Membership>> {
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
        server_id: ServerId,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel> {
        if !self.servers.contains_key(&server_id) {
            return None;
        }

        let channel_id: ChannelId = Uuid::new_v4().into();
        let channel = match channel_type {
            ChannelType::Text => Channel::new_text(channel_id, server_id, name),
            ChannelType::Voice => Channel::new_voice(channel_id, server_id, name),
        };

        self.channels.insert(channel.id(), channel.clone());
        Some(channel)
    }

    pub(crate) fn update_channel_name(
        &mut self,
        channel_id: ChannelId,
        actor_user_id: UserId,
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
        channel_id: ChannelId,
        actor_user_id: UserId,
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
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
    ) -> CreateMessageResult {
        let Some(channel) = self.channels.get(&channel_id).cloned() else {
            return CreateMessageResult::NotFound;
        };

        let channel_type = channel.kind();

        if channel_type != ChannelType::Text {
            return CreateMessageResult::ChannelKindMismatch;
        }

        let is_channel_member = self
            .is_channel_member(channel_id, author_user_id)
            .unwrap_or(false);

        if !is_channel_member {
            return CreateMessageResult::Forbidden;
        }

        let message = Message {
            id: Uuid::new_v4().into(),
            channel_id,
            author_user_id,
            content,
        };

        self.messages_by_channel
            .entry(channel_id)
            .or_default()
            .push(message.clone());

        let server_id = channel.server_id();
        let notified_user_ids = self
            .server_members_by_id
            .get(&server_id)
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter(|user_id| *user_id != author_user_id)
            .collect::<Vec<_>>();

        for recipient_user_id in &notified_user_ids {
            self.notification_outbox
                .push((message.id, channel_id, *recipient_user_id, author_user_id));

            let unread_count = self
                .unread_counts_by_user_channel
                .entry((*recipient_user_id, channel_id))
                .or_insert(0);
            *unread_count += 1;
        }

        CreateMessageResult::Created {
            message,
            notified_user_ids,
        }
    }

    pub(crate) fn list_messages(&self, channel_id: ChannelId) -> Vec<Message> {
        self.messages_by_channel
            .get(&channel_id)
            .cloned()
            .unwrap_or_default()
    }

    pub(crate) fn update_message(
        &mut self,
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
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
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
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

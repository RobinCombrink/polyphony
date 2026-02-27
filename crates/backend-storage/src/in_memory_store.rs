use std::collections::HashMap;

use backend_domain::{Channel, DisplayName, Membership, Message, Server, User, VoiceSession};

use crate::MutationResult;

#[derive(Debug, Default)]
pub(crate) struct InMemoryStore {
    pub(crate) next_server_id: u64,
    pub(crate) next_channel_id: u64,
    pub(crate) next_message_id: u64,
    pub(crate) users_by_subject: HashMap<String, User>,
    pub(crate) servers: HashMap<String, Server>,
    pub(crate) server_members_by_id: HashMap<String, Vec<String>>,
    pub(crate) channels: HashMap<String, Channel>,
    pub(crate) messages_by_channel: HashMap<String, Vec<Message>>,
    pub(crate) voice_participants_by_channel: HashMap<String, Vec<String>>,
}

impl InMemoryStore {
    pub(crate) fn get_or_create_user(&mut self, auth0_subject: &str) -> User {
        if let Some(existing_user) = self.users_by_subject.get(auth0_subject) {
            return existing_user.clone();
        }

        let user = User {
            auth0_subject: auth0_subject.to_owned(),
            display_name: None,
        };

        self.users_by_subject
            .insert(auth0_subject.to_owned(), user.clone());

        user
    }

    pub(crate) fn set_user_display_name(
        &mut self,
        auth0_subject: &str,
        display_name: String,
    ) -> User {
        let mut user = self.get_or_create_user(auth0_subject);
        user.display_name = Some(DisplayName::new(display_name));
        self.users_by_subject
            .insert(auth0_subject.to_owned(), user.clone());
        user
    }

    pub(crate) fn create_server(&mut self, name: String, owner_subject: String) -> Server {
        self.next_server_id += 1;
        let server = Server {
            id: format!("srv-{}", self.next_server_id),
            name,
            owner_subject: owner_subject.clone(),
        };

        self.servers.insert(server.id.clone(), server.clone());
        self.server_members_by_id
            .insert(server.id.clone(), vec![owner_subject]);
        server
    }

    pub(crate) fn add_server_member(
        &mut self,
        server_id: &str,
        actor_subject: &str,
        user_subject: String,
    ) -> MutationResult {
        let server = match self.servers.get(server_id) {
            Some(existing_server) => existing_server,
            None => return MutationResult::NotFound,
        };

        if server.owner_subject != actor_subject {
            return MutationResult::Forbidden;
        }

        let members = self
            .server_members_by_id
            .entry(server_id.to_owned())
            .or_insert_with(|| vec![server.owner_subject.clone()]);

        if !members.contains(&user_subject) {
            members.push(user_subject);
        }

        MutationResult::Updated
    }

    pub(crate) fn list_server_members(&self, server_id: &str) -> Option<Vec<Membership>> {
        if !self.servers.contains_key(server_id) {
            return None;
        }

        let members = self
            .server_members_by_id
            .get(server_id)
            .map(|subjects| {
                subjects
                    .iter()
                    .map(|user_subject| Membership {
                        user_subject: user_subject.clone(),
                        server_id: server_id.to_owned(),
                    })
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();

        Some(members)
    }

    pub(crate) fn create_channel(&mut self, server_id: &str, name: String) -> Option<Channel> {
        if !self.servers.contains_key(server_id) {
            return None;
        }

        self.next_channel_id += 1;
        let channel = Channel {
            id: format!("chn-{}", self.next_channel_id),
            server_id: server_id.to_owned(),
            name,
        };

        self.channels.insert(channel.id.clone(), channel.clone());
        Some(channel)
    }

    pub(crate) fn create_message(
        &mut self,
        channel_id: &str,
        author_subject: String,
        content: String,
    ) -> Option<Message> {
        if !self.channels.contains_key(channel_id) {
            return None;
        }

        self.next_message_id += 1;
        let message = Message {
            id: format!("msg-{}", self.next_message_id),
            channel_id: channel_id.to_owned(),
            author_subject,
            content,
        };

        self.messages_by_channel
            .entry(channel_id.to_owned())
            .or_default()
            .push(message.clone());

        Some(message)
    }

    pub(crate) fn list_messages(&self, channel_id: &str) -> Vec<Message> {
        self.messages_by_channel
            .get(channel_id)
            .cloned()
            .unwrap_or_default()
    }

    pub(crate) fn update_message(
        &mut self,
        channel_id: &str,
        message_id: &str,
        author_subject: &str,
        content: String,
    ) -> MutationResult {
        let messages = match self.messages_by_channel.get_mut(channel_id) {
            Some(existing_messages) => existing_messages,
            None => return MutationResult::NotFound,
        };

        let maybe_message = messages.iter_mut().find(|message| message.id == message_id);

        match maybe_message {
            Some(message) if message.author_subject == author_subject => {
                message.content = content;
                MutationResult::Updated
            }
            Some(_) => MutationResult::Forbidden,
            None => MutationResult::NotFound,
        }
    }

    pub(crate) fn delete_message(
        &mut self,
        channel_id: &str,
        message_id: &str,
        author_subject: &str,
    ) -> MutationResult {
        let messages = match self.messages_by_channel.get_mut(channel_id) {
            Some(existing_messages) => existing_messages,
            None => return MutationResult::NotFound,
        };

        let message_index = messages.iter().position(|message| message.id == message_id);

        match message_index {
            Some(index) if messages[index].author_subject == author_subject => {
                messages.remove(index);
                MutationResult::Deleted
            }
            Some(_) => MutationResult::Forbidden,
            None => MutationResult::NotFound,
        }
    }

    pub(crate) fn join_voice_session(
        &mut self,
        channel_id: &str,
        participant_subject: String,
    ) -> Option<VoiceSession> {
        if !self.channels.contains_key(channel_id) {
            return None;
        }

        let participants = self
            .voice_participants_by_channel
            .entry(channel_id.to_owned())
            .or_default();

        if !participants.contains(&participant_subject) {
            participants.push(participant_subject.clone());
        }

        Some(VoiceSession {
            channel_id: channel_id.to_owned(),
            participant_subject,
        })
    }

    pub(crate) fn leave_voice_session(
        &mut self,
        channel_id: &str,
        participant_subject: &str,
    ) -> MutationResult {
        if !self.channels.contains_key(channel_id) {
            return MutationResult::NotFound;
        }

        let participants = match self.voice_participants_by_channel.get_mut(channel_id) {
            Some(existing_participants) => existing_participants,
            None => return MutationResult::NotFound,
        };

        match participants
            .iter()
            .position(|subject| subject == participant_subject)
        {
            Some(index) => {
                participants.remove(index);
                MutationResult::Deleted
            }
            None => MutationResult::NotFound,
        }
    }

    pub(crate) fn list_voice_sessions(&self, channel_id: &str) -> Option<Vec<VoiceSession>> {
        if !self.channels.contains_key(channel_id) {
            return None;
        }

        let sessions = self
            .voice_participants_by_channel
            .get(channel_id)
            .map(|participants| {
                participants
                    .iter()
                    .map(|participant_subject| VoiceSession {
                        channel_id: channel_id.to_owned(),
                        participant_subject: participant_subject.clone(),
                    })
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();

        Some(sessions)
    }
}

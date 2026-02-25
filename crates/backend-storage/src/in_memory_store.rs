use std::collections::HashMap;

use backend_domain::{Channel, Message, Server, VoiceSession};

use crate::MutationResult;

#[derive(Debug, Default)]
pub(crate) struct InMemoryStore {
    pub(crate) next_server_id: u64,
    pub(crate) next_channel_id: u64,
    pub(crate) next_message_id: u64,
    pub(crate) servers: HashMap<String, Server>,
    pub(crate) channels: HashMap<String, Channel>,
    pub(crate) messages_by_channel: HashMap<String, Vec<Message>>,
    pub(crate) voice_participants_by_channel: HashMap<String, Vec<String>>,
}

impl InMemoryStore {
    pub(crate) fn create_server(&mut self, name: String, owner_subject: String) -> Server {
        self.next_server_id += 1;
        let server = Server {
            id: format!("srv-{}", self.next_server_id),
            name,
            owner_subject,
        };

        self.servers.insert(server.id.clone(), server.clone());
        server
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

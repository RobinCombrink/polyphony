use std::collections::HashMap;
use std::time::{Duration, SystemTime};

use backend_domain::{
    BlockRelationship, Channel, ChannelId, ChannelType, DirectMessage, DirectMessageThread,
    DirectMessageThreadId, DisplayName, ExternalReference, FriendNotificationEventType,
    FriendRequest, FriendRequestId, FriendRequestState, Friendship, FriendshipId, Membership,
    Message, MessageId, NotificationCategoryPreference, NotificationEventType,
    NotificationMuteState, Server, ServerId, User, UserId,
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
    pub(crate) notification_outbox:
        Vec<(MessageId, ChannelId, UserId, UserId, NotificationEventType)>,
    pub(crate) friend_notification_outbox:
        Vec<(FriendRequestId, UserId, UserId, FriendNotificationEventType)>,
    pub(crate) unread_counts_by_user_channel: HashMap<(UserId, ChannelId), u64>,
    pub(crate) global_notification_category_by_user:
        HashMap<UserId, NotificationCategoryPreference>,
    pub(crate) global_mute_state_by_user: HashMap<UserId, NotificationMuteState>,
    pub(crate) global_channel_default_category_by_user:
        HashMap<UserId, NotificationCategoryPreference>,
    pub(crate) server_notification_category_by_user_server:
        HashMap<(UserId, ServerId), NotificationCategoryPreference>,
    pub(crate) server_mute_state_by_user_server: HashMap<(UserId, ServerId), NotificationMuteState>,
    pub(crate) channel_notification_category_by_user_channel:
        HashMap<(UserId, ChannelId), NotificationCategoryPreference>,
    pub(crate) channel_mute_until_by_user_channel: HashMap<(UserId, ChannelId), SystemTime>,
    pub(crate) friend_requests_by_id: HashMap<FriendRequestId, FriendRequest>,
    pub(crate) friendships_by_id: HashMap<FriendshipId, Friendship>,
    pub(crate) blocks_by_user_pair: HashMap<(UserId, UserId), BlockRelationship>,
    pub(crate) direct_message_threads_by_id: HashMap<DirectMessageThreadId, DirectMessageThread>,
    pub(crate) direct_message_thread_id_by_user_pair:
        HashMap<(UserId, UserId), DirectMessageThreadId>,
    pub(crate) direct_messages_by_thread_id: HashMap<DirectMessageThreadId, Vec<DirectMessage>>,
}

impl InMemoryStore {
    fn ordered_user_pair(user_id: UserId, other_user_id: UserId) -> (UserId, UserId) {
        if user_id <= other_user_id {
            (user_id, other_user_id)
        } else {
            (other_user_id, user_id)
        }
    }

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
        mentioned_user_id: Option<UserId>,
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

        let message_id: MessageId = Uuid::new_v4().into();
        let message = match mentioned_user_id {
            Some(mentioned_user_id) => Message::new_mentioned(
                message_id,
                channel_id,
                author_user_id,
                content,
                mentioned_user_id,
            ),
            None => Message::new_regular(message_id, channel_id, author_user_id, content),
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
            .filter(|user_id| {
                if *user_id == author_user_id
                    || self.is_channel_temporarily_muted_for_user(*user_id, channel_id)
                {
                    return false;
                }

                if self.global_mute_state_for_user(*user_id).is_muted() {
                    return false;
                }

                if self
                    .server_mute_state_for_user(*user_id, server_id)
                    .is_muted()
                {
                    return false;
                }

                let effective_category = self
                    .effective_notification_category_for_channel(*user_id, server_id, channel_id);

                match effective_category {
                    NotificationCategoryPreference::None => false,
                    NotificationCategoryPreference::AllMessages => true,
                    NotificationCategoryPreference::OnlyMentions => message.is_mentioned(),
                }
            })
            .collect::<Vec<_>>();

        let event_type = if message.is_mentioned() {
            NotificationEventType::Mentioned
        } else {
            NotificationEventType::UnreadMessage
        };

        for recipient_user_id in &notified_user_ids {
            self.notification_outbox.push((
                message.id(),
                channel_id,
                *recipient_user_id,
                author_user_id,
                event_type,
            ));

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

        let maybe_message = messages
            .iter_mut()
            .find(|message| message.id() == message_id);

        match maybe_message {
            Some(message) if message.author_user_id() == author_user_id => {
                message.set_content(content);
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

        let message_index = messages
            .iter()
            .position(|message| message.id() == message_id);

        match message_index {
            Some(index) if messages[index].author_user_id() == author_user_id => {
                messages.remove(index);
                MutationResult::Deleted
            }
            Some(_) => MutationResult::Forbidden,
            None => MutationResult::NotFound,
        }
    }

    pub(crate) fn set_server_notification_category_for_user(
        &mut self,
        user_id: UserId,
        server_id: ServerId,
        category: NotificationCategoryPreference,
    ) {
        self.server_notification_category_by_user_server
            .insert((user_id, server_id), category);
    }

    pub(crate) fn set_global_notification_category_for_user(
        &mut self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    ) {
        self.global_notification_category_by_user
            .insert(user_id, category);
    }

    pub(crate) fn set_global_channel_default_notification_category_for_user(
        &mut self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    ) {
        self.global_channel_default_category_by_user
            .insert(user_id, category);
    }

    pub(crate) fn set_channel_notification_category_for_user(
        &mut self,
        user_id: UserId,
        channel_id: ChannelId,
        category: NotificationCategoryPreference,
    ) {
        self.channel_notification_category_by_user_channel
            .insert((user_id, channel_id), category);
    }

    pub(crate) fn clear_channel_notification_category_for_user(
        &mut self,
        user_id: UserId,
        channel_id: ChannelId,
    ) {
        self.channel_notification_category_by_user_channel
            .remove(&(user_id, channel_id));
    }

    pub(crate) fn global_mute_state_for_user(&self, user_id: UserId) -> NotificationMuteState {
        self.global_mute_state_by_user
            .get(&user_id)
            .copied()
            .unwrap_or(NotificationMuteState::Unmuted)
    }

    pub(crate) fn set_global_mute_state_for_user(
        &mut self,
        user_id: UserId,
        mute_state: NotificationMuteState,
    ) {
        self.global_mute_state_by_user.insert(user_id, mute_state);
    }

    pub(crate) fn server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> NotificationMuteState {
        self.server_mute_state_by_user_server
            .get(&(user_id, server_id))
            .copied()
            .unwrap_or(NotificationMuteState::Unmuted)
    }

    pub(crate) fn set_server_mute_state_for_user(
        &mut self,
        user_id: UserId,
        server_id: ServerId,
        mute_state: NotificationMuteState,
    ) {
        self.server_mute_state_by_user_server
            .insert((user_id, server_id), mute_state);
    }

    pub(crate) fn set_channel_temporary_mute_for_user(
        &mut self,
        user_id: UserId,
        channel_id: ChannelId,
        duration_minutes: u32,
    ) {
        let until = SystemTime::now() + Duration::from_secs(u64::from(duration_minutes) * 60);
        self.channel_mute_until_by_user_channel
            .insert((user_id, channel_id), until);
    }

    pub(crate) fn clear_channel_temporary_mute_for_user(
        &mut self,
        user_id: UserId,
        channel_id: ChannelId,
    ) {
        self.channel_mute_until_by_user_channel
            .insert((user_id, channel_id), SystemTime::UNIX_EPOCH);
    }

    pub(crate) fn server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> Option<NotificationCategoryPreference> {
        self.server_notification_category_by_user_server
            .get(&(user_id, server_id))
            .copied()
    }

    pub(crate) fn global_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference {
        self.global_notification_category_by_user
            .get(&user_id)
            .copied()
            .unwrap_or_default()
    }

    pub(crate) fn global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference {
        self.global_channel_default_category_by_user
            .get(&user_id)
            .copied()
            .unwrap_or_default()
    }

    pub(crate) fn channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<NotificationCategoryPreference> {
        self.channel_notification_category_by_user_channel
            .get(&(user_id, channel_id))
            .copied()
    }

    pub(crate) fn is_channel_temporarily_muted_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> bool {
        self.channel_mute_until_by_user_channel
            .get(&(user_id, channel_id))
            .is_some_and(|muted_until| *muted_until > SystemTime::now())
    }

    pub(crate) fn channel_temporary_mute_expires_at_epoch_seconds(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<u64> {
        let muted_until = self
            .channel_mute_until_by_user_channel
            .get(&(user_id, channel_id))?;

        if *muted_until <= SystemTime::now() {
            return None;
        }

        muted_until
            .duration_since(SystemTime::UNIX_EPOCH)
            .ok()
            .map(|duration| duration.as_secs())
    }

    pub(crate) fn effective_notification_category_for_channel(
        &self,
        user_id: UserId,
        server_id: ServerId,
        channel_id: ChannelId,
    ) -> NotificationCategoryPreference {
        let scoped_category = self
            .channel_notification_category_for_user(user_id, channel_id)
            .or_else(|| self.server_notification_category_for_user(user_id, server_id))
            .unwrap_or_else(|| self.global_channel_default_notification_category_for_user(user_id));

        let global_category = self.global_notification_category_for_user(user_id);
        match (global_category, scoped_category) {
            (NotificationCategoryPreference::None, _) => NotificationCategoryPreference::None,
            (
                NotificationCategoryPreference::OnlyMentions,
                NotificationCategoryPreference::AllMessages,
            ) => NotificationCategoryPreference::OnlyMentions,
            _ => scoped_category,
        }
    }

    pub(crate) fn are_friends(&self, user_id: UserId, other_user_id: UserId) -> bool {
        let ordered_pair = Self::ordered_user_pair(user_id, other_user_id);
        self.friendships_by_id.values().any(|friendship| {
            Self::ordered_user_pair(friendship.user_a_id, friendship.user_b_id) == ordered_pair
        })
    }

    pub(crate) fn users_are_blocked(&self, user_id: UserId, other_user_id: UserId) -> bool {
        let ordered_pair = Self::ordered_user_pair(user_id, other_user_id);
        self.blocks_by_user_pair.contains_key(&ordered_pair)
    }

    pub(crate) fn send_friend_request(
        &mut self,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    ) -> crate::SendFriendRequestResult {
        if requester_user_id == addressee_user_id {
            return crate::SendFriendRequestResult::Forbidden;
        }

        if self.find_user_by_id(requester_user_id).is_none()
            || self.find_user_by_id(addressee_user_id).is_none()
        {
            return crate::SendFriendRequestResult::NotFound;
        }

        if self.users_are_blocked(requester_user_id, addressee_user_id) {
            return crate::SendFriendRequestResult::Blocked;
        }

        if self.are_friends(requester_user_id, addressee_user_id) {
            return crate::SendFriendRequestResult::AlreadyFriends;
        }

        let already_pending = self.friend_requests_by_id.values().any(|request| {
            request.state == FriendRequestState::Pending
                && ((request.requester_user_id == requester_user_id
                    && request.addressee_user_id == addressee_user_id)
                    || (request.requester_user_id == addressee_user_id
                        && request.addressee_user_id == requester_user_id))
        });

        if already_pending {
            return crate::SendFriendRequestResult::AlreadyPending;
        }

        let friend_request = FriendRequest {
            id: Uuid::new_v4().into(),
            requester_user_id,
            addressee_user_id,
            state: FriendRequestState::Pending,
        };

        self.friend_requests_by_id
            .insert(friend_request.id, friend_request.clone());

        self.friend_notification_outbox.push((
            friend_request.id,
            addressee_user_id,
            requester_user_id,
            FriendNotificationEventType::FriendRequestReceived,
        ));

        crate::SendFriendRequestResult::Created(friend_request)
    }

    pub(crate) fn set_friend_request_state(
        &mut self,
        actor_user_id: UserId,
        friend_request_id: FriendRequestId,
        state: FriendRequestState,
    ) -> crate::UpdateFriendRequestResult {
        let Some(existing_request) = self.friend_requests_by_id.get(&friend_request_id).cloned()
        else {
            return crate::UpdateFriendRequestResult::NotFound;
        };

        if existing_request.state != FriendRequestState::Pending {
            return crate::UpdateFriendRequestResult::InvalidState;
        }

        match state {
            FriendRequestState::Accepted | FriendRequestState::Declined => {
                if existing_request.addressee_user_id != actor_user_id {
                    return crate::UpdateFriendRequestResult::Forbidden;
                }
            }
            FriendRequestState::Cancelled => {
                if existing_request.requester_user_id != actor_user_id {
                    return crate::UpdateFriendRequestResult::Forbidden;
                }
            }
            FriendRequestState::Pending => return crate::UpdateFriendRequestResult::InvalidState,
        }

        let requester_user_id = existing_request.requester_user_id;
        let addressee_user_id = existing_request.addressee_user_id;

        if state == FriendRequestState::Declined || state == FriendRequestState::Cancelled {
            self.friend_requests_by_id.remove(&friend_request_id);

            return crate::UpdateFriendRequestResult::Updated(FriendRequest {
                id: friend_request_id,
                requester_user_id,
                addressee_user_id,
                state,
            });
        }

        let Some(existing_request) = self.friend_requests_by_id.get_mut(&friend_request_id) else {
            return crate::UpdateFriendRequestResult::NotFound;
        };
        existing_request.state = state;
        let updated_request = existing_request.clone();

        if state == FriendRequestState::Accepted
            && !self.are_friends(requester_user_id, addressee_user_id)
        {
            let friendship = Friendship {
                id: Uuid::new_v4().into(),
                user_a_id: requester_user_id,
                user_b_id: addressee_user_id,
            };
            self.friendships_by_id.insert(friendship.id, friendship);

            self.friend_notification_outbox.push((
                friend_request_id,
                requester_user_id,
                addressee_user_id,
                FriendNotificationEventType::FriendRequestAccepted,
            ));
        }

        crate::UpdateFriendRequestResult::Updated(updated_request)
    }

    pub(crate) fn list_friendships_for_user(&self, user_id: UserId) -> Vec<Friendship> {
        self.friendships_by_id
            .values()
            .filter(|friendship| friendship.user_a_id == user_id || friendship.user_b_id == user_id)
            .cloned()
            .collect::<Vec<_>>()
    }

    pub(crate) fn list_pending_incoming_friend_requests(
        &self,
        user_id: UserId,
    ) -> Vec<FriendRequest> {
        self.friend_requests_by_id
            .values()
            .filter(|request| {
                request.state == FriendRequestState::Pending && request.addressee_user_id == user_id
            })
            .cloned()
            .collect::<Vec<_>>()
    }

    pub(crate) fn list_pending_outgoing_friend_requests(
        &self,
        user_id: UserId,
    ) -> Vec<FriendRequest> {
        self.friend_requests_by_id
            .values()
            .filter(|request| {
                request.state == FriendRequestState::Pending && request.requester_user_id == user_id
            })
            .cloned()
            .collect::<Vec<_>>()
    }

    pub(crate) fn block_user(
        &mut self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> crate::BlockUserResult {
        if blocker_user_id == blocked_user_id {
            return crate::BlockUserResult::Forbidden;
        }

        if self.find_user_by_id(blocker_user_id).is_none()
            || self.find_user_by_id(blocked_user_id).is_none()
        {
            return crate::BlockUserResult::NotFound;
        }

        let ordered_pair = Self::ordered_user_pair(blocker_user_id, blocked_user_id);
        if self.blocks_by_user_pair.contains_key(&ordered_pair) {
            return crate::BlockUserResult::AlreadyBlocked;
        }

        let restored_friendship_id = self
            .friendships_by_id
            .iter()
            .find(|(_, friendship)| {
                Self::ordered_user_pair(friendship.user_a_id, friendship.user_b_id) == ordered_pair
            })
            .map(|(id, _)| *id);

        if let Some(friendship_id) = restored_friendship_id {
            self.friendships_by_id.remove(&friendship_id);
        }

        let block_relationship = BlockRelationship {
            id: Uuid::new_v4().into(),
            blocker_user_id,
            blocked_user_id,
            restored_friendship_id,
        };

        self.blocks_by_user_pair
            .insert(ordered_pair, block_relationship.clone());

        crate::BlockUserResult::Created(block_relationship)
    }

    pub(crate) fn unblock_user(
        &mut self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> MutationResult {
        let ordered_pair = Self::ordered_user_pair(blocker_user_id, blocked_user_id);
        let Some(block_relationship) = self.blocks_by_user_pair.get(&ordered_pair).cloned() else {
            return MutationResult::NotFound;
        };

        if block_relationship.blocker_user_id != blocker_user_id {
            return MutationResult::Forbidden;
        }

        self.blocks_by_user_pair.remove(&ordered_pair);

        if let Some(friendship_id) = block_relationship.restored_friendship_id {
            let friendship = Friendship {
                id: friendship_id,
                user_a_id: ordered_pair.0,
                user_b_id: ordered_pair.1,
            };
            self.friendships_by_id.insert(friendship.id, friendship);
        }

        MutationResult::Deleted
    }

    pub(crate) fn list_blocked_users(&self, blocker_user_id: UserId) -> Vec<BlockRelationship> {
        self.blocks_by_user_pair
            .values()
            .filter(|block_relationship| block_relationship.blocker_user_id == blocker_user_id)
            .cloned()
            .collect::<Vec<_>>()
    }

    pub(crate) fn open_or_get_direct_message_thread(
        &mut self,
        actor_user_id: UserId,
        other_user_id: UserId,
    ) -> crate::OpenOrGetDirectMessageThreadResult {
        if actor_user_id == other_user_id {
            return crate::OpenOrGetDirectMessageThreadResult::Forbidden;
        }

        if self.find_user_by_id(actor_user_id).is_none()
            || self.find_user_by_id(other_user_id).is_none()
        {
            return crate::OpenOrGetDirectMessageThreadResult::NotFound;
        }

        if self.users_are_blocked(actor_user_id, other_user_id) {
            return crate::OpenOrGetDirectMessageThreadResult::Blocked;
        }

        if !self.are_friends(actor_user_id, other_user_id) {
            return crate::OpenOrGetDirectMessageThreadResult::Forbidden;
        }

        let ordered_pair = Self::ordered_user_pair(actor_user_id, other_user_id);
        if let Some(thread_id) = self
            .direct_message_thread_id_by_user_pair
            .get(&ordered_pair)
            .copied()
        {
            let existing_thread = self
                .direct_message_threads_by_id
                .get(&thread_id)
                .cloned()
                .expect("dm thread id mapping to existing thread");
            return crate::OpenOrGetDirectMessageThreadResult::Opened(existing_thread);
        }

        let thread = DirectMessageThread {
            id: Uuid::new_v4().into(),
            participant_a_user_id: ordered_pair.0,
            participant_b_user_id: ordered_pair.1,
        };
        self.direct_message_thread_id_by_user_pair
            .insert(ordered_pair, thread.id);
        self.direct_message_threads_by_id
            .insert(thread.id, thread.clone());
        crate::OpenOrGetDirectMessageThreadResult::Opened(thread)
    }

    pub(crate) fn list_direct_message_threads_for_user(
        &self,
        user_id: UserId,
    ) -> Vec<DirectMessageThread> {
        self.direct_message_threads_by_id
            .values()
            .filter(|thread| {
                thread.participant_a_user_id == user_id || thread.participant_b_user_id == user_id
            })
            .cloned()
            .collect::<Vec<_>>()
    }

    pub(crate) fn send_direct_message(
        &mut self,
        actor_user_id: UserId,
        thread_id: DirectMessageThreadId,
        content: String,
    ) -> crate::SendDirectMessageResult {
        let Some(thread) = self.direct_message_threads_by_id.get(&thread_id).cloned() else {
            return crate::SendDirectMessageResult::NotFound;
        };

        if thread.participant_a_user_id != actor_user_id
            && thread.participant_b_user_id != actor_user_id
        {
            return crate::SendDirectMessageResult::Forbidden;
        }

        let other_user_id = if thread.participant_a_user_id == actor_user_id {
            thread.participant_b_user_id
        } else {
            thread.participant_a_user_id
        };

        if self.users_are_blocked(actor_user_id, other_user_id) {
            return crate::SendDirectMessageResult::Blocked;
        }

        if !self.are_friends(actor_user_id, other_user_id) {
            return crate::SendDirectMessageResult::Forbidden;
        }

        let message = DirectMessage {
            id: Uuid::new_v4().into(),
            thread_id,
            author_user_id: actor_user_id,
            content,
        };
        self.direct_messages_by_thread_id
            .entry(thread_id)
            .or_default()
            .push(message.clone());

        crate::SendDirectMessageResult::Created(message)
    }

    pub(crate) fn list_direct_messages(
        &self,
        actor_user_id: UserId,
        thread_id: DirectMessageThreadId,
    ) -> Option<Vec<DirectMessage>> {
        let thread = self.direct_message_threads_by_id.get(&thread_id)?;
        if thread.participant_a_user_id != actor_user_id
            && thread.participant_b_user_id != actor_user_id
        {
            return None;
        }

        Some(
            self.direct_messages_by_thread_id
                .get(&thread_id)
                .cloned()
                .unwrap_or_default(),
        )
    }

    pub(crate) fn search_direct_messages_for_person(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
        query: &str,
    ) -> Option<Vec<DirectMessage>> {
        if self.users_are_blocked(actor_user_id, other_user_id) {
            return None;
        }

        if !self.are_friends(actor_user_id, other_user_id) {
            return None;
        }

        let ordered_pair = Self::ordered_user_pair(actor_user_id, other_user_id);
        let Some(thread_id) = self
            .direct_message_thread_id_by_user_pair
            .get(&ordered_pair)
            .copied()
        else {
            return Some(Vec::new());
        };

        let query_lower = query.to_lowercase();
        let messages = self
            .direct_messages_by_thread_id
            .get(&thread_id)
            .cloned()
            .unwrap_or_default()
            .into_iter()
            .filter(|message| message.content.to_lowercase().contains(&query_lower))
            .collect::<Vec<_>>();

        Some(messages)
    }
}

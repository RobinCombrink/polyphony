use backend_domain::{ChannelId, MessageId, ServerId, UserId};
use serde::Serialize;
use tokio::sync::broadcast;

#[derive(Clone, Debug, Serialize)]
#[serde(tag = "event_type", rename_all = "snake_case")]
pub enum NotificationEvent {
    UnreadMessage {
        server_id: ServerId,
        server_name: String,
        channel_id: ChannelId,
        channel_name: String,
        message_id: MessageId,
    },
    Mentioned {
        server_id: ServerId,
        server_name: String,
        channel_id: ChannelId,
        channel_name: String,
        message_id: MessageId,
    },
    FriendJoinedVoice {
        server_id: ServerId,
        server_name: String,
        channel_id: ChannelId,
        channel_name: String,
        joined_user_id: UserId,
        joined_user_display_name: String,
    },
    FriendRequestReceived {
        friend_request_id: backend_domain::FriendRequestId,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    },
    FriendRequestAccepted {
        friend_request_id: backend_domain::FriendRequestId,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    },
}

impl NotificationEvent {
    pub fn unread_message(
        server_id: ServerId,
        server_name: String,
        channel_id: ChannelId,
        channel_name: String,
        message_id: MessageId,
    ) -> Self {
        Self::UnreadMessage {
            server_id,
            server_name,
            channel_id,
            channel_name,
            message_id,
        }
    }

    pub fn mentioned(
        server_id: ServerId,
        server_name: String,
        channel_id: ChannelId,
        channel_name: String,
        message_id: MessageId,
    ) -> Self {
        Self::Mentioned {
            server_id,
            server_name,
            channel_id,
            channel_name,
            message_id,
        }
    }

    pub fn friend_joined_voice(
        server_id: ServerId,
        server_name: String,
        channel_id: ChannelId,
        channel_name: String,
        joined_user_id: UserId,
        joined_user_display_name: String,
    ) -> Self {
        Self::FriendJoinedVoice {
            server_id,
            server_name,
            channel_id,
            channel_name,
            joined_user_id,
            joined_user_display_name,
        }
    }

    pub fn friend_request_received(
        friend_request_id: backend_domain::FriendRequestId,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    ) -> Self {
        Self::FriendRequestReceived {
            friend_request_id,
            requester_user_id,
            addressee_user_id,
        }
    }

    pub fn friend_request_accepted(
        friend_request_id: backend_domain::FriendRequestId,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    ) -> Self {
        Self::FriendRequestAccepted {
            friend_request_id,
            requester_user_id,
            addressee_user_id,
        }
    }

}

#[derive(Clone, Debug)]
pub struct NotificationEnvelope {
    pub recipient_user_id: UserId,
    pub event: NotificationEvent,
}

#[derive(Clone, Debug)]
pub struct NotificationHub {
    sender: broadcast::Sender<NotificationEnvelope>,
}

impl Default for NotificationHub {
    fn default() -> Self {
        let (sender, _) = broadcast::channel(1024);
        Self { sender }
    }
}

impl NotificationHub {
    pub fn subscribe(&self) -> broadcast::Receiver<NotificationEnvelope> {
        self.sender.subscribe()
    }

    pub fn publish(&self, envelope: NotificationEnvelope) {
        let _ = self.sender.send(envelope);
    }
}

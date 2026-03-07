use backend_domain::{ChannelId, MessageId, UserId};
use serde::Serialize;
use tokio::sync::broadcast;

#[derive(Clone, Debug, Serialize)]
pub struct NotificationEvent {
    pub event_type: String,
    pub channel_id: ChannelId,
    pub message_id: MessageId,
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
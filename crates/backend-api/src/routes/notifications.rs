use axum::{
    extract::{
        State, WebSocketUpgrade,
        ws::{Message, WebSocket},
    },
    response::IntoResponse,
};
use backend_storage::{ChannelRepository, MessageRepository, ServerRepository, UserRepository};

use crate::{
    ApiState,
    auth::{AuthenticatedUser, TokenVerifier},
};

pub(crate) async fn websocket_notifications<
    UserRepo,
    ServerRepo,
    ChannelRepo,
    MessageRepo,
    Verifier,
>(
    ws: WebSocketUpgrade,
    State(state): State<ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>>,
    authenticated_user: AuthenticatedUser,
) -> impl IntoResponse
where
    UserRepo: UserRepository + Send + Sync + 'static,
    ServerRepo: ServerRepository + Send + Sync + 'static,
    ChannelRepo: ChannelRepository + Send + Sync + 'static,
    MessageRepo: MessageRepository + Send + Sync + 'static,
    Verifier: TokenVerifier + Send + Sync + 'static,
{
    ws.on_upgrade(move |socket| async move {
        forward_notifications(socket, state, authenticated_user).await;
    })
}

async fn forward_notifications<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>(
    mut socket: WebSocket,
    state: ApiState<UserRepo, ServerRepo, ChannelRepo, MessageRepo, Verifier>,
    authenticated_user: AuthenticatedUser,
) where
    UserRepo: UserRepository,
    ServerRepo: ServerRepository,
    ChannelRepo: ChannelRepository,
    MessageRepo: MessageRepository,
    Verifier: TokenVerifier,
{
    let mut subscriber = state.notification_hub.subscribe();

    while let Ok(envelope) = subscriber.recv().await {
        if envelope.recipient_user_id != authenticated_user.user_id {
            continue;
        }

        let payload = match serde_json::to_string(&envelope.event) {
            Ok(value) => value,
            Err(_) => continue,
        };

        if socket.send(Message::Text(payload.into())).await.is_err() {
            break;
        }
    }
}
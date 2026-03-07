mod common;

use std::collections::HashMap;
use std::fmt::{Debug, Formatter};
use std::sync::Arc;
use std::time::Duration;

use axum::http::StatusCode;
use backend_api::notification_hub::NotificationHub;
use common::bdd_support::{
    Actor, ChannelId, MessageId, ServerId, SharedTestStore, add_server_member_with_token,
    create_actor_with_notification_hub, create_channel_with_token, create_message_with_token,
    create_server_with_token, mark_channel_notifications_read_with_token,
    outbox_count_for_message_recipient, outbox_total_count_for_recipient, payload_channel_id,
    payload_message_id, payload_server_id, prime_feature_test_store, response_payload_json,
    shutdown_feature_test_store, unread_count_for_channel, unread_notifications_count_with_token,
};
use cucumber::{World as _, given, then, when};
use futures_util::StreamExt;
use serde_json::Value;
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use tokio_tungstenite::MaybeTlsStream;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;

const FEATURE_PATH: &str = "../../features/notifications.feature";

struct WsConnection {
    actor_name: String,
    stream: WebSocketStream<MaybeTlsStream<tokio::net::TcpStream>>,
    shutdown_signal: Option<oneshot::Sender<()>>,
}

impl Debug for WsConnection {
    fn fmt(&self, f: &mut Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("WsConnection")
            .field("actor_name", &self.actor_name)
            .finish()
    }
}

#[derive(Debug, cucumber::World)]
struct NotificationsWorld {
    actors: HashMap<String, Actor>,
    shared_store: SharedTestStore,
    notification_hub: Arc<NotificationHub>,
    server_id: Option<ServerId>,
    channel_id: Option<ChannelId>,
    channel_ids_by_name: HashMap<String, ChannelId>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    latest_message_id: Option<MessageId>,
    outbox_totals_before_post_by_actor: HashMap<String, u64>,
    active_ws_connection: Option<WsConnection>,
}

impl Default for NotificationsWorld {
    fn default() -> Self {
        Self {
            actors: HashMap::new(),
            shared_store: common::bdd_support::default_shared_store(),
            notification_hub: Arc::new(NotificationHub::default()),
            server_id: None,
            channel_id: None,
            channel_ids_by_name: HashMap::new(),
            latest_status: None,
            latest_payload: None,
            latest_message_id: None,
            outbox_totals_before_post_by_actor: HashMap::new(),
            active_ws_connection: None,
        }
    }
}

impl NotificationsWorld {
    fn actor_ref(&self, name: &str) -> &Actor {
        self.actors
            .get(name)
            .unwrap_or_else(|| panic!("actor {name} to be initialized"))
    }

    fn server_id_ref(&self) -> &ServerId {
        self.server_id.as_ref().expect("server id to be set")
    }

    fn channel_id_ref(&self) -> &ChannelId {
        self.channel_id.as_ref().expect("channel id to be set")
    }

    fn channel_id_by_name_ref(&self, channel_name: &str) -> &ChannelId {
        self.channel_ids_by_name
            .get(channel_name)
            .unwrap_or_else(|| panic!("channel {channel_name} to be initialized"))
    }

    fn latest_status(&self) -> StatusCode {
        self.latest_status.expect("latest status to be set")
    }

    fn latest_message_id(&self) -> MessageId {
        self.latest_message_id.expect("latest message id to be set")
    }

    async fn connect_actor_ws_notifications(&mut self, actor_name: &str) {
        let actor = self.actor_ref(actor_name);
        let app = actor.app.clone();

        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .expect("test listener to bind");
        let local_address = listener.local_addr().expect("listener address");
        let (shutdown_tx, shutdown_rx) = oneshot::channel::<()>();

        tokio::spawn(async move {
            let _ = axum::serve(listener, app)
                .with_graceful_shutdown(async {
                    let _ = shutdown_rx.await;
                })
                .await;
        });

        let websocket_url = format!("ws://{local_address}/api/v1/notifications/ws");
        let mut request = websocket_url
            .into_client_request()
            .expect("websocket request to be valid");
        request.headers_mut().insert(
            http::header::AUTHORIZATION,
            http::HeaderValue::from_str(&format!("Bearer {}", actor.token))
                .expect("authorization header value to be valid"),
        );

        let (stream, _) = tokio_tungstenite::connect_async(request)
            .await
            .expect("notifications websocket to connect");

        self.active_ws_connection = Some(WsConnection {
            actor_name: actor_name.to_owned(),
            stream,
            shutdown_signal: Some(shutdown_tx),
        });
    }

    async fn next_ws_event(&mut self, timeout: Duration) -> Option<Value> {
        let ws_connection = self
            .active_ws_connection
            .as_mut()
            .expect("active websocket connection to be set");

        tokio::time::timeout(timeout, async {
            loop {
                let message = ws_connection.stream.next().await?;
                let message = match message {
                    Ok(value) => value,
                    Err(_) => return None,
                };

                if !message.is_text() {
                    continue;
                }

                let text_payload = match message.into_text() {
                    Ok(value) => value,
                    Err(_) => return None,
                };

                let payload: Value = serde_json::from_str(&text_payload).ok()?;
                return Some(payload);
            }
        })
        .await
        .ok()
        .flatten()
    }
}

impl Drop for NotificationsWorld {
    fn drop(&mut self) {
        if let Some(connection) = self.active_ws_connection.as_mut() {
            let _ = connection
                .shutdown_signal
                .take()
                .map(|sender| sender.send(()));
        }
    }
}

#[given(regex = r#"^a user named "([^"]+)" exists$"#)]
async fn a_user_named_exists(world: &mut NotificationsWorld, name: String) {
    if world.actors.contains_key(&name) {
        return;
    }

    let token = format!("{}-token", name.to_ascii_lowercase());
    let actor = create_actor_with_notification_hub(
        &name,
        &token,
        world.shared_store.clone(),
        Arc::clone(&world.notification_hub),
    )
    .await;
    world.actors.insert(name, actor);
}

#[given(regex = r#"^a text channel exists in "([^"]+)"'s server$"#)]
async fn a_text_channel_exists_in_named_users_server(
    world: &mut NotificationsWorld,
    owner_name: String,
) {
    let channel_id =
        create_text_channel_for_owner(world, &owner_name, "notification-channel").await;
    world.channel_id = Some(channel_id);
}

#[given(regex = r#"^a voice channel exists in "([^"]+)"'s server$"#)]
async fn a_voice_channel_exists_in_named_users_server(
    world: &mut NotificationsWorld,
    owner_name: String,
) {
    let owner = world.actor_ref(&owner_name);

    let channel_payload = response_payload_json(
        create_channel_with_token(
            &owner.app,
            world.server_id_ref(),
            "notification-voice",
            "voice",
            &owner.token,
        )
        .await,
    )
    .await;

    world.channel_id = Some(payload_channel_id(&channel_payload, "id"));
}

#[given(regex = r#"^a text channel named "([^"]+)" exists in "([^"]+)"'s server$"#)]
async fn a_text_channel_named_exists_in_named_users_server(
    world: &mut NotificationsWorld,
    channel_name: String,
    owner_name: String,
) {
    let channel_id = create_text_channel_for_owner(world, &owner_name, &channel_name).await;
    world
        .channel_ids_by_name
        .insert(channel_name.clone(), channel_id);
}

#[given(regex = r#"^"([^"]+)" adds "([^"]+)" to the server$"#)]
async fn named_user_adds_named_user_to_the_server(
    world: &mut NotificationsWorld,
    owner_name: String,
    member_name: String,
) {
    let owner = world.actor_ref(&owner_name);
    let member = world.actor_ref(&member_name);

    let response = add_server_member_with_token(
        &owner.app,
        world.server_id_ref(),
        &member.user_id,
        &owner.token,
    )
    .await;

    assert_eq!(response.status(), StatusCode::CREATED);
}

#[given(regex = r#"^"([^"]+)" is connected to notifications websocket$"#)]
async fn named_user_is_connected_to_notifications_websocket(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    world.connect_actor_ws_notifications(&actor_name).await;
}

#[when(regex = r#"^"([^"]+)" posts a message in that channel$"#)]
async fn named_user_posts_a_message_in_that_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    world.outbox_totals_before_post_by_actor.clear();

    for (name, actor) in &world.actors {
        let outbox_count =
            outbox_total_count_for_recipient(&world.shared_store, actor.user_id).await;
        world
            .outbox_totals_before_post_by_actor
            .insert(name.to_owned(), outbox_count);
    }

    let actor = world.actor_ref(&actor_name);
    let response = create_message_with_token(
        &actor.app,
        world.channel_id_ref(),
        "notification-message",
        &actor.token,
    )
    .await;

    world.latest_status = Some(response.status());
    if response.status() == StatusCode::CREATED {
        let payload = response_payload_json(response).await;
        world.latest_message_id = Some(payload_message_id(&payload, "id"));
        world.latest_payload = Some(payload);
    } else {
        world.latest_message_id = None;
        world.latest_payload = None;
    }
}

#[when(regex = r#"^"([^"]+)" posts a message in channel "([^"]+)"$"#)]
async fn named_user_posts_a_message_in_channel_named(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    named_user_posts_a_message_in_given_channel(
        world,
        actor_name,
        *world.channel_id_by_name_ref(&channel_name),
    )
    .await;
}

#[when(regex = r#"^"([^"]+)" marks channel "([^"]+)" notifications as read$"#)]
async fn named_user_marks_channel_notifications_as_read(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response =
        mark_channel_notifications_read_with_token(&actor.app, &channel_id, &actor.token).await;

    world.latest_status = Some(response.status());
    assert_eq!(world.latest_status(), StatusCode::NO_CONTENT);
}

#[then(regex = r#"^unread count increments for "([^"]+)" in that channel$"#)]
async fn unread_count_increments_for_named_user_in_that_channel(
    world: &mut NotificationsWorld,
    recipient_name: String,
) {
    let recipient = world.actor_ref(&recipient_name);
    let unread_count = unread_count_for_channel(
        &world.shared_store,
        recipient.user_id,
        *world.channel_id_ref(),
    )
    .await;
    assert_eq!(unread_count, 1);
}

#[then(regex = r#"^a notification outbox event is recorded for "([^"]+)"$"#)]
async fn a_notification_outbox_event_is_recorded_for_named_user(
    world: &mut NotificationsWorld,
    recipient_name: String,
) {
    let recipient = world.actor_ref(&recipient_name);
    let outbox_count = outbox_count_for_message_recipient(
        &world.shared_store,
        world.latest_message_id(),
        recipient.user_id,
    )
    .await;

    assert_eq!(outbox_count, 1);
}

#[then(regex = r#"^unread count for "([^"]+)" in that channel is zero$"#)]
async fn unread_count_for_named_user_in_that_channel_is_zero(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let unread_count =
        unread_count_for_channel(&world.shared_store, actor.user_id, *world.channel_id_ref()).await;

    assert_eq!(unread_count, 0);
}

#[then(regex = r#"^no notification outbox event is recorded for "([^"]+)"$"#)]
async fn no_notification_outbox_event_is_recorded_for_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);

    let after_count = outbox_total_count_for_recipient(&world.shared_store, actor.user_id).await;

    let before_count = *world
        .outbox_totals_before_post_by_actor
        .get(&actor_name)
        .expect("outbox count before posting to be tracked");

    assert_eq!(after_count, before_count);
}

#[then(regex = r#"^unread count for "([^"]+)" in channel "([^"]+)" is zero$"#)]
async fn unread_count_for_named_user_in_named_channel_is_zero(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let unread_count =
        unread_count_for_channel(&world.shared_store, actor.user_id, channel_id).await;

    assert_eq!(unread_count, 0);
}

#[then(regex = r#"^"([^"]+)" sees total unread notification count of ([0-9]+)$"#)]
async fn named_user_sees_total_unread_notification_count_of(
    world: &mut NotificationsWorld,
    actor_name: String,
    expected_total: u64,
) {
    let actor = world.actor_ref(&actor_name);
    let response = unread_notifications_count_with_token(&actor.app, &actor.token).await;

    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;
    let total_unread_count = payload["total_unread_count"]
        .as_u64()
        .expect("total unread count to be present");

    assert_eq!(total_unread_count, expected_total);
}

#[then(regex = r#"^"([^"]+)" receives a message-created websocket notification for that channel$"#)]
async fn named_user_receives_message_created_websocket_notification_for_that_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("websocket notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(event["event_type"].as_str(), Some("message_created"));
    let expected_channel_id = world.channel_id_ref().to_string();
    assert_eq!(
        event["channel_id"].as_str(),
        Some(expected_channel_id.as_str())
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active websocket connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(regex = r#"^"([^"]+)" does not receive websocket notification events for that channel$"#)]
async fn named_user_does_not_receive_websocket_notification_events_for_that_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let event = world.next_ws_event(Duration::from_millis(600)).await;
    assert!(event.is_none(), "unexpected websocket notification payload");

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active websocket connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then("posting is denied because that channel does not support messaging")]
async fn posting_is_denied_because_that_channel_does_not_support_messaging(
    world: &mut NotificationsWorld,
) {
    assert_eq!(world.latest_status(), StatusCode::UNPROCESSABLE_ENTITY);
}

async fn ensure_server_for_owner(world: &mut NotificationsWorld, owner_name: &str) {
    if world.server_id.is_some() {
        return;
    }

    let owner = world.actor_ref(owner_name).clone();
    let server_payload = response_payload_json(
        create_server_with_token(&owner.app, "notification-server", &owner.token).await,
    )
    .await;
    world.server_id = Some(payload_server_id(&server_payload, "id"));
}

async fn create_text_channel_for_owner(
    world: &mut NotificationsWorld,
    owner_name: &str,
    channel_name: &str,
) -> ChannelId {
    ensure_server_for_owner(world, owner_name).await;

    let owner = world.actor_ref(owner_name);
    let channel_payload = response_payload_json(
        create_channel_with_token(
            &owner.app,
            world.server_id_ref(),
            channel_name,
            "text",
            &owner.token,
        )
        .await,
    )
    .await;

    let channel_id = payload_channel_id(&channel_payload, "id");
    world
        .channel_ids_by_name
        .insert(channel_name.to_owned(), channel_id);

    channel_id
}

async fn named_user_posts_a_message_in_given_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_id: ChannelId,
) {
    let actor = world.actor_ref(&actor_name);
    let response = create_message_with_token(
        &actor.app,
        &channel_id,
        "notification-message",
        &actor.token,
    )
    .await;

    world.latest_status = Some(response.status());
    if response.status() == StatusCode::CREATED {
        let payload = response_payload_json(response).await;
        world.latest_message_id = Some(payload_message_id(&payload, "id"));
        world.latest_payload = Some(payload);
    } else {
        world.latest_message_id = None;
        world.latest_payload = None;
    }
}

#[tokio::test]
async fn notifications_feature() {
    prime_feature_test_store().await;
    NotificationsWorld::cucumber()
        .run_and_exit(FEATURE_PATH)
        .await;
    shutdown_feature_test_store().await;
}

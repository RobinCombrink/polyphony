mod common;

use std::collections::HashMap;
use std::fmt::{Debug, Formatter};
use std::sync::Arc;
use std::time::Duration;

use axum::body::Body;
use axum::http::{Request, StatusCode, header};
use backend_api::notification_hub::NotificationHub;
use common::bdd_support::{
    Actor, ChannelId, MessageId, NotificationCategoryPreference, NotificationMuteState, ServerId,
    SharedTestStore, add_server_member_with_token, channel_notification_preference_with_token,
    connect_voice_session_with_token, create_actor_with_notification_hub,
    create_channel_with_token, create_message_with_token, create_message_with_token_and_mention,
    create_server_with_token, global_notification_preference_with_token,
    mark_channel_notifications_read_with_token, mute_channel_notifications_with_token,
    outbox_count_for_message_recipient, outbox_total_count_for_recipient, payload_channel_id,
    payload_message_id, payload_server_id, prime_feature_test_store, response_payload_json,
    server_notification_preference_with_token, shutdown_feature_test_store,
    unmute_channel_notifications_with_token, unread_count_for_channel,
    unread_notifications_count_with_token,
    update_global_channel_default_notification_preference_with_token,
    update_global_notification_category_preference_with_token,
    update_global_notification_preference_with_token,
    update_server_notification_preference_with_token,
};
use cucumber::{World as _, given, then, when};
use futures_util::StreamExt;
use serde_json::Value;
use tokio::net::TcpListener;
use tokio::sync::oneshot;
use tokio_tungstenite::MaybeTlsStream;
use tokio_tungstenite::WebSocketStream;
use tokio_tungstenite::tungstenite::client::IntoClientRequest;
use tower::ServiceExt;

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
    server_ids_by_name: HashMap<String, ServerId>,
    server_owner_by_name: HashMap<String, String>,
    channel_id: Option<ChannelId>,
    channel_ids_by_name: HashMap<String, ChannelId>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    latest_message_id: Option<MessageId>,
    friend_request_ids_by_pair: HashMap<(String, String), String>,
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
            server_ids_by_name: HashMap::new(),
            server_owner_by_name: HashMap::new(),
            channel_id: None,
            channel_ids_by_name: HashMap::new(),
            latest_status: None,
            latest_payload: None,
            latest_message_id: None,
            friend_request_ids_by_pair: HashMap::new(),
            outbox_totals_before_post_by_actor: HashMap::new(),
            active_ws_connection: None,
        }
    }
}

impl NotificationsWorld {
    fn ordered_actor_pair(first: &str, second: &str) -> (String, String) {
        if first <= second {
            (first.to_owned(), second.to_owned())
        } else {
            (second.to_owned(), first.to_owned())
        }
    }

    fn friend_request_id_for_pair(&self, first: &str, second: &str) -> String {
        self.friend_request_ids_by_pair
            .get(&Self::ordered_actor_pair(first, second))
            .cloned()
            .unwrap_or_else(|| {
                panic!("friend request id for pair {first}-{second} to be initialized")
            })
    }

    fn actor_ref(&self, name: &str) -> &Actor {
        self.actors
            .get(name)
            .unwrap_or_else(|| panic!("actor {name} to be initialized"))
    }

    fn server_id_ref(&self) -> &ServerId {
        self.server_id.as_ref().expect("server id to be set")
    }

    fn server_id_by_name_ref(&self, server_name: &str) -> &ServerId {
        self.server_ids_by_name
            .get(server_name)
            .unwrap_or_else(|| panic!("server {server_name} to be initialized"))
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

#[given(regex = r#"^a server named "([^"]+)" owned by "([^"]+)" exists$"#)]
async fn a_server_named_owned_by_named_user_exists(
    world: &mut NotificationsWorld,
    server_name: String,
    owner_name: String,
) {
    let server_id = ensure_named_server_for_owner(world, &server_name, &owner_name).await;
    world.server_id = Some(server_id);
}

#[given(regex = r#"^a text channel exists in server "([^"]+)" created by "([^"]+)"$"#)]
async fn a_text_channel_exists_in_named_server_created_by_named_user(
    world: &mut NotificationsWorld,
    server_name: String,
    owner_name: String,
) {
    let channel_id = create_text_channel_for_named_server(
        world,
        &server_name,
        &owner_name,
        "notification-channel",
    )
    .await;
    world.channel_id = Some(channel_id);
}

#[given(regex = r#"^a voice channel exists in server "([^"]+)" created by "([^"]+)"$"#)]
async fn a_voice_channel_exists_in_named_server_created_by_named_user(
    world: &mut NotificationsWorld,
    server_name: String,
    owner_name: String,
) {
    let server_id = ensure_named_server_for_owner(world, &server_name, &owner_name).await;
    world.server_id = Some(server_id);

    let owner = world.actor_ref(&owner_name);

    let channel_payload = response_payload_json(
        create_channel_with_token(
            &owner.app,
            &server_id,
            "notification-voice",
            "voice",
            &owner.token,
        )
        .await,
    )
    .await;

    world.channel_id = Some(payload_channel_id(&channel_payload, "id"));
}

#[given(
    regex = r#"^a voice channel named "([^"]+)" exists in server "([^"]+)" created by "([^"]+)"$"#
)]
async fn a_voice_channel_named_exists_in_named_server_created_by_named_user(
    world: &mut NotificationsWorld,
    channel_name: String,
    server_name: String,
    owner_name: String,
) {
    let server_id = ensure_named_server_for_owner(world, &server_name, &owner_name).await;
    world.server_id = Some(server_id);

    let owner = world.actor_ref(&owner_name);
    let channel_payload = response_payload_json(
        create_channel_with_token(&owner.app, &server_id, &channel_name, "voice", &owner.token)
            .await,
    )
    .await;

    let channel_id = payload_channel_id(&channel_payload, "id");
    world.channel_id = Some(channel_id);
    world
        .channel_ids_by_name
        .insert(channel_name.to_owned(), channel_id);
}

#[given(
    regex = r#"^a text channel named "([^"]+)" exists in server "([^"]+)" created by "([^"]+)"$"#
)]
async fn a_text_channel_named_exists_in_named_server_created_by_named_user(
    world: &mut NotificationsWorld,
    channel_name: String,
    server_name: String,
    owner_name: String,
) {
    let channel_id =
        create_text_channel_for_named_server(world, &server_name, &owner_name, &channel_name).await;
    world
        .channel_ids_by_name
        .insert(channel_name.clone(), channel_id);
}

#[given(regex = r#"^"([^"]+)" adds "([^"]+)" to server "([^"]+)"$"#)]
async fn named_user_adds_named_user_to_named_server(
    world: &mut NotificationsWorld,
    owner_name: String,
    member_name: String,
    server_name: String,
) {
    assert_server_owner(world, &server_name, &owner_name);

    let owner = world.actor_ref(&owner_name).clone();
    let member = world.actor_ref(&member_name).clone();
    let server_id = *world.server_id_by_name_ref(&server_name);
    world.server_id = Some(server_id);

    let response =
        add_server_member_with_token(&owner.app, &server_id, &member.user_id, &owner.token).await;

    assert_eq!(response.status(), StatusCode::CREATED);
}

#[given(regex = r#"^"([^"]+)" has muted server "([^"]+)"$"#)]
async fn named_user_has_muted_named_server(
    world: &mut NotificationsWorld,
    actor_name: String,
    server_name: String,
) {
    let server_id = *world.server_id_by_name_ref(&server_name);
    world.server_id = Some(server_id);

    let actor = world.actor_ref(&actor_name);
    let response = update_server_notification_preference_with_token(
        &actor.app,
        &server_id,
        NotificationMuteState::Muted,
        &actor.token,
    )
    .await;
    assert_eq!(response.status(), StatusCode::NO_CONTENT);
}

#[given(regex = r#"^"([^"]+)" has globally muted notifications$"#)]
async fn named_user_has_globally_muted_notifications(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let response = update_global_notification_preference_with_token(
        &actor.app,
        NotificationMuteState::Muted,
        &actor.token,
    )
    .await;
    assert_eq!(response.status(), StatusCode::NO_CONTENT);
}

#[given(regex = r#"^"([^"]+)" has temporarily muted channel "([^"]+)" for ([0-9]+) minutes$"#)]
async fn named_user_has_temporarily_muted_named_channel_for_minutes(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
    duration_minutes: u32,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response = mute_channel_notifications_with_token(
        &actor.app,
        &channel_id,
        duration_minutes,
        &actor.token,
    )
    .await;
    assert_eq!(response.status(), StatusCode::NO_CONTENT);
}

#[given(regex = r#"^"([^"]+)" is subscribed to live notifications$"#)]
async fn named_user_is_subscribed_to_live_notifications(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    world.connect_actor_ws_notifications(&actor_name).await;
}

#[given(regex = r#"^"([^"]+)" has all-messages channel default notifications$"#)]
async fn named_user_has_all_messages_channel_default_notifications(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let global_category_response = update_global_notification_category_preference_with_token(
        &actor.app,
        NotificationCategoryPreference::AllMessages,
        &actor.token,
    )
    .await;
    assert_eq!(global_category_response.status(), StatusCode::NO_CONTENT);

    let channel_default_response =
        update_global_channel_default_notification_preference_with_token(
            &actor.app,
            NotificationCategoryPreference::AllMessages,
            &actor.token,
        )
        .await;

    assert_eq!(channel_default_response.status(), StatusCode::NO_CONTENT);
}

#[given(regex = r#"^"([^"]+)" has only-mentions channel default notifications$"#)]
async fn named_user_has_only_mentions_channel_default_notifications(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let global_category_response = update_global_notification_category_preference_with_token(
        &actor.app,
        NotificationCategoryPreference::OnlyMentions,
        &actor.token,
    )
    .await;
    assert_eq!(global_category_response.status(), StatusCode::NO_CONTENT);

    let channel_default_response =
        update_global_channel_default_notification_preference_with_token(
            &actor.app,
            NotificationCategoryPreference::OnlyMentions,
            &actor.token,
        )
        .await;

    assert_eq!(channel_default_response.status(), StatusCode::NO_CONTENT);
}

#[given(regex = r#"^"([^"]+)" has none channel default notifications$"#)]
async fn named_user_has_none_channel_default_notifications(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let global_category_response = update_global_notification_category_preference_with_token(
        &actor.app,
        NotificationCategoryPreference::None,
        &actor.token,
    )
    .await;
    assert_eq!(global_category_response.status(), StatusCode::NO_CONTENT);

    let channel_default_response =
        update_global_channel_default_notification_preference_with_token(
            &actor.app,
            NotificationCategoryPreference::None,
            &actor.token,
        )
        .await;

    assert_eq!(channel_default_response.status(), StatusCode::NO_CONTENT);
}

#[when(regex = r#"^"([^"]+)" posts a message in channel "([^"]+)"$"#)]
async fn named_user_posts_a_message_in_channel_named(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    track_outbox_totals_before_post(world).await;

    named_user_posts_a_message_in_given_channel(
        world,
        actor_name,
        *world.channel_id_by_name_ref(&channel_name),
    )
    .await;
}

#[when(regex = r#"^"([^"]+)" sends a friend request to "([^"]+)"$"#)]
async fn named_user_sends_friend_request_to_named_user(
    world: &mut NotificationsWorld,
    requester_name: String,
    addressee_name: String,
) {
    let requester = world.actor_ref(&requester_name);
    let addressee = world.actor_ref(&addressee_name);

    let response = requester
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/friends/requests/{}", addressee.user_id))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", requester.token))
                .body(Body::empty())
                .expect("send friend request request to be valid"),
        )
        .await
        .expect("send friend request response from app");

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);

    if world.latest_status() == StatusCode::CREATED {
        let friend_request_id = world
            .latest_payload
            .as_ref()
            .and_then(|payload| payload["id"].as_str())
            .expect("friend request id in payload")
            .to_owned();

        world.friend_request_ids_by_pair.insert(
            NotificationsWorld::ordered_actor_pair(&requester_name, &addressee_name),
            friend_request_id,
        );
    }
}

#[given(regex = r#"^"([^"]+)" sent a friend request to "([^"]+)"$"#)]
async fn named_user_sent_friend_request_to_named_user(
    world: &mut NotificationsWorld,
    requester_name: String,
    addressee_name: String,
) {
    named_user_sends_friend_request_to_named_user(world, requester_name, addressee_name).await;
    assert_eq!(world.latest_status(), StatusCode::CREATED);
}

#[when(regex = r#"^"([^"]+)" accepts the friend request from "([^"]+)"$"#)]
async fn named_user_accepts_the_friend_request_from_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
    requester_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let friend_request_id = world.friend_request_id_for_pair(&actor_name, &requester_name);

    let response = actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/friends/requests/{friend_request_id}/accept"
                ))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("accept friend request request to be valid"),
        )
        .await
        .expect("accept friend request response from app");

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" declines the friend request from "([^"]+)"$"#)]
async fn named_user_declines_the_friend_request_from_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
    requester_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let friend_request_id = world.friend_request_id_for_pair(&actor_name, &requester_name);

    let response = actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/friends/requests/{friend_request_id}/decline"
                ))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("decline friend request request to be valid"),
        )
        .await
        .expect("decline friend request response from app");

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" cancels the friend request to "([^"]+)"$"#)]
async fn named_user_cancels_the_friend_request_to_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
    addressee_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let friend_request_id = world.friend_request_id_for_pair(&actor_name, &addressee_name);

    let response = actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/friends/requests/{friend_request_id}/cancel"
                ))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("cancel friend request request to be valid"),
        )
        .await
        .expect("cancel friend request response from app");

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" posts a plain message in channel "([^"]+)"$"#)]
async fn named_user_posts_a_plain_message_in_channel_named(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    track_outbox_totals_before_post(world).await;

    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response = create_message_with_token(
        &actor.app,
        &channel_id,
        "plain notification-message",
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

#[when(regex = r#"^"([^"]+)" posts a message mentioning "([^"]+)" in channel "([^"]+)"$"#)]
async fn named_user_posts_a_message_mentioning_named_user_in_channel_named(
    world: &mut NotificationsWorld,
    actor_name: String,
    mentioned_user_name: String,
    channel_name: String,
) {
    track_outbox_totals_before_post(world).await;

    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let mentioned_user_id = world.actor_ref(&mentioned_user_name).user_id;
    let response = create_message_with_token_and_mention(
        &actor.app,
        &channel_id,
        "@mention notification-message",
        &mentioned_user_id,
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

#[when(regex = r#"^"([^"]+)" connects to voice for channel "([^"]+)"$"#)]
async fn named_user_connects_to_voice_for_channel_named(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response = connect_voice_session_with_token(&actor.app, &channel_id, &actor.token).await;

    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);

    assert_eq!(world.latest_status(), StatusCode::OK);
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

#[when(regex = r#"^the temporary mute expires for "([^"]+)" in channel "([^"]+)"$"#)]
async fn temporary_mute_expires_for_named_user_in_named_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response =
        unmute_channel_notifications_with_token(&actor.app, &channel_id, &actor.token).await;
    assert_eq!(response.status(), StatusCode::NO_CONTENT);
}

#[when(regex = r#"^"([^"]+)" globally unmutes notifications$"#)]
async fn named_user_globally_unmutes_notifications(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let response = update_global_notification_preference_with_token(
        &actor.app,
        NotificationMuteState::Unmuted,
        &actor.token,
    )
    .await;
    assert_eq!(response.status(), StatusCode::NO_CONTENT);
}

#[when(regex = r#"^"([^"]+)" unmutes server "([^"]+)"$"#)]
async fn named_user_unmutes_named_server(
    world: &mut NotificationsWorld,
    actor_name: String,
    server_name: String,
) {
    let server_id = *world.server_id_by_name_ref(&server_name);
    world.server_id = Some(server_id);

    let actor = world.actor_ref(&actor_name);
    let response = update_server_notification_preference_with_token(
        &actor.app,
        &server_id,
        NotificationMuteState::Unmuted,
        &actor.token,
    )
    .await;

    assert_eq!(response.status(), StatusCode::NO_CONTENT);
}

#[then(regex = r#"^a durable notification record is stored for "([^"]+)"$"#)]
async fn a_durable_notification_record_is_stored_for_named_user(
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

    assert_eq!(
        outbox_count, 1,
        "Expected a durable notification record to be stored for {}",
        recipient_name
    );
}

#[then(regex = r#"^no durable notification record is stored for "([^"]+)" for the last message$"#)]
async fn no_durable_notification_record_is_stored_for_named_user_for_last_message(
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

    assert_eq!(
        outbox_count, 0,
        "Expected no durable notification record to be stored for {} for the last message",
        recipient_name
    );
}

#[then(regex = r#"^no durable notification record is stored for "([^"]+)"$"#)]
async fn no_durable_notification_record_is_stored_for_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let actor = world.actor_ref(&actor_name);

    let after_count = outbox_total_count_for_recipient(&world.shared_store, actor.user_id).await;

    let before_count = *world
        .outbox_totals_before_post_by_actor
        .get(&actor_name)
        .expect("outbox count before posting to be tracked");

    assert_eq!(
        after_count, before_count,
        "Expected no durable notification record to be stored for {}",
        actor_name
    );
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

#[then(regex = r#"^unread count increments for "([^"]+)" in channel "([^"]+)"$"#)]
async fn unread_count_increments_for_named_user_in_named_channel(
    world: &mut NotificationsWorld,
    recipient_name: String,
    channel_name: String,
) {
    let recipient = world.actor_ref(&recipient_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let unread_count =
        unread_count_for_channel(&world.shared_store, recipient.user_id, channel_id).await;

    assert_eq!(unread_count, 1);
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

#[then(regex = r#"^"([^"]+)" sees global notification preference mute state is (muted|unmuted)$"#)]
async fn named_user_sees_global_notification_preference_mute_state_is(
    world: &mut NotificationsWorld,
    actor_name: String,
    expected_state: String,
) {
    let actor = world.actor_ref(&actor_name);
    let response = global_notification_preference_with_token(&actor.app, &actor.token).await;

    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;
    let mute_state = payload["mute_state"]
        .as_str()
        .expect("mute_state to be present");

    assert_eq!(mute_state, expected_state);
}

#[then(regex = r#"^"([^"]+)" sees server notification preference mute state is (muted|unmuted)$"#)]
async fn named_user_sees_server_notification_preference_mute_state_is(
    world: &mut NotificationsWorld,
    actor_name: String,
    expected_state: String,
) {
    let actor = world.actor_ref(&actor_name);
    let response =
        server_notification_preference_with_token(&actor.app, world.server_id_ref(), &actor.token)
            .await;

    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;
    let mute_state = payload["mute_state"]
        .as_str()
        .expect("mute_state to be present");

    assert_eq!(mute_state, expected_state);
}

#[then(
    regex = r#"^"([^"]+)" sees channel "([^"]+)" notification preference mute state is (muted|unmuted)$"#
)]
async fn named_user_sees_named_channel_notification_preference_mute_state_is(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
    expected_state: String,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response =
        channel_notification_preference_with_token(&actor.app, &channel_id, &actor.token).await;

    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;
    let mute_state = payload["mute_state"]
        .as_str()
        .expect("mute_state to be present");

    assert_eq!(mute_state, expected_state);
}

#[then(regex = r#"^"([^"]+)" sees channel "([^"]+)" mute expiry timestamp is (present|absent)$"#)]
async fn named_user_sees_named_channel_mute_expiry_timestamp_is(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
    expected_presence: String,
) {
    let actor = world.actor_ref(&actor_name);
    let channel_id = *world.channel_id_by_name_ref(&channel_name);
    let response =
        channel_notification_preference_with_token(&actor.app, &channel_id, &actor.token).await;

    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;
    let mute_expiry = payload["muted_until_epoch_seconds"].as_u64();

    match expected_presence.as_str() {
        "present" => assert!(mute_expiry.is_some(), "expected mute expiry to be present"),
        "absent" => assert!(mute_expiry.is_none(), "expected mute expiry to be absent"),
        _ => panic!("expected presence to be either present or absent"),
    }
}

#[then(regex = r#"^"([^"]+)" receives a message-created live notification for channel "([^"]+)"$"#)]
async fn named_user_receives_message_created_live_notification_for_named_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("live notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(event["event_type"].as_str(), Some("mentioned"));
    let expected_server_id = world.server_id.expect("server id to be set").to_string();
    assert_eq!(
        event["server_id"].as_str(),
        Some(expected_server_id.as_str())
    );
    assert!(
        event["server_name"].as_str().is_some(),
        "expected server_name in live notification event"
    );
    let expected_channel_id = world.channel_id_by_name_ref(&channel_name).to_string();
    assert_eq!(
        event["channel_id"].as_str(),
        Some(expected_channel_id.as_str())
    );
    assert_eq!(event["channel_name"].as_str(), Some(channel_name.as_str()));
    assert!(
        event["message_id"].as_str().is_some(),
        "expected message_id in message-created live notification event"
    );
    assert!(
        event["joined_user_id"].is_null(),
        "expected joined_user_id to be absent for message-created live notification event"
    );
    assert!(
        event["joined_user_display_name"].is_null(),
        "expected joined_user_display_name to be absent for message-created live notification event"
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(regex = r#"^"([^"]+)" receives a mentioned live notification for channel "([^"]+)"$"#)]
async fn named_user_receives_mentioned_live_notification_for_named_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("live notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(event["event_type"].as_str(), Some("mentioned"));
    let expected_channel_id = world.channel_id_by_name_ref(&channel_name).to_string();
    assert_eq!(
        event["channel_id"].as_str(),
        Some(expected_channel_id.as_str())
    );
    assert_eq!(event["channel_name"].as_str(), Some(channel_name.as_str()));
    assert!(
        event["message_id"].as_str().is_some(),
        "expected message_id in mentioned live notification event"
    );
    assert!(
        event["joined_user_id"].is_null(),
        "expected joined_user_id to be absent for mentioned live notification event"
    );
    assert!(
        event["joined_user_display_name"].is_null(),
        "expected joined_user_display_name to be absent for mentioned live notification event"
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(regex = r#"^"([^"]+)" receives an unread-message live notification for channel "([^"]+)"$"#)]
async fn named_user_receives_unread_message_live_notification_for_named_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("live notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(event["event_type"].as_str(), Some("unread_message"));
    let expected_channel_id = world.channel_id_by_name_ref(&channel_name).to_string();
    assert_eq!(
        event["channel_id"].as_str(),
        Some(expected_channel_id.as_str())
    );
    assert_eq!(event["channel_name"].as_str(), Some(channel_name.as_str()));
    assert!(
        event["message_id"].as_str().is_some(),
        "expected message_id in unread-message live notification event"
    );
    assert!(
        event["joined_user_id"].is_null(),
        "expected joined_user_id to be absent for unread-message live notification event"
    );
    assert!(
        event["joined_user_display_name"].is_null(),
        "expected joined_user_display_name to be absent for unread-message live notification event"
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(
    regex = r#"^"([^"]+)" receives a friend-joined-voice live notification for channel "([^"]+)" from "([^"]+)"$"#
)]
async fn named_user_receives_friend_joined_voice_live_notification_for_named_channel_from_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
    channel_name: String,
    joined_user_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("live notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::OK);
    assert_eq!(event["event_type"].as_str(), Some("friend_joined_voice"));

    let expected_server_id = world.server_id.expect("server id to be set").to_string();
    assert_eq!(
        event["server_id"].as_str(),
        Some(expected_server_id.as_str())
    );

    let expected_channel_id = world.channel_id_by_name_ref(&channel_name).to_string();
    assert_eq!(
        event["channel_id"].as_str(),
        Some(expected_channel_id.as_str())
    );
    assert_eq!(event["channel_name"].as_str(), Some(channel_name.as_str()));
    assert!(
        event["message_id"].is_null(),
        "expected message_id to be absent for friend-joined-voice live notification event"
    );

    let expected_joined_user_id = world.actor_ref(&joined_user_name).user_id.to_string();
    assert_eq!(
        event["joined_user_id"].as_str(),
        Some(expected_joined_user_id.as_str())
    );
    let joined_user_display_name = event["joined_user_display_name"]
        .as_str()
        .expect("expected joined_user_display_name");
    assert!(
        joined_user_display_name == joined_user_name
            || joined_user_display_name == expected_joined_user_id,
        "expected joined_user_display_name to match actor name or user id"
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(
    regex = r#"^"([^"]+)" receives a friend-request-received live notification from "([^"]+)"$"#
)]
async fn named_user_receives_friend_request_received_live_notification_from_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
    requester_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("live notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(
        event["event_type"].as_str(),
        Some("friend_request_received")
    );

    let requester = world.actor_ref(&requester_name);
    let addressee = world.actor_ref(&actor_name);
    assert_eq!(
        event["requester_user_id"].as_str(),
        Some(requester.user_id.to_string().as_str())
    );
    assert_eq!(
        event["addressee_user_id"].as_str(),
        Some(addressee.user_id.to_string().as_str())
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(
    regex = r#"^"([^"]+)" receives a friend-request-accepted live notification from "([^"]+)"$"#
)]
async fn named_user_receives_friend_request_accepted_live_notification_from_named_user(
    world: &mut NotificationsWorld,
    actor_name: String,
    accepter_name: String,
) {
    let event = world
        .next_ws_event(Duration::from_secs(2))
        .await
        .expect("live notification event to be received");

    assert_eq!(world.latest_status(), StatusCode::OK);
    assert_eq!(
        event["event_type"].as_str(),
        Some("friend_request_accepted")
    );

    let requester = world.actor_ref(&actor_name);
    let addressee = world.actor_ref(&accepter_name);
    assert_eq!(
        event["requester_user_id"].as_str(),
        Some(requester.user_id.to_string().as_str())
    );
    assert_eq!(
        event["addressee_user_id"].as_str(),
        Some(addressee.user_id.to_string().as_str())
    );

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

async fn named_user_does_not_receive_live_notification_events_for_that_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
) {
    let event = world.next_ws_event(Duration::from_millis(600)).await;
    assert!(event.is_none(), "unexpected live notification payload");

    let ws_connection = world
        .active_ws_connection
        .as_ref()
        .expect("active live notification stream connection to be set");
    assert_eq!(ws_connection.actor_name, actor_name);
}

#[then(regex = r#"^"([^"]+)" does not receive live notifications for channel "([^"]+)"$"#)]
async fn named_user_does_not_receive_live_notification_events_for_named_channel(
    world: &mut NotificationsWorld,
    actor_name: String,
    _channel_name: String,
) {
    named_user_does_not_receive_live_notification_events_for_that_channel(world, actor_name).await;
}

async fn posting_is_denied_because_that_channel_does_not_support_messaging(
    world: &mut NotificationsWorld,
) {
    assert_eq!(world.latest_status(), StatusCode::UNPROCESSABLE_ENTITY);
}

#[then(regex = r#"^posting is denied because channel "([^"]+)" does not support messaging$"#)]
async fn posting_is_denied_because_named_channel_does_not_support_messaging(
    world: &mut NotificationsWorld,
    _channel_name: String,
) {
    posting_is_denied_because_that_channel_does_not_support_messaging(world).await;
}

async fn ensure_named_server_for_owner(
    world: &mut NotificationsWorld,
    server_name: &str,
    owner_name: &str,
) -> ServerId {
    if let Some(existing_server_id) = world.server_ids_by_name.get(server_name) {
        assert_server_owner(world, server_name, owner_name);
        return *existing_server_id;
    }

    let owner = world.actor_ref(owner_name).clone();
    let server_payload = response_payload_json(
        create_server_with_token(&owner.app, server_name, &owner.token).await,
    )
    .await;
    let server_id = payload_server_id(&server_payload, "id");
    world
        .server_ids_by_name
        .insert(server_name.to_owned(), server_id);
    world
        .server_owner_by_name
        .insert(server_name.to_owned(), owner_name.to_owned());

    server_id
}

fn assert_server_owner(world: &NotificationsWorld, server_name: &str, owner_name: &str) {
    let configured_owner = world
        .server_owner_by_name
        .get(server_name)
        .unwrap_or_else(|| panic!("server {server_name} owner to be set"));

    assert_eq!(
        configured_owner, owner_name,
        "referenced server owner must match the initialized server"
    );
}

async fn create_text_channel_for_named_server(
    world: &mut NotificationsWorld,
    server_name: &str,
    owner_name: &str,
    channel_name: &str,
) -> ChannelId {
    let server_id = ensure_named_server_for_owner(world, server_name, owner_name).await;
    world.server_id = Some(server_id);

    let owner = world.actor_ref(owner_name);
    let channel_payload = response_payload_json(
        create_channel_with_token(&owner.app, &server_id, channel_name, "text", &owner.token).await,
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
    let mentioned_user_id = world
        .actors
        .get("Noah")
        .map(|recipient| recipient.user_id)
        .filter(|user_id| *user_id != actor.user_id);
    let response = if let Some(mentioned_user_id) = mentioned_user_id {
        create_message_with_token_and_mention(
            &actor.app,
            &channel_id,
            "@noah notification-message",
            &mentioned_user_id,
            &actor.token,
        )
        .await
    } else {
        create_message_with_token(
            &actor.app,
            &channel_id,
            "notification-message",
            &actor.token,
        )
        .await
    };

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

async fn track_outbox_totals_before_post(world: &mut NotificationsWorld) {
    world.outbox_totals_before_post_by_actor.clear();

    for (name, actor) in &world.actors {
        let outbox_count =
            outbox_total_count_for_recipient(&world.shared_store, actor.user_id).await;
        world
            .outbox_totals_before_post_by_actor
            .insert(name.to_owned(), outbox_count);
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

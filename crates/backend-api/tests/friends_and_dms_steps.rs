mod common;

use std::collections::HashMap;

use axum::body::Body;
use axum::http::{Request, StatusCode, header};
use common::bdd_support::{
    Actor, FriendNotificationEventType, SharedTestStore, add_server_member_with_token,
    create_actor, create_server_with_token, default_shared_store, fresh_shared_store,
    outbox_count_for_friend_notification, payload_server_id, prime_feature_test_store,
    response_payload_json, shutdown_feature_test_store,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use tower::ServiceExt;

const FEATURE_PATH: &str = "../../features/friends_and_dms.feature";

#[derive(Debug, cucumber::World)]
struct FriendsAndDirectMessagesWorld {
    shared_store: SharedTestStore,
    actors: HashMap<String, Actor>,
    friend_request_ids_by_pair: HashMap<(String, String), String>,
    direct_message_thread_ids_by_pair: HashMap<(String, String), String>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    latest_direct_message_content: Option<String>,
    first_opened_thread_id: Option<String>,
    second_opened_thread_id: Option<String>,
}

impl Default for FriendsAndDirectMessagesWorld {
    fn default() -> Self {
        Self {
            shared_store: default_shared_store(),
            actors: HashMap::new(),
            friend_request_ids_by_pair: HashMap::new(),
            direct_message_thread_ids_by_pair: HashMap::new(),
            latest_status: None,
            latest_payload: None,
            latest_direct_message_content: None,
            first_opened_thread_id: None,
            second_opened_thread_id: None,
        }
    }
}

impl FriendsAndDirectMessagesWorld {
    fn actor_ref(&self, name: &str) -> &Actor {
        self.actors
            .get(name)
            .unwrap_or_else(|| panic!("actor {name} to exist"))
    }

    fn ordered_pair(first: &str, second: &str) -> (String, String) {
        if first <= second {
            (first.to_owned(), second.to_owned())
        } else {
            (second.to_owned(), first.to_owned())
        }
    }

    fn friend_request_id_for_pair(&self, requester_name: &str, addressee_name: &str) -> &str {
        let pair = Self::ordered_pair(requester_name, addressee_name);
        self.friend_request_ids_by_pair
            .get(&pair)
            .unwrap_or_else(|| {
                panic!("friend request id for pair {requester_name}-{addressee_name} to exist")
            })
    }

    fn direct_message_thread_id_for_pair(&self, first_name: &str, second_name: &str) -> &str {
        let pair = Self::ordered_pair(first_name, second_name);
        self.direct_message_thread_ids_by_pair
            .get(&pair)
            .unwrap_or_else(|| {
                panic!("direct message thread id for pair {first_name}-{second_name} to exist")
            })
    }

    fn latest_status_ref(&self) -> StatusCode {
        self.latest_status.expect("latest status to be set")
    }
}

async fn send_friend_request(
    actor: &Actor,
    target_user_id: backend_api::domain::UserId,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/friends/requests/{target_user_id}"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("send friend request request to be valid"),
        )
        .await
        .expect("send friend request response from app")
}

async fn list_friends(actor: &Actor) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/friends")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("list friends request to be valid"),
        )
        .await
        .expect("list friends response from app")
}

async fn list_incoming_friend_requests(actor: &Actor) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri("/api/v1/friends/requests/incoming")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("list incoming friend requests request to be valid"),
        )
        .await
        .expect("list incoming friend requests response from app")
}

async fn set_friend_request_state(
    actor: &Actor,
    friend_request_id: &str,
    action: &str,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!(
                    "/api/v1/friends/requests/{friend_request_id}/{action}"
                ))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("set friend request state request to be valid"),
        )
        .await
        .expect("set friend request state response from app")
}

async fn open_direct_message_thread(
    actor: &Actor,
    other_user_id: backend_api::domain::UserId,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/dms/threads/{other_user_id}"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("open direct message thread request to be valid"),
        )
        .await
        .expect("open direct message thread response from app")
}

async fn send_direct_message(
    actor: &Actor,
    thread_id: &str,
    content: &str,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/dms/threads/{thread_id}/messages"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(
                    serde_json::json!({ "content": content }).to_string(),
                ))
                .expect("send direct message request to be valid"),
        )
        .await
        .expect("send direct message response from app")
}

async fn list_direct_messages(actor: &Actor, thread_id: &str) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/dms/threads/{thread_id}/messages"))
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("list direct messages request to be valid"),
        )
        .await
        .expect("list direct messages response from app")
}

async fn search_direct_messages(
    actor: &Actor,
    other_user_id: backend_api::domain::UserId,
    query: &str,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/dms/search/{other_user_id}?q={query}"))
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("search direct messages request to be valid"),
        )
        .await
        .expect("search direct messages response from app")
}

async fn block_user(
    actor: &Actor,
    target_user_id: backend_api::domain::UserId,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/blocks/{target_user_id}"))
                .method("POST")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("block user request to be valid"),
        )
        .await
        .expect("block user response from app")
}

async fn unblock_user(
    actor: &Actor,
    target_user_id: backend_api::domain::UserId,
) -> axum::response::Response {
    actor
        .app
        .clone()
        .oneshot(
            Request::builder()
                .uri(format!("/api/v1/blocks/{target_user_id}"))
                .method("DELETE")
                .header(header::AUTHORIZATION, format!("Bearer {}", actor.token))
                .body(Body::empty())
                .expect("unblock user request to be valid"),
        )
        .await
        .expect("unblock user response from app")
}

#[given(regex = r#"^a user named "([^"]+)" exists$"#)]
async fn a_user_named_exists(world: &mut FriendsAndDirectMessagesWorld, name: String) {
    if world.actors.contains_key(&name) {
        return;
    }

    if world.actors.is_empty() {
        world.shared_store = fresh_shared_store().await;
    }

    let token = format!("token-{}", name.to_lowercase());
    let actor = create_actor(&name, &token, world.shared_store.clone()).await;
    world.actors.insert(name, actor);
}

#[given(regex = r#"^"([^"]+)" sent a friend request to "([^"]+)"$"#)]
async fn named_user_sent_friend_request_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    requester_name: String,
    addressee_name: String,
) {
    let requester = world.actor_ref(&requester_name);
    let addressee = world.actor_ref(&addressee_name);

    let response = send_friend_request(requester, addressee.user_id).await;
    assert_eq!(response.status(), StatusCode::CREATED);
    let payload = response_payload_json(response).await;

    let friend_request_id = payload["id"]
        .as_str()
        .expect("friend request id to be present")
        .to_owned();

    world.friend_request_ids_by_pair.insert(
        FriendsAndDirectMessagesWorld::ordered_pair(&requester_name, &addressee_name),
        friend_request_id,
    );
}

#[given(regex = r#"^"([^"]+)" and "([^"]+)" are friends$"#)]
async fn named_users_are_friends(
    world: &mut FriendsAndDirectMessagesWorld,
    first_name: String,
    second_name: String,
) {
    named_user_sent_friend_request_to_named_user(world, first_name.clone(), second_name.clone())
        .await;

    let second = world.actor_ref(&second_name);
    let friend_request_id = world
        .friend_request_id_for_pair(&first_name, &second_name)
        .to_owned();

    let response = set_friend_request_state(second, &friend_request_id, "accept").await;
    assert_eq!(response.status(), StatusCode::OK);
}

#[given(regex = r#"^a direct message thread exists between "([^"]+)" and "([^"]+)"$"#)]
async fn direct_message_thread_exists_between_named_users(
    world: &mut FriendsAndDirectMessagesWorld,
    first_name: String,
    second_name: String,
) {
    let first = world.actor_ref(&first_name);
    let second = world.actor_ref(&second_name);

    let response = open_direct_message_thread(first, second.user_id).await;
    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;
    let thread_id = payload["id"]
        .as_str()
        .expect("direct message thread id to be present")
        .to_owned();

    world.direct_message_thread_ids_by_pair.insert(
        FriendsAndDirectMessagesWorld::ordered_pair(&first_name, &second_name),
        thread_id,
    );
}

#[given(regex = r#"^"([^"]+)" sent a direct message containing "([^"]+)" to "([^"]+)"$"#)]
async fn named_user_sent_direct_message_containing_text_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    author_name: String,
    text: String,
    recipient_name: String,
) {
    if !world.direct_message_thread_ids_by_pair.contains_key(
        &FriendsAndDirectMessagesWorld::ordered_pair(&author_name, &recipient_name),
    ) {
        direct_message_thread_exists_between_named_users(
            world,
            author_name.clone(),
            recipient_name.clone(),
        )
        .await;
    }

    let thread_id = world
        .direct_message_thread_id_for_pair(&author_name, &recipient_name)
        .to_owned();
    let author = world.actor_ref(&author_name);

    let response = send_direct_message(author, &thread_id, &text).await;
    assert_eq!(response.status(), StatusCode::CREATED);
}

#[given(regex = r#"^"([^"]+)" blocked "([^"]+)"$"#)]
async fn named_user_blocked_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    blocker_name: String,
    blocked_name: String,
) {
    let blocker = world.actor_ref(&blocker_name);
    let blocked = world.actor_ref(&blocked_name);

    let response = block_user(blocker, blocked.user_id).await;
    assert!(response.status() == StatusCode::CREATED || response.status() == StatusCode::OK);
}

#[given(regex = r#"^a server named "([^"]+)" owned by "([^"]+)" exists$"#)]
async fn a_server_named_owned_by_named_user_exists(
    world: &mut FriendsAndDirectMessagesWorld,
    server_name: String,
    owner_name: String,
) {
    let owner = world.actor_ref(&owner_name);
    let response = create_server_with_token(&owner.app, &server_name, &owner.token).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
    assert_eq!(world.latest_status_ref(), StatusCode::CREATED);
}

#[given(regex = r#"^"([^"]+)" adds "([^"]+)" to server "([^"]+)"$"#)]
async fn named_user_adds_named_user_to_server(
    world: &mut FriendsAndDirectMessagesWorld,
    owner_name: String,
    member_name: String,
    _server_name: String,
) {
    let owner = world.actor_ref(&owner_name);
    let member = world.actor_ref(&member_name);

    let latest_payload = world
        .latest_payload
        .as_ref()
        .expect("latest payload with server id to be set");
    let server_id = payload_server_id(
        &serde_json::json!({"user_id": latest_payload["id"]}),
        "user_id",
    );

    let response =
        add_server_member_with_token(&owner.app, &server_id, &member.user_id, &owner.token).await;
    assert!(matches!(
        response.status(),
        StatusCode::NO_CONTENT | StatusCode::CREATED
    ));
}

#[when(regex = r#"^"([^"]+)" sends a friend request to "([^"]+)"$"#)]
async fn named_user_sends_friend_request_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    requester_name: String,
    addressee_name: String,
) {
    let requester = world.actor_ref(&requester_name);
    let addressee = world.actor_ref(&addressee_name);

    let response = send_friend_request(requester, addressee.user_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);

    if world.latest_status_ref() == StatusCode::CREATED {
        let friend_request_id = world.latest_payload.as_ref().expect("latest payload")["id"]
            .as_str()
            .expect("friend request id to be present")
            .to_owned();
        world.friend_request_ids_by_pair.insert(
            FriendsAndDirectMessagesWorld::ordered_pair(&requester_name, &addressee_name),
            friend_request_id,
        );
    }
}

#[when(regex = r#"^"([^"]+)" accepts the friend request from "([^"]+)"$"#)]
async fn named_user_accepts_the_friend_request_from_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    actor_name: String,
    requester_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let friend_request_id = world
        .friend_request_id_for_pair(&requester_name, &actor_name)
        .to_owned();

    let response = set_friend_request_state(actor, &friend_request_id, "accept").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" declines the friend request from "([^"]+)"$"#)]
async fn named_user_declines_the_friend_request_from_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    actor_name: String,
    requester_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let friend_request_id = world
        .friend_request_id_for_pair(&requester_name, &actor_name)
        .to_owned();

    let response = set_friend_request_state(actor, &friend_request_id, "decline").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" cancels the friend request to "([^"]+)"$"#)]
async fn named_user_cancels_the_friend_request_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    actor_name: String,
    addressee_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let friend_request_id = world
        .friend_request_id_for_pair(&actor_name, &addressee_name)
        .to_owned();

    let response = set_friend_request_state(actor, &friend_request_id, "cancel").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" opens a direct message thread with "([^"]+)"$"#)]
async fn named_user_opens_direct_message_thread_with_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    actor_name: String,
    other_name: String,
) {
    let actor = world.actor_ref(&actor_name);
    let other = world.actor_ref(&other_name);

    let response = open_direct_message_thread(actor, other.user_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);

    if world.latest_status_ref() == StatusCode::OK {
        let thread_id = world.latest_payload.as_ref().expect("latest payload")["id"]
            .as_str()
            .expect("thread id to be present")
            .to_owned();

        if world.first_opened_thread_id.is_none() {
            world.first_opened_thread_id = Some(thread_id.clone());
        } else {
            world.second_opened_thread_id = Some(thread_id.clone());
        }

        world.direct_message_thread_ids_by_pair.insert(
            FriendsAndDirectMessagesWorld::ordered_pair(&actor_name, &other_name),
            thread_id,
        );
    }
}

#[when(regex = r#"^"([^"]+)" opens a direct message thread with "([^"]+)" again$"#)]
async fn named_user_opens_direct_message_thread_with_named_user_again(
    world: &mut FriendsAndDirectMessagesWorld,
    actor_name: String,
    other_name: String,
) {
    named_user_opens_direct_message_thread_with_named_user(world, actor_name, other_name).await;
}

#[when(regex = r#"^"([^"]+)" sends a direct message to "([^"]+)"$"#)]
async fn named_user_sends_a_direct_message_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    author_name: String,
    recipient_name: String,
) {
    let author = world.actor_ref(&author_name);
    let recipient = world.actor_ref(&recipient_name);

    let pair = FriendsAndDirectMessagesWorld::ordered_pair(&author_name, &recipient_name);
    if let Some(thread_id) = world.direct_message_thread_ids_by_pair.get(&pair) {
        let content = "hello from direct message";
        let response = send_direct_message(author, thread_id, content).await;
        world.latest_status = Some(response.status());
        world.latest_payload = Some(response_payload_json(response).await);
        world.latest_direct_message_content = Some(content.to_owned());
        return;
    }

    let open_response = open_direct_message_thread(author, recipient.user_id).await;
    world.latest_status = Some(open_response.status());
    world.latest_payload = Some(response_payload_json(open_response).await);
}

#[when(regex = r#"^"([^"]+)" searches direct messages with "([^"]+)" for "([^"]+)"$"#)]
async fn named_user_searches_direct_messages_with_named_user_for_query(
    world: &mut FriendsAndDirectMessagesWorld,
    actor_name: String,
    other_name: String,
    query: String,
) {
    let actor = world.actor_ref(&actor_name);
    let other = world.actor_ref(&other_name);

    let response = search_direct_messages(actor, other.user_id, &query).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" blocks "([^"]+)"$"#)]
async fn named_user_blocks_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    blocker_name: String,
    blocked_name: String,
) {
    let blocker = world.actor_ref(&blocker_name);
    let blocked = world.actor_ref(&blocked_name);

    let response = block_user(blocker, blocked.user_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when(regex = r#"^"([^"]+)" unblocks "([^"]+)"$"#)]
async fn named_user_unblocks_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    blocker_name: String,
    blocked_name: String,
) {
    let blocker = world.actor_ref(&blocker_name);
    let blocked = world.actor_ref(&blocked_name);

    let response = unblock_user(blocker, blocked.user_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when(regex = r#"^"([^"]+)" sends a friend request to "([^"]+)" from server "([^"]+)"$"#)]
async fn named_user_sends_friend_request_to_named_user_from_server(
    world: &mut FriendsAndDirectMessagesWorld,
    requester_name: String,
    addressee_name: String,
    _server_name: String,
) {
    named_user_sends_friend_request_to_named_user(world, requester_name, addressee_name).await;
}

#[then(regex = r#"^"([^"]+)" is included in the friend list for "([^"]+)"$"#)]
async fn named_user_is_included_in_friend_list_for_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    expected_friend_name: String,
    owner_name: String,
) {
    let owner = world.actor_ref(&owner_name);
    let expected_friend = world.actor_ref(&expected_friend_name);

    let response = list_friends(owner).await;
    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;

    let list = payload.as_array().expect("friends payload to be array");
    assert!(
        list.iter().any(|entry| {
            entry["user_id"].as_str() == Some(&expected_friend.user_id.to_string())
        })
    );
}

#[then(regex = r#"^"([^"]+)" is not included in the friend list for "([^"]+)"$"#)]
async fn named_user_is_not_included_in_friend_list_for_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    unexpected_friend_name: String,
    owner_name: String,
) {
    let owner = world.actor_ref(&owner_name);
    let unexpected_friend = world.actor_ref(&unexpected_friend_name);

    let response = list_friends(owner).await;
    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;

    let list = payload.as_array().expect("friends payload to be array");
    assert!(!list.iter().any(|entry| {
        entry["user_id"].as_str() == Some(&unexpected_friend.user_id.to_string())
    }));
}

#[then(regex = r#"^"([^"]+)" has no pending friend request from "([^"]+)"$"#)]
async fn named_user_has_no_pending_friend_request_from_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    addressee_name: String,
    requester_name: String,
) {
    let addressee = world.actor_ref(&addressee_name);
    let requester = world.actor_ref(&requester_name);

    let response = list_incoming_friend_requests(addressee).await;
    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;

    let list = payload
        .as_array()
        .expect("incoming requests payload to be array");
    assert!(!list.iter().any(|entry| {
        entry["requester_user_id"].as_str() == Some(&requester.user_id.to_string())
    }));
}

#[then("both thread openings resolve to the same direct message thread")]
async fn both_thread_openings_resolve_to_the_same_direct_message_thread(
    world: &mut FriendsAndDirectMessagesWorld,
) {
    assert_eq!(world.latest_status_ref(), StatusCode::OK);
    assert_eq!(
        world.first_opened_thread_id.as_deref(),
        world.second_opened_thread_id.as_deref()
    );
}

#[then(
    regex = r#"^listing direct messages between "([^"]+)" and "([^"]+)" includes the new message$"#
)]
async fn listing_direct_messages_between_named_users_includes_the_new_message(
    world: &mut FriendsAndDirectMessagesWorld,
    first_name: String,
    second_name: String,
) {
    let first = world.actor_ref(&first_name);
    let thread_id = world
        .direct_message_thread_id_for_pair(&first_name, &second_name)
        .to_owned();

    let response = list_direct_messages(first, &thread_id).await;
    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;

    let expected_content = world
        .latest_direct_message_content
        .as_deref()
        .unwrap_or("hello from direct message");

    let list = payload
        .as_array()
        .expect("direct messages payload to be array");
    assert!(
        list.iter()
            .any(|entry| entry["content"].as_str() == Some(expected_content))
    );
}

#[then("direct messaging is denied because they are not friends")]
async fn direct_messaging_is_denied_because_they_are_not_friends(
    world: &mut FriendsAndDirectMessagesWorld,
) {
    assert_eq!(world.latest_status_ref(), StatusCode::FORBIDDEN);
}

#[then("direct message search is denied")]
async fn direct_message_search_is_denied(world: &mut FriendsAndDirectMessagesWorld) {
    assert_eq!(world.latest_status_ref(), StatusCode::FORBIDDEN);
}

#[then(regex = r#"^"([^"]+)" cannot send a friend request to "([^"]+)"$"#)]
async fn named_user_cannot_send_friend_request_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    requester_name: String,
    addressee_name: String,
) {
    named_user_sends_friend_request_to_named_user(world, requester_name, addressee_name).await;
    assert_eq!(world.latest_status_ref(), StatusCode::FORBIDDEN);
}

#[then(regex = r#"^"([^"]+)" cannot send a direct message to "([^"]+)"$"#)]
async fn named_user_cannot_send_direct_message_to_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    sender_name: String,
    recipient_name: String,
) {
    named_user_sends_a_direct_message_to_named_user(world, sender_name, recipient_name).await;
    assert_eq!(world.latest_status_ref(), StatusCode::FORBIDDEN);
}

#[then(regex = r#"^"([^"]+)" has a pending friend request from "([^"]+)"$"#)]
async fn named_user_has_a_pending_friend_request_from_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    addressee_name: String,
    requester_name: String,
) {
    let addressee = world.actor_ref(&addressee_name);
    let requester = world.actor_ref(&requester_name);

    let response = list_incoming_friend_requests(addressee).await;
    assert_eq!(response.status(), StatusCode::OK);
    let payload = response_payload_json(response).await;

    let list = payload
        .as_array()
        .expect("incoming requests payload to be array");
    assert!(list.iter().any(|entry| {
        entry["requester_user_id"].as_str() == Some(&requester.user_id.to_string())
            && entry["state"].as_str() == Some("pending")
    }));
}

#[then(regex = r#"^"([^"]+)" receives one friend request notification from "([^"]+)"$"#)]
async fn named_user_receives_one_friend_request_notification_from_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    recipient_name: String,
    actor_name: String,
) {
    let recipient = world.actor_ref(&recipient_name);
    let actor = world.actor_ref(&actor_name);

    let count = outbox_count_for_friend_notification(
        &world.shared_store,
        recipient.user_id,
        actor.user_id,
        FriendNotificationEventType::FriendRequestReceived,
    )
    .await;

    assert_eq!(count, 1);
}

#[then(regex = r#"^"([^"]+)" receives one friend request accepted notification from "([^"]+)"$"#)]
async fn named_user_receives_one_friend_request_accepted_notification_from_named_user(
    world: &mut FriendsAndDirectMessagesWorld,
    recipient_name: String,
    actor_name: String,
) {
    let recipient = world.actor_ref(&recipient_name);
    let actor = world.actor_ref(&actor_name);

    let count = outbox_count_for_friend_notification(
        &world.shared_store,
        recipient.user_id,
        actor.user_id,
        FriendNotificationEventType::FriendRequestAccepted,
    )
    .await;

    assert_eq!(count, 1);
}

#[tokio::test]
async fn friends_and_direct_messages_feature() {
    prime_feature_test_store().await;
    FriendsAndDirectMessagesWorld::cucumber()
        .run_and_exit(FEATURE_PATH)
        .await;
    shutdown_feature_test_store().await;
}

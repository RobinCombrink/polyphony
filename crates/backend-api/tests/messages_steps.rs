mod common;

use std::sync::Arc;

use axum::http::StatusCode;
use common::{
    bdd_support::{
        ChannelId, MessageId, ServerId, SharedTestStore, create_channel_with_token, create_message,
        create_message_with_token, create_server_with_token, default_shared_store, delete_message,
        delete_message_with_token, fresh_shared_store, list_messages, list_messages_with_token,
        payload_channel_id, payload_message_id, payload_server_id, prime_feature_test_store,
        response_payload_json, seeded_app_with_store, shutdown_feature_test_store, update_message,
        update_message_with_token,
    },
    entity_seeder::EntitySeeder,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use uuid::Uuid;

const FEATURE_PATH: &str = "../../features/messages.feature";

#[derive(Debug, cucumber::World)]
struct MessagesWorld {
    owner_app: axum::Router,
    second_app: Option<axum::Router>,
    shared_store: SharedTestStore,
    server_id: Option<ServerId>,
    channel_id: Option<ChannelId>,
    message_id: Option<MessageId>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    owner_token: String,
    owner_name: Option<String>,
    second_name: Option<String>,
}

impl Default for MessagesWorld {
    fn default() -> Self {
        Self {
            owner_app: axum::Router::new(),
            second_app: None,
            shared_store: default_shared_store(),
            server_id: None,
            channel_id: None,
            message_id: None,
            latest_status: None,
            latest_payload: None,
            owner_token: String::new(),
            owner_name: None,
            second_name: None,
        }
    }
}

impl MessagesWorld {
    fn owner_app_ref(&self) -> &axum::Router {
        &self.owner_app
    }

    fn second_app_ref(&self) -> &axum::Router {
        self.second_app
            .as_ref()
            .expect("second app to be initialized")
    }

    fn server_id_ref(&self) -> &ServerId {
        self.server_id.as_ref().expect("server id to be set")
    }

    fn channel_id_ref(&self) -> &ChannelId {
        self.channel_id.as_ref().expect("channel id to be set")
    }

    fn message_id_ref(&self) -> &MessageId {
        self.message_id.as_ref().expect("message id to be set")
    }

    fn latest_status(&self) -> StatusCode {
        self.latest_status.expect("latest status to be set")
    }

    fn latest_payload_ref(&self) -> &Value {
        self.latest_payload
            .as_ref()
            .expect("latest payload to be set")
    }

    fn owner_token(&self) -> &str {
        if self.owner_token.is_empty() {
            return "valid-token";
        }

        self.owner_token.as_str()
    }

    fn assert_owner_name(&self, name: &str) {
        assert_eq!(
            self.owner_name.as_deref(),
            Some(name),
            "owner name mismatch in scenario step"
        );
    }

    fn assert_second_name(&self, name: &str) {
        assert_eq!(
            self.second_name.as_deref(),
            Some(name),
            "second user name mismatch in scenario step"
        );
    }

    async fn ensure_owner_server(&mut self) {
        if self.server_id.is_some() {
            return;
        }

        let fixture = EntitySeeder.chat_fixture();
        let response = create_server_with_token(
            self.owner_app_ref(),
            &fixture.server.name,
            self.owner_token(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
        let payload = response_payload_json(response).await;
        self.server_id = Some(payload_server_id(&payload, "id"));
    }

    async fn ensure_owner_channel(&mut self) {
        self.ensure_owner_server().await;
        if self.channel_id.is_some() {
            return;
        }

        let fixture = EntitySeeder.chat_fixture();
        let response = create_channel_with_token(
            self.owner_app_ref(),
            self.server_id_ref(),
            fixture.channel.name(),
            "text",
            self.owner_token(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
        let payload = response_payload_json(response).await;
        self.channel_id = Some(payload_channel_id(&payload, "id"));
    }

    async fn ensure_owner_message(&mut self) {
        self.ensure_owner_channel().await;
        if self.message_id.is_some() {
            return;
        }

        let fixture = EntitySeeder.chat_fixture();
        let payload = response_payload_json(
            create_message(
                self.owner_app_ref(),
                self.channel_id_ref(),
                &fixture.message.content,
            )
            .await,
        )
        .await;
        self.message_id = Some(payload_message_id(&payload, "id"));
    }
}

#[given("an authenticated user exists")]
async fn an_authenticated_user_exists(world: &mut MessagesWorld) {
    let fixture = EntitySeeder.chat_fixture();
    let shared = fresh_shared_store().await;
    world.owner_app = seeded_app_with_store(
        &fixture.user.external_reference,
        "valid-token",
        Arc::clone(&shared),
    );
    world.second_app = None;
    world.shared_store = shared;
    world.server_id = None;
    world.channel_id = None;
    world.message_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.owner_token = "valid-token".to_owned();
    world.owner_name = None;
    world.second_name = None;
}

#[given(regex = r#"^a user named "([^"]+)" exists$"#)]
async fn a_user_named_exists(world: &mut MessagesWorld, name: String) {
    if world.owner_name.is_none() {
        let shared = fresh_shared_store().await;
        let subject = format!("auth0|{}", name.to_lowercase());
        world.owner_app = seeded_app_with_store(&subject, "owner-token", Arc::clone(&shared));
        world.shared_store = shared;
        world.second_app = None;
        world.server_id = None;
        world.channel_id = None;
        world.message_id = None;
        world.latest_status = None;
        world.latest_payload = None;
        world.owner_token = "owner-token".to_owned();
        world.owner_name = Some(name);
        world.second_name = None;
        return;
    }

    if world.second_app.is_none() {
        let shared = world.shared_store.clone();
        let subject = format!("auth0|{}", name.to_lowercase());
        world.second_app = Some(seeded_app_with_store(&subject, "member-token", shared));
        world.second_name = Some(name);
        world.latest_status = None;
        world.latest_payload = None;
        return;
    }

    world.assert_owner_name(&name);
}

#[given(regex = r#"^a channel exists in "([^"]+)"'s server$"#)]
async fn a_channel_exists_in_named_users_server(world: &mut MessagesWorld, name: String) {
    world.assert_owner_name(&name);
    world.ensure_owner_channel().await;
}

#[given(regex = r#"^a server named "([^"]+)" owned by "([^"]+)" exists$"#)]
async fn a_server_named_owned_by_named_user_exists(
    world: &mut MessagesWorld,
    _server_name: String,
    owner_name: String,
) {
    world.assert_owner_name(&owner_name);
    world.ensure_owner_server().await;
}

#[given(regex = r#"^a channel exists in server "([^"]+)" owned by "([^"]+)"$"#)]
async fn a_channel_exists_in_named_server_owned_by_named_user(
    world: &mut MessagesWorld,
    _server_name: String,
    owner_name: String,
) {
    a_channel_exists_in_named_users_server(world, owner_name).await;
}

#[given("a channel exists in the user's server")]
async fn a_channel_exists_in_the_users_server(world: &mut MessagesWorld) {
    world.ensure_owner_channel().await;
}

#[given(regex = r#"^a channel exists in server "([^"]+)" for the authenticated user$"#)]
async fn a_channel_exists_in_named_server_for_the_authenticated_user(
    world: &mut MessagesWorld,
    _server_name: String,
) {
    a_channel_exists_in_the_users_server(world).await;
}

#[given("the user already has a message in that channel")]
async fn the_user_already_has_a_message_in_that_channel(world: &mut MessagesWorld) {
    world.ensure_owner_message().await;
}

#[given("a channel exists in a server shared with another user")]
async fn a_channel_exists_in_a_server_shared_with_another_user(world: &mut MessagesWorld) {
    let shared = fresh_shared_store().await;
    let owner_user = EntitySeeder.user();
    let other_user = EntitySeeder.user();

    let owner_app = seeded_app_with_store(
        &owner_user.external_reference,
        "owner-token",
        Arc::clone(&shared),
    );
    let other_app = seeded_app_with_store(
        &other_user.external_reference,
        "other-token",
        Arc::clone(&shared),
    );

    let server_payload = response_payload_json(
        create_server_with_token(&owner_app, "shared-server", "owner-token").await,
    )
    .await;
    let server_id = payload_server_id(&server_payload, "id");

    let channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &server_id,
            "shared-channel",
            "text",
            "owner-token",
        )
        .await,
    )
    .await;

    world.owner_app = owner_app;
    world.second_app = Some(other_app);
    world.shared_store = shared;
    world.server_id = Some(server_id);
    world.channel_id = Some(payload_channel_id(&channel_payload, "id"));
    world.message_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.owner_token = "owner-token".to_owned();
}

#[given("another user already has a message in that channel")]
async fn another_user_already_has_a_message_in_that_channel(world: &mut MessagesWorld) {
    let payload = response_payload_json(
        create_message_with_token(
            world.owner_app_ref(),
            world.channel_id_ref(),
            "owner-message",
            "owner-token",
        )
        .await,
    )
    .await;
    world.message_id = Some(payload_message_id(&payload, "id"));
}

#[given("a server owner exists")]
async fn a_server_owner_exists(world: &mut MessagesWorld) {
    let fixture = EntitySeeder.chat_fixture();
    let shared = fresh_shared_store().await;
    world.owner_app = seeded_app_with_store(
        &fixture.user.external_reference,
        "owner-token",
        Arc::clone(&shared),
    );
    world.shared_store = shared;
    world.second_app = None;
    world.server_id = None;
    world.channel_id = None;
    world.message_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.owner_token = "owner-token".to_owned();
    world.owner_name = Some("Owner".to_owned());
    world.second_name = None;
}

#[given("a second authenticated user exists")]
async fn a_second_authenticated_user_exists(world: &mut MessagesWorld) {
    let shared = world.shared_store.clone();
    let second_user = EntitySeeder.user();
    world.second_app = Some(seeded_app_with_store(
        &second_user.external_reference,
        "member-token",
        shared,
    ));
    world.second_name = Some("Member".to_owned());
}

#[given("a channel exists in the owner's server")]
async fn a_channel_exists_in_the_owners_server(world: &mut MessagesWorld) {
    world.ensure_owner_channel().await;
}

#[given("a voice channel exists in the user's server")]
async fn a_voice_channel_exists_in_the_users_server(world: &mut MessagesWorld) {
    world.ensure_owner_server().await;
    let payload = response_payload_json(
        create_channel_with_token(
            world.owner_app_ref(),
            world.server_id_ref(),
            "voice-channel",
            "voice",
            world.owner_token(),
        )
        .await,
    )
    .await;
    world.channel_id = Some(payload_channel_id(&payload, "id"));
}

#[given(regex = r#"^a voice channel exists in server "([^"]+)" for the authenticated user$"#)]
async fn a_voice_channel_exists_in_named_server_for_the_authenticated_user(
    world: &mut MessagesWorld,
    _server_name: String,
) {
    a_voice_channel_exists_in_the_users_server(world).await;
}

#[when("the user posts a message in that channel")]
async fn the_user_posts_a_message_in_that_channel(world: &mut MessagesWorld) {
    let response =
        create_message(world.owner_app_ref(), world.channel_id_ref(), "new message").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
    world.message_id = Some(payload_message_id(world.latest_payload_ref(), "id"));
}

#[when("the user edits that message")]
async fn the_user_edits_that_message(world: &mut MessagesWorld) {
    let response = update_message(
        world.owner_app_ref(),
        world.channel_id_ref(),
        world.message_id_ref(),
        "updated message",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user deletes that message")]
async fn the_user_deletes_that_message(world: &mut MessagesWorld) {
    let response = delete_message(
        world.owner_app_ref(),
        world.channel_id_ref(),
        world.message_id_ref(),
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the authenticated user edits the other user's message")]
async fn the_authenticated_user_edits_the_other_users_message(world: &mut MessagesWorld) {
    let response = update_message_with_token(
        world.second_app_ref(),
        world.channel_id_ref(),
        world.message_id_ref(),
        "attempted edit",
        "other-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the authenticated user deletes the other user's message")]
async fn the_authenticated_user_deletes_the_other_users_message(world: &mut MessagesWorld) {
    let response = delete_message_with_token(
        world.second_app_ref(),
        world.channel_id_ref(),
        world.message_id_ref(),
        "other-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the second user lists messages in that channel")]
async fn the_second_user_lists_messages_in_that_channel(world: &mut MessagesWorld) {
    let response = list_messages_with_token(
        world.second_app_ref(),
        world.channel_id_ref(),
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when(regex = r#"^"([^"]+)" lists messages in that channel$"#)]
async fn named_user_lists_messages_in_that_channel(world: &mut MessagesWorld, name: String) {
    world.assert_second_name(&name);
    the_second_user_lists_messages_in_that_channel(world).await;
}

#[when("the user edits a message that does not exist in that channel")]
async fn the_user_edits_a_message_that_does_not_exist_in_that_channel(world: &mut MessagesWorld) {
    let missing_message_id: MessageId = Uuid::new_v4().into();
    let response = update_message(
        world.owner_app_ref(),
        world.channel_id_ref(),
        &missing_message_id,
        "attempted update",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user edits a message in a channel that does not exist")]
async fn the_user_edits_a_message_in_a_channel_that_does_not_exist(world: &mut MessagesWorld) {
    let missing_channel_id: ChannelId = Uuid::new_v4().into();
    let missing_message_id: MessageId = Uuid::new_v4().into();
    let response = update_message(
        world.owner_app_ref(),
        &missing_channel_id,
        &missing_message_id,
        "attempted update",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user deletes a message that does not exist in that channel")]
async fn the_user_deletes_a_message_that_does_not_exist_in_that_channel(world: &mut MessagesWorld) {
    let missing_message_id: MessageId = Uuid::new_v4().into();
    let response = delete_message(
        world.owner_app_ref(),
        world.channel_id_ref(),
        &missing_message_id,
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user deletes a message in a channel that does not exist")]
async fn the_user_deletes_a_message_in_a_channel_that_does_not_exist(world: &mut MessagesWorld) {
    let missing_channel_id: ChannelId = Uuid::new_v4().into();
    let missing_message_id: MessageId = Uuid::new_v4().into();
    let response = delete_message(
        world.owner_app_ref(),
        &missing_channel_id,
        &missing_message_id,
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user posts a message in that voice channel")]
async fn the_user_posts_a_message_in_that_voice_channel(world: &mut MessagesWorld) {
    let response = create_message(
        world.owner_app_ref(),
        world.channel_id_ref(),
        "invalid voice post",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[then("listing messages for that channel includes the new message")]
async fn listing_messages_for_that_channel_includes_the_new_message(world: &mut MessagesWorld) {
    let payload =
        response_payload_json(list_messages(world.owner_app_ref(), world.channel_id_ref()).await)
            .await;
    let messages = payload.as_array().expect("messages payload to be array");
    assert!(
        messages
            .iter()
            .any(|message| payload_message_id(message, "id") == *world.message_id_ref())
    );
}

#[then("listing messages for that channel returns the updated content")]
async fn listing_messages_for_that_channel_returns_the_updated_content(world: &mut MessagesWorld) {
    let payload =
        response_payload_json(list_messages(world.owner_app_ref(), world.channel_id_ref()).await)
            .await;
    let messages = payload.as_array().expect("messages payload to be array");
    assert!(messages.iter().any(|message| {
        payload_message_id(message, "id") == *world.message_id_ref()
            && message["content"].as_str() == Some("updated message")
    }));
}

#[then("listing messages for that channel does not include the deleted message")]
async fn listing_messages_for_that_channel_does_not_include_the_deleted_message(
    world: &mut MessagesWorld,
) {
    let payload =
        response_payload_json(list_messages(world.owner_app_ref(), world.channel_id_ref()).await)
            .await;
    let messages = payload.as_array().expect("messages payload to be array");
    assert!(
        !messages
            .iter()
            .any(|message| payload_message_id(message, "id") == *world.message_id_ref())
    );
}

#[then("the edit is denied")]
async fn the_edit_is_denied(world: &mut MessagesWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the delete is denied")]
async fn the_delete_is_denied(world: &mut MessagesWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("message listing is denied")]
async fn message_listing_is_denied(world: &mut MessagesWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the action fails because the message does not exist")]
async fn the_action_fails_because_the_message_does_not_exist(world: &mut MessagesWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[then("the action fails because the channel does not exist")]
async fn the_action_fails_because_the_channel_does_not_exist(world: &mut MessagesWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[then("posting is denied because that channel does not support messaging")]
async fn posting_is_denied_because_that_channel_does_not_support_messaging(
    world: &mut MessagesWorld,
) {
    assert_eq!(world.latest_status(), StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        world.latest_payload_ref()["error_code"].as_str(),
        Some("CHANNEL_KIND_MISMATCH")
    );
}

#[tokio::test]
async fn messages_feature() {
    prime_feature_test_store().await;
    MessagesWorld::cucumber().run_and_exit(FEATURE_PATH).await;
    shutdown_feature_test_store().await;
}

mod common;

use std::sync::Arc;

use axum::http::StatusCode;
use common::{
    bdd_support::{
        prime_feature_test_store,
        SharedTestStore, add_server_member_with_token, connect_channel_session_with_type,
        connect_voice_session, connect_voice_session_with_token, create_channel_with_token,
        create_server_with_token, create_voice_channel, default_shared_store,
        fresh_shared_store, get_me_with_token, payload_uuid, response_payload_json,
        seeded_app_with_store,
        shutdown_feature_test_store,
    },
    entity_seeder::EntitySeeder,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use uuid::Uuid;

const FEATURE_PATH: &str = "../../features/voice_sessions.feature";

#[derive(Debug, cucumber::World)]
struct VoiceSessionsWorld {
    owner_app: axum::Router,
    second_app: Option<axum::Router>,
    shared_store: SharedTestStore,
    server_id: Option<Uuid>,
    channel_id: Option<Uuid>,
    second_user_id: Option<Uuid>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    owner_token: String,
    owner_name: Option<String>,
    second_name: Option<String>,
}

impl Default for VoiceSessionsWorld {
    fn default() -> Self {
        Self {
            owner_app: axum::Router::new(),
            second_app: None,
            shared_store: default_shared_store(),
            server_id: None,
            channel_id: None,
            second_user_id: None,
            latest_status: None,
            latest_payload: None,
            owner_token: String::new(),
            owner_name: None,
            second_name: None,
        }
    }
}

impl VoiceSessionsWorld {
    fn owner_app_ref(&self) -> &axum::Router {
        &self.owner_app
    }

    fn second_app_ref(&self) -> &axum::Router {
        self.second_app
            .as_ref()
            .expect("second app to be initialized")
    }

    fn server_id_ref(&self) -> &Uuid {
        self.server_id.as_ref().expect("server id to be set")
    }

    fn channel_id_ref(&self) -> &Uuid {
        self.channel_id.as_ref().expect("channel id to be set")
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
        self.server_id = Some(payload_uuid(&payload, "id"));
    }
}

#[given("an authenticated user exists")]
async fn an_authenticated_user_exists(world: &mut VoiceSessionsWorld) {
    let fixture = EntitySeeder.chat_fixture();
    let shared = fresh_shared_store().await;
    world.owner_app =
        seeded_app_with_store(
            &fixture.user.external_reference,
            "valid-token",
            Arc::clone(&shared),
        )
        ;
    world.second_app = None;
    world.shared_store = shared;
    world.server_id = None;
    world.channel_id = None;
    world.second_user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.owner_token = "valid-token".to_owned();
    world.owner_name = None;
    world.second_name = None;
}

#[given(regex = r#"^a user named "([^"]+)" exists$"#)]
async fn a_user_named_exists(world: &mut VoiceSessionsWorld, name: String) {
    if world.owner_name.is_none() {
        let shared = fresh_shared_store().await;
        let subject = format!("auth0|{}", name.to_lowercase());
        world.owner_app = seeded_app_with_store(
            &subject,
            "owner-token",
            Arc::clone(&shared),
        );
        world.shared_store = shared;
        world.second_app = None;
        world.server_id = None;
        world.channel_id = None;
        world.second_user_id = None;
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
        let second_app = seeded_app_with_store(&subject, "member-token", shared);

        let me_payload =
            response_payload_json(get_me_with_token(&second_app, "member-token").await).await;
        world.second_user_id = Some(payload_uuid(&me_payload, "user_id"));
        world.second_app = Some(second_app);
        world.second_name = Some(name);
        world.latest_status = None;
        world.latest_payload = None;
        return;
    }

    world.assert_owner_name(&name);
}

#[given(regex = r#"^a voice channel exists in "([^"]+)"'s server$"#)]
async fn a_voice_channel_exists_in_named_users_server(
    world: &mut VoiceSessionsWorld,
    name: String,
) {
    world.assert_owner_name(&name);
    a_voice_channel_exists_in_the_owners_server(world).await;
}

#[given(regex = r#"^"([^"]+)" adds "([^"]+)" to the server$"#)]
async fn named_user_adds_named_user_to_the_server(
    world: &mut VoiceSessionsWorld,
    owner_name: String,
    member_name: String,
) {
    world.assert_owner_name(&owner_name);
    world.assert_second_name(&member_name);
    the_first_user_adds_the_second_user_as_a_member(world).await;
}

#[given("a voice channel exists in the user's server")]
async fn a_voice_channel_exists_in_the_users_server(world: &mut VoiceSessionsWorld) {
    world.ensure_owner_server().await;
    let fixture = EntitySeeder.chat_fixture();
    let payload = response_payload_json(
        create_voice_channel(
            world.owner_app_ref(),
            world.server_id_ref(),
            fixture.channel.name(),
        )
        .await,
    )
    .await;
    world.channel_id = Some(payload_uuid(&payload, "id"));
}

#[given("a server owner exists")]
async fn a_server_owner_exists(world: &mut VoiceSessionsWorld) {
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
    world.second_user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.owner_token = "owner-token".to_owned();
    world.owner_name = Some("Owner".to_owned());
    world.second_name = None;
}

#[given("a second authenticated user exists")]
async fn a_second_authenticated_user_exists(world: &mut VoiceSessionsWorld) {
    let shared = world.shared_store.clone();
    let second_user = EntitySeeder.user();
    let second_app =
        seeded_app_with_store(&second_user.external_reference, "member-token", shared);

    let me_payload =
        response_payload_json(get_me_with_token(&second_app, "member-token").await).await;
    world.second_user_id = Some(payload_uuid(&me_payload, "user_id"));
    world.second_app = Some(second_app);
    world.second_name = Some("Member".to_owned());
}

#[given("a voice channel exists in the owner's server")]
async fn a_voice_channel_exists_in_the_owners_server(world: &mut VoiceSessionsWorld) {
    world.ensure_owner_server().await;
    let payload = response_payload_json(
        create_channel_with_token(
            world.owner_app_ref(),
            world.server_id_ref(),
            "owner-voice-channel",
            "voice",
            "owner-token",
        )
        .await,
    )
    .await;
    world.channel_id = Some(payload_uuid(&payload, "id"));
}

#[given("the first user adds the second user as a member")]
async fn the_first_user_adds_the_second_user_as_a_member(world: &mut VoiceSessionsWorld) {
    let second_user_id = world
        .second_user_id
        .as_ref()
        .expect("second user id to be set");
    let response = add_server_member_with_token(
        world.owner_app_ref(),
        world.server_id_ref(),
        second_user_id,
        "owner-token",
    )
    .await;
    assert_eq!(response.status(), StatusCode::CREATED);
}

#[given("a text channel exists in the user's server")]
async fn a_text_channel_exists_in_the_users_server(world: &mut VoiceSessionsWorld) {
    world.ensure_owner_server().await;
    let payload = response_payload_json(
        create_channel_with_token(
            world.owner_app_ref(),
            world.server_id_ref(),
            "owner-text-channel",
            "text",
            "valid-token",
        )
        .await,
    )
    .await;
    world.channel_id = Some(payload_uuid(&payload, "id"));
}

#[when("I connect to voice for that channel")]
async fn i_connect_to_voice_for_that_channel(world: &mut VoiceSessionsWorld) {
    let response = connect_voice_session(world.owner_app_ref(), world.channel_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when("I connect to voice for a missing channel")]
async fn i_connect_to_voice_for_a_missing_channel(world: &mut VoiceSessionsWorld) {
    let missing_channel_id = Uuid::new_v4();
    let response = connect_voice_session(world.owner_app_ref(), &missing_channel_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the second user connects to voice for that channel")]
async fn the_second_user_connects_to_voice_for_that_channel(world: &mut VoiceSessionsWorld) {
    let response = connect_voice_session_with_token(
        world.second_app_ref(),
        world.channel_id_ref(),
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    if response.status() == StatusCode::OK {
        world.latest_payload = Some(response_payload_json(response).await);
    } else {
        world.latest_payload = None;
    }
}

#[when(regex = r#"^"([^"]+)" connects to voice for that channel$"#)]
async fn named_user_connects_to_voice_for_that_channel(
    world: &mut VoiceSessionsWorld,
    name: String,
) {
    world.assert_second_name(&name);
    the_second_user_connects_to_voice_for_that_channel(world).await;
}

#[when("I connect to voice for that text channel")]
async fn i_connect_to_voice_for_that_text_channel(world: &mut VoiceSessionsWorld) {
    let response = connect_voice_session(world.owner_app_ref(), world.channel_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when("I connect to text session for that voice channel")]
async fn i_connect_to_text_session_for_that_voice_channel(world: &mut VoiceSessionsWorld) {
    let response =
        connect_channel_session_with_type(world.owner_app_ref(), world.channel_id_ref(), "text")
            .await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[then("the connection succeeds")]
async fn the_connection_succeeds(world: &mut VoiceSessionsWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
}

#[then("the participant can join that voice conversation")]
async fn the_participant_can_join_that_voice_conversation(world: &mut VoiceSessionsWorld) {
    assert_eq!(
        payload_uuid(world.latest_payload_ref(), "channel_id"),
        *world.channel_id_ref()
    );
    assert!(
        world.latest_payload_ref()["participant_user_id"]
            .as_str()
            .is_some()
    );
    assert_eq!(
        world.latest_payload_ref()["livekit_url"].as_str(),
        Some("ws://127.0.0.1:7880")
    );
    assert!(
        world.latest_payload_ref()["access_token"]
            .as_str()
            .expect("access token to be present")
            .len()
            > 10
    );
}

#[then("the action fails because the channel does not exist")]
async fn the_action_fails_because_the_channel_does_not_exist(world: &mut VoiceSessionsWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[then("voice connection is denied")]
async fn voice_connection_is_denied(world: &mut VoiceSessionsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("voice connection is denied for that channel type")]
async fn voice_connection_is_denied_for_that_channel_type(world: &mut VoiceSessionsWorld) {
    assert_eq!(world.latest_status(), StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        world.latest_payload_ref()["error_code"].as_str(),
        Some("CHANNEL_KIND_MISMATCH")
    );
}

#[then("text session connection is denied for that channel type")]
async fn text_session_connection_is_denied_for_that_channel_type(world: &mut VoiceSessionsWorld) {
    assert_eq!(world.latest_status(), StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        world.latest_payload_ref()["error_code"].as_str(),
        Some("CHANNEL_KIND_MISMATCH")
    );
}

#[tokio::test]
async fn voice_sessions_feature() {
    prime_feature_test_store().await;
    VoiceSessionsWorld::cucumber()
        .run_and_exit(FEATURE_PATH)
        .await;
    shutdown_feature_test_store().await;
}

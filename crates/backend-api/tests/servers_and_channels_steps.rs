mod common;

use std::sync::Arc;

use axum::http::StatusCode;
use backend_api::{build_app, storage::InMemoryRepository};
use common::{
    bdd_support::{
        add_server_member, add_server_member_with_token, create_channel, create_channel_with_token,
        create_server, create_server_with_token, delete_channel, delete_channel_with_token,
        delete_server, delete_server_with_token, list_channels, list_channels_with_token,
        list_servers, list_servers_with_token, payload_uuid, response_payload_json, seeded_state,
        seeded_state_with_store, update_channel, update_channel_with_token,
    },
    entity_seeder::EntitySeeder,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use uuid::Uuid;

const FEATURE_PATH: &str = "../../features/servers_and_channels.feature";

#[derive(Debug, Default, cucumber::World)]
struct ServersAndChannelsWorld {
    owner_app: Option<axum::Router>,
    second_app: Option<axum::Router>,
    shared_store: Option<Arc<InMemoryRepository>>,
    server_id: Option<Uuid>,
    channel_id: Option<Uuid>,
    second_user_id: Option<Uuid>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    updated_channel_name: Option<String>,
    owner_token: String,
}

impl ServersAndChannelsWorld {
    fn owner_app_ref(&self) -> &axum::Router {
        self.owner_app
            .as_ref()
            .expect("owner app to be initialized")
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

    async fn ensure_owner_server(&mut self) {
        if self.server_id.is_some() {
            return;
        }

        let fixture = EntitySeeder::default().chat_fixture();
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

    async fn ensure_owner_channel(&mut self) {
        self.ensure_owner_server().await;
        if self.channel_id.is_some() {
            return;
        }

        let fixture = EntitySeeder::default().chat_fixture();
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
        self.channel_id = Some(payload_uuid(&payload, "id"));
    }
}

#[given("an authenticated user exists")]
async fn an_authenticated_user_exists(world: &mut ServersAndChannelsWorld) {
    let fixture = EntitySeeder::default().chat_fixture();
    world.owner_app = Some(build_app(seeded_state(
        &fixture.user.external_reference,
        "valid-token",
    )));
    world.second_app = None;
    world.shared_store = None;
    world.server_id = None;
    world.channel_id = None;
    world.second_user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.updated_channel_name = None;
    world.owner_token = "valid-token".to_owned();
}

#[given("the user already owns a server")]
async fn the_user_already_owns_a_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
}

#[given("a channel exists in the user's server")]
async fn a_channel_exists_in_the_users_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_channel().await;
}

#[given("a server owner exists")]
async fn a_server_owner_exists(world: &mut ServersAndChannelsWorld) {
    let fixture = EntitySeeder::default().chat_fixture();
    let shared = Arc::new(InMemoryRepository::new());
    world.owner_app = Some(build_app(seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        Arc::clone(&shared),
    )));
    world.shared_store = Some(shared);
    world.second_app = None;
    world.server_id = None;
    world.channel_id = None;
    world.second_user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.updated_channel_name = None;
    world.owner_token = "owner-token".to_owned();
}

#[given("a second authenticated user exists")]
async fn a_second_authenticated_user_exists(world: &mut ServersAndChannelsWorld) {
    let shared = world
        .shared_store
        .as_ref()
        .expect("shared store to be initialized")
        .clone();
    let second_user = EntitySeeder::default().user();

    let second_app = build_app(seeded_state_with_store(
        &second_user.external_reference,
        "member-token",
        shared,
    ));

    // materialize user and capture their actual id used by API membership checks
    let me_response = common::bdd_support::get_me_with_token(&second_app, "member-token").await;
    let me_payload = response_payload_json(me_response).await;

    world.second_user_id = Some(payload_uuid(&me_payload, "user_id"));
    world.second_app = Some(second_app);
}

#[given("the owner already has a server")]
async fn the_owner_already_has_a_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
}

#[given("the first user adds the second user as a member")]
async fn the_first_user_adds_the_second_user_as_a_member(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;

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

#[given("a channel exists in the owner's server")]
async fn a_channel_exists_in_the_owners_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_channel().await;
}

#[given("a channel exists in a server owned by another user")]
async fn a_channel_exists_in_a_server_owned_by_another_user(world: &mut ServersAndChannelsWorld) {
    // Rebuild into an explicit owner/non-owner setup.
    let shared = Arc::new(InMemoryRepository::new());
    let owner_user = EntitySeeder::default().user();
    let non_owner_user = EntitySeeder::default().user();

    let owner_app = build_app(seeded_state_with_store(
        &owner_user.external_reference,
        "owner-token",
        Arc::clone(&shared),
    ));
    let non_owner_app = build_app(seeded_state_with_store(
        &non_owner_user.external_reference,
        "member-token",
        shared,
    ));

    let server_payload = response_payload_json(
        create_server_with_token(&owner_app, "owner-server", "owner-token").await,
    )
    .await;
    let server_id = payload_uuid(&server_payload, "id");

    let channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &server_id,
            "owner-channel",
            "text",
            "owner-token",
        )
        .await,
    )
    .await;

    world.owner_app = Some(owner_app);
    world.second_app = Some(non_owner_app);
    world.shared_store = None;
    world.server_id = Some(server_id);
    world.channel_id = Some(payload_uuid(&channel_payload, "id"));
    world.latest_status = None;
    world.latest_payload = None;
    world.updated_channel_name = None;
}

#[when("the user creates a server")]
async fn the_user_creates_a_server(world: &mut ServersAndChannelsWorld) {
    let response = create_server(world.owner_app_ref(), "bdd-server").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
    world.server_id = Some(payload_uuid(world.latest_payload_ref(), "id"));
}

#[when("the user lists their servers")]
async fn the_user_lists_their_servers(world: &mut ServersAndChannelsWorld) {
    let response = list_servers(world.owner_app_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when("the user creates a channel in that server")]
async fn the_user_creates_a_channel_in_that_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
    let response =
        create_channel(world.owner_app_ref(), world.server_id_ref(), "bdd-channel").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
    world.channel_id = Some(payload_uuid(world.latest_payload_ref(), "id"));
}

#[when("the user lists channels in that server")]
async fn the_user_lists_channels_in_that_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
    let response = list_channels(world.owner_app_ref(), world.server_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when("the server owner updates the channel name")]
async fn the_server_owner_updates_the_channel_name(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_channel().await;
    let updated_name = "updated-channel-name".to_owned();
    let response =
        update_channel(world.owner_app_ref(), world.channel_id_ref(), &updated_name).await;
    world.updated_channel_name = Some(updated_name);
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the non-owner attempts to update the channel name")]
async fn the_non_owner_attempts_to_update_the_channel_name(world: &mut ServersAndChannelsWorld) {
    let response = update_channel_with_token(
        world.second_app_ref(),
        world.channel_id_ref(),
        "forbidden-name",
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user updates a channel that does not exist")]
async fn the_user_updates_a_channel_that_does_not_exist(world: &mut ServersAndChannelsWorld) {
    let missing_channel_id = Uuid::new_v4();
    let response = update_channel(
        world.owner_app_ref(),
        &missing_channel_id,
        "missing-channel",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the server owner adds another user as a member")]
async fn the_server_owner_adds_another_user_as_a_member(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
    let extra_user = EntitySeeder::default().user();
    let response =
        add_server_member(world.owner_app_ref(), world.server_id_ref(), &extra_user.id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when("the second user lists their servers")]
async fn the_second_user_lists_their_servers(world: &mut ServersAndChannelsWorld) {
    let response = list_servers_with_token(world.second_app_ref(), "member-token").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when("the second user lists channels in that server")]
async fn the_second_user_lists_channels_in_that_server(world: &mut ServersAndChannelsWorld) {
    let response = list_channels_with_token(
        world.second_app_ref(),
        world.server_id_ref(),
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the second user tries to add a different user to that server")]
async fn the_second_user_tries_to_add_a_different_user_to_that_server(
    world: &mut ServersAndChannelsWorld,
) {
    let extra_user = EntitySeeder::default().user();
    let response = add_server_member_with_token(
        world.second_app_ref(),
        world.server_id_ref(),
        &extra_user.id,
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the server owner deletes that server")]
async fn the_server_owner_deletes_that_server(world: &mut ServersAndChannelsWorld) {
    let response = delete_server(world.owner_app_ref(), world.server_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the second user deletes that server")]
async fn the_second_user_deletes_that_server(world: &mut ServersAndChannelsWorld) {
    let response = delete_server_with_token(
        world.second_app_ref(),
        world.server_id_ref(),
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user deletes a server that does not exist")]
async fn the_user_deletes_a_server_that_does_not_exist(world: &mut ServersAndChannelsWorld) {
    let missing_server_id = Uuid::new_v4();
    let response = delete_server(world.owner_app_ref(), &missing_server_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the server owner deletes that channel")]
async fn the_server_owner_deletes_that_channel(world: &mut ServersAndChannelsWorld) {
    let response = delete_channel(world.owner_app_ref(), world.channel_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the second user deletes that channel")]
async fn the_second_user_deletes_that_channel(world: &mut ServersAndChannelsWorld) {
    let response = delete_channel_with_token(
        world.second_app_ref(),
        world.channel_id_ref(),
        "member-token",
    )
    .await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when("the user deletes a channel that does not exist")]
async fn the_user_deletes_a_channel_that_does_not_exist(world: &mut ServersAndChannelsWorld) {
    let missing_channel_id = Uuid::new_v4();
    let response = delete_channel(world.owner_app_ref(), &missing_channel_id).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[then("the server is created successfully")]
async fn the_server_is_created_successfully(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert!(world.latest_payload_ref()["id"].as_str().is_some());
}

#[then("the owned server is included in the server list")]
async fn the_owned_server_is_included_in_the_server_list(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
    let servers = world
        .latest_payload_ref()
        .as_array()
        .expect("server list payload to be array");
    assert!(
        servers
            .iter()
            .any(|server| payload_uuid(server, "id") == *world.server_id_ref())
    );
}

#[then("the server channel is created successfully")]
async fn the_server_channel_is_created_successfully(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(
        payload_uuid(world.latest_payload_ref(), "server_id"),
        *world.server_id_ref()
    );
}

#[then("the channel is included in the channel list")]
async fn the_channel_is_included_in_the_channel_list(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
    let channels = world
        .latest_payload_ref()
        .as_array()
        .expect("channel list payload to be array");
    assert!(
        channels
            .iter()
            .any(|channel| payload_uuid(channel, "id") == *world.channel_id_ref())
    );
}

#[then("listing channels in that server includes the updated name")]
async fn listing_channels_in_that_server_includes_the_updated_name(
    world: &mut ServersAndChannelsWorld,
) {
    let list_response = list_channels(world.owner_app_ref(), world.server_id_ref()).await;
    let list_payload = response_payload_json(list_response).await;
    let channels = list_payload
        .as_array()
        .expect("channel list payload to be array");
    let updated_name = world
        .updated_channel_name
        .as_ref()
        .expect("updated channel name to be set");

    assert!(channels.iter().any(|channel| {
        payload_uuid(channel, "id") == *world.channel_id_ref()
            && channel["name"].as_str() == Some(updated_name.as_str())
    }));
}

#[then("the update is forbidden")]
async fn the_update_is_forbidden(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the user is told the channel does not exist")]
async fn the_user_is_told_the_channel_does_not_exist(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[then("the server membership is created successfully")]
async fn the_server_membership_is_created_successfully(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(
        payload_uuid(world.latest_payload_ref(), "server_id"),
        *world.server_id_ref()
    );
    assert!(world.latest_payload_ref()["user_id"].as_str().is_some());
}

#[then("the shared server is included in their server list")]
async fn the_shared_server_is_included_in_their_server_list(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::OK);
    let servers = world
        .latest_payload_ref()
        .as_array()
        .expect("server list payload to be array");
    assert!(
        servers
            .iter()
            .any(|server| payload_uuid(server, "id") == *world.server_id_ref())
    );
}

#[then("listing channels is forbidden")]
async fn listing_channels_is_forbidden(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the add-member action is forbidden")]
async fn the_add_member_action_is_forbidden(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the delete succeeds")]
async fn the_delete_succeeds(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::NO_CONTENT);
}

#[then("listing servers for that user returns no servers")]
async fn listing_servers_for_that_user_returns_no_servers(world: &mut ServersAndChannelsWorld) {
    let list_response = list_servers(world.owner_app_ref()).await;
    let list_payload = response_payload_json(list_response).await;
    assert!(
        list_payload
            .as_array()
            .expect("server list payload to be array")
            .is_empty()
    );
}

#[then("the delete is forbidden")]
async fn the_delete_is_forbidden(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the user is told the server does not exist")]
async fn the_user_is_told_the_server_does_not_exist(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[then("listing channels in that server returns no channels")]
async fn listing_channels_in_that_server_returns_no_channels(world: &mut ServersAndChannelsWorld) {
    let list_response = list_channels(world.owner_app_ref(), world.server_id_ref()).await;
    let list_payload = response_payload_json(list_response).await;
    assert!(
        list_payload
            .as_array()
            .expect("channel list payload to be array")
            .is_empty()
    );
}

#[tokio::test]
async fn servers_and_channels_feature() {
    ServersAndChannelsWorld::cucumber()
        .run_and_exit(FEATURE_PATH)
        .await;
}

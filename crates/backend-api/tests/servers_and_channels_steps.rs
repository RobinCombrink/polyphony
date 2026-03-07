mod common;

use std::collections::HashMap;
use std::sync::Arc;

use axum::http::StatusCode;
use common::{
    bdd_support::{
        Actor, ChannelId, ServerId, SharedTestStore, UserId, add_server_member,
        add_server_member_with_token, create_actor, create_channel, create_channel_with_token,
        create_server, create_server_with_token, default_shared_store, delete_channel,
        delete_channel_with_token, delete_server, delete_server_with_token, fresh_shared_store,
        list_channels, list_channels_with_token, list_servers, list_servers_with_token,
        payload_channel_id, payload_server_id, payload_user_id, prime_feature_test_store,
        response_payload_json, seeded_app_with_store, shutdown_feature_test_store, update_channel,
        update_channel_with_token,
    },
    entity_seeder::EntitySeeder,
};
use cucumber::{World as _, given, then, when};
use serde_json::Value;
use uuid::Uuid;

const FEATURE_PATH: &str = "../../features/servers_and_channels.feature";

#[derive(Debug, cucumber::World)]
struct ServersAndChannelsWorld {
    actors: HashMap<String, Actor>,
    shared_store: SharedTestStore,
    owner_name: Option<String>,
    second_name: Option<String>,
    server_id: Option<ServerId>,
    channel_id: Option<ChannelId>,
    second_user_id: Option<UserId>,
    latest_status: Option<StatusCode>,
    latest_payload: Option<Value>,
    updated_channel_name: Option<String>,
    owner_token: String,
}

impl Default for ServersAndChannelsWorld {
    fn default() -> Self {
        Self {
            actors: HashMap::new(),
            shared_store: default_shared_store(),
            owner_name: None,
            second_name: None,
            server_id: None,
            channel_id: None,
            second_user_id: None,
            latest_status: None,
            latest_payload: None,
            updated_channel_name: None,
            owner_token: String::new(),
        }
    }
}

impl ServersAndChannelsWorld {
    fn actor_ref(&self, name: &str) -> &Actor {
        self.actors.get(name).expect("actor to be initialized")
    }

    fn owner_actor_ref(&self) -> &Actor {
        let owner_name = self.owner_name.as_ref().expect("owner name to be set");
        self.actor_ref(owner_name)
    }

    fn second_actor_ref(&self) -> &Actor {
        let second_name = self
            .second_name
            .as_ref()
            .expect("second user name to be set");
        self.actor_ref(second_name)
    }

    fn owner_app_ref(&self) -> &axum::Router {
        &self.owner_actor_ref().app
    }

    fn second_app_ref(&self) -> &axum::Router {
        &self.second_actor_ref().app
    }

    fn server_id_ref(&self) -> &ServerId {
        self.server_id.as_ref().expect("server id to be set")
    }

    fn channel_id_ref(&self) -> &ChannelId {
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
        let owner = self.owner_actor_ref();
        let response =
            create_server_with_token(&owner.app, &fixture.server.name, owner.token.as_str()).await;
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
        let owner = self.owner_actor_ref();
        let response = create_channel_with_token(
            &owner.app,
            self.server_id_ref(),
            fixture.channel.name(),
            "text",
            owner.token.as_str(),
        )
        .await;
        assert_eq!(response.status(), StatusCode::CREATED);
        let payload = response_payload_json(response).await;
        self.channel_id = Some(payload_channel_id(&payload, "id"));
    }
}

#[given("an authenticated user exists")]
async fn an_authenticated_user_exists(world: &mut ServersAndChannelsWorld) {
    let shared = fresh_shared_store().await;
    let actor = create_actor("Authenticated User", "valid-token", Arc::clone(&shared)).await;

    world.actors.clear();
    world.actors.insert(actor.name.clone(), actor);
    world.shared_store = shared;
    world.owner_name = Some("Authenticated User".to_owned());
    world.second_name = None;
    world.server_id = None;
    world.channel_id = None;
    world.second_user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.updated_channel_name = None;
    world.owner_token = "valid-token".to_owned();
}

#[given(regex = r#"^a user named "([^"]+)" exists$"#)]
async fn a_user_named_exists(world: &mut ServersAndChannelsWorld, name: String) {
    if world.owner_name.is_none() {
        let shared = fresh_shared_store().await;
        let actor = create_actor(&name, "owner-token", Arc::clone(&shared)).await;

        world.actors.clear();
        world.actors.insert(name.clone(), actor);
        world.shared_store = shared;
        world.owner_token = "owner-token".to_owned();
        world.owner_name = Some(name);
        world.second_name = None;
        world.server_id = None;
        world.channel_id = None;
        world.second_user_id = None;
        world.latest_status = None;
        world.latest_payload = None;
        world.updated_channel_name = None;
        return;
    }

    if world.second_name.is_none() {
        let shared = world.shared_store.clone();
        let second_actor = create_actor(&name, "member-token", shared).await;
        world.second_user_id = Some(second_actor.user_id);
        world.actors.insert(name.clone(), second_actor);
        world.second_name = Some(name);
        world.latest_status = None;
        world.latest_payload = None;
        return;
    }

    world.assert_owner_name(&name);
}

#[given(regex = r#"^"([^"]+)" owns a server$"#)]
async fn named_user_owns_a_server(world: &mut ServersAndChannelsWorld, name: String) {
    world.assert_owner_name(&name);
    world.ensure_owner_server().await;
}

#[given(regex = r#"^"([^"]+)" owns server "([^"]+)"$"#)]
async fn named_user_owns_named_server(
    world: &mut ServersAndChannelsWorld,
    name: String,
    _server_name: String,
) {
    named_user_owns_a_server(world, name).await;
}

#[given(regex = r#"^a channel exists in "([^"]+)"'s server$"#)]
async fn a_channel_exists_in_named_users_server(world: &mut ServersAndChannelsWorld, name: String) {
    world.assert_owner_name(&name);
    world.ensure_owner_channel().await;
}

#[given(regex = r#"^a channel exists in server "([^"]+)" owned by "([^"]+)"$"#)]
async fn a_channel_exists_in_named_server_owned_by_named_user(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
    owner_name: String,
) {
    a_channel_exists_in_named_users_server(world, owner_name).await;
}

#[given(regex = r#"^"([^"]+)" adds "([^"]+)" to the server$"#)]
async fn named_user_adds_named_user_to_the_server(
    world: &mut ServersAndChannelsWorld,
    owner_name: String,
    member_name: String,
) {
    world.assert_owner_name(&owner_name);
    world.assert_second_name(&member_name);
    the_first_user_adds_the_second_user_as_a_member(world).await;
}

#[given(regex = r#"^"([^"]+)" adds "([^"]+)" to server "([^"]+)"$"#)]
async fn named_user_adds_named_user_to_named_server(
    world: &mut ServersAndChannelsWorld,
    owner_name: String,
    member_name: String,
    _server_name: String,
) {
    named_user_adds_named_user_to_the_server(world, owner_name, member_name).await;
}

#[given("the user already owns a server")]
async fn the_user_already_owns_a_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
}

#[given(regex = r#"^the user already owns server "([^"]+)"$"#)]
async fn the_user_already_owns_named_server(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    the_user_already_owns_a_server(world).await;
}

#[given("a channel exists in the user's server")]
async fn a_channel_exists_in_the_users_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_channel().await;
}

#[given(regex = r#"^a channel exists in server "([^"]+)" for the authenticated user$"#)]
async fn a_channel_exists_in_named_server_for_the_authenticated_user(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    a_channel_exists_in_the_users_server(world).await;
}

#[given("a server owner exists")]
async fn a_server_owner_exists(world: &mut ServersAndChannelsWorld) {
    let shared = fresh_shared_store().await;
    let owner_actor = create_actor("Owner", "owner-token", Arc::clone(&shared)).await;

    world.actors.clear();
    world.actors.insert("Owner".to_owned(), owner_actor);
    world.shared_store = shared;
    world.server_id = None;
    world.channel_id = None;
    world.second_user_id = None;
    world.latest_status = None;
    world.latest_payload = None;
    world.updated_channel_name = None;
    world.owner_token = "owner-token".to_owned();
    world.owner_name = Some("Owner".to_owned());
    world.second_name = None;
}

#[given("a second authenticated user exists")]
async fn a_second_authenticated_user_exists(world: &mut ServersAndChannelsWorld) {
    let shared = world.shared_store.clone();
    let second_actor = create_actor("Member", "member-token", shared).await;

    world.second_user_id = Some(second_actor.user_id);
    world.actors.insert("Member".to_owned(), second_actor);
    world.second_name = Some("Member".to_owned());
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
    let shared = fresh_shared_store().await;
    let owner_actor = create_actor("Owner", "owner-token", Arc::clone(&shared)).await;
    let non_owner_actor = create_actor("Member", "member-token", Arc::clone(&shared)).await;

    let server_payload = response_payload_json(
        create_server_with_token(&owner_actor.app, "owner-server", "owner-token").await,
    )
    .await;
    let server_id = payload_server_id(&server_payload, "id");

    let channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_actor.app,
            &server_id,
            "owner-channel",
            "text",
            "owner-token",
        )
        .await,
    )
    .await;

    world.actors.clear();
    world.actors.insert("Owner".to_owned(), owner_actor);
    world.actors.insert("Member".to_owned(), non_owner_actor);
    world.shared_store = shared;
    world.owner_name = Some("Owner".to_owned());
    world.second_name = Some("Member".to_owned());
    world.server_id = Some(server_id);
    world.channel_id = Some(payload_channel_id(&channel_payload, "id"));
    world.latest_status = None;
    world.latest_payload = None;
    world.updated_channel_name = None;
}

#[when("the user creates a server")]
async fn the_user_creates_a_server(world: &mut ServersAndChannelsWorld) {
    let response = create_server(world.owner_app_ref(), "bdd-server").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
    world.server_id = Some(payload_server_id(world.latest_payload_ref(), "id"));
}

#[when("the user lists their servers")]
async fn the_user_lists_their_servers(world: &mut ServersAndChannelsWorld) {
    let response = list_servers(world.owner_app_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^"([^"]+)" lists their servers$"#)]
async fn named_user_lists_their_servers(world: &mut ServersAndChannelsWorld, name: String) {
    world.assert_second_name(&name);
    the_second_user_lists_their_servers(world).await;
}

#[when("the user creates a channel in that server")]
async fn the_user_creates_a_channel_in_that_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
    let response =
        create_channel(world.owner_app_ref(), world.server_id_ref(), "bdd-channel").await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
    world.channel_id = Some(payload_channel_id(world.latest_payload_ref(), "id"));
}

#[when(regex = r#"^the user creates a channel in server "([^"]+)"$"#)]
async fn the_user_creates_a_channel_in_named_server(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    the_user_creates_a_channel_in_that_server(world).await;
}

#[when("the user lists channels in that server")]
async fn the_user_lists_channels_in_that_server(world: &mut ServersAndChannelsWorld) {
    world.ensure_owner_server().await;
    let response = list_channels(world.owner_app_ref(), world.server_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = Some(response_payload_json(response).await);
}

#[when(regex = r#"^the user lists channels in server "([^"]+)"$"#)]
async fn the_user_lists_channels_in_named_server(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    the_user_lists_channels_in_that_server(world).await;
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
    let missing_channel_id = Uuid::new_v4().into();
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
    let shared = world.shared_store.clone();
    let extra_user = EntitySeeder.user();
    let extra_app = seeded_app_with_store(&extra_user.external_reference, "extra-token", shared);
    let extra_user_response =
        common::bdd_support::get_me_with_token(&extra_app, "extra-token").await;
    let extra_user_payload = response_payload_json(extra_user_response).await;
    let extra_user_id = payload_user_id(&extra_user_payload, "user_id");

    let response =
        add_server_member(world.owner_app_ref(), world.server_id_ref(), &extra_user_id).await;
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

#[when(regex = r#"^"([^"]+)" lists channels in server "([^"]+)"$"#)]
async fn named_user_lists_channels_in_named_server(
    world: &mut ServersAndChannelsWorld,
    name: String,
    _server_name: String,
) {
    named_user_lists_channels_in_that_server(world, name).await;
}

#[when(regex = r#"^"([^"]+)" lists channels in that server$"#)]
async fn named_user_lists_channels_in_that_server(
    world: &mut ServersAndChannelsWorld,
    name: String,
) {
    world.assert_second_name(&name);
    the_second_user_lists_channels_in_that_server(world).await;
}

#[when("the second user tries to add a different user to that server")]
async fn the_second_user_tries_to_add_a_different_user_to_that_server(
    world: &mut ServersAndChannelsWorld,
) {
    let extra_user = EntitySeeder.user();
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

#[when(regex = r#"^"([^"]+)" tries to add a different user to that server$"#)]
async fn named_user_tries_to_add_a_different_user_to_that_server(
    world: &mut ServersAndChannelsWorld,
    name: String,
) {
    world.assert_second_name(&name);
    the_second_user_tries_to_add_a_different_user_to_that_server(world).await;
}

#[when(regex = r#"^"([^"]+)" tries to add a different user to server "([^"]+)"$"#)]
async fn named_user_tries_to_add_a_different_user_to_named_server(
    world: &mut ServersAndChannelsWorld,
    name: String,
    _server_name: String,
) {
    named_user_tries_to_add_a_different_user_to_that_server(world, name).await;
}

#[when("the server owner deletes that server")]
async fn the_server_owner_deletes_that_server(world: &mut ServersAndChannelsWorld) {
    let response = delete_server(world.owner_app_ref(), world.server_id_ref()).await;
    world.latest_status = Some(response.status());
    world.latest_payload = None;
}

#[when(regex = r#"^the server owner deletes server "([^"]+)"$"#)]
async fn the_server_owner_deletes_named_server(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    the_server_owner_deletes_that_server(world).await;
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

#[when(regex = r#"^"([^"]+)" deletes that server$"#)]
async fn named_user_deletes_that_server(world: &mut ServersAndChannelsWorld, name: String) {
    world.assert_second_name(&name);
    the_second_user_deletes_that_server(world).await;
}

#[when(regex = r#"^"([^"]+)" deletes server "([^"]+)"$"#)]
async fn named_user_deletes_named_server(
    world: &mut ServersAndChannelsWorld,
    name: String,
    _server_name: String,
) {
    named_user_deletes_that_server(world, name).await;
}

#[when("the user deletes a server that does not exist")]
async fn the_user_deletes_a_server_that_does_not_exist(world: &mut ServersAndChannelsWorld) {
    let missing_server_id: ServerId = Uuid::new_v4().into();
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

#[when(regex = r#"^"([^"]+)" deletes that channel$"#)]
async fn named_user_deletes_that_channel(world: &mut ServersAndChannelsWorld, name: String) {
    world.assert_second_name(&name);
    the_second_user_deletes_that_channel(world).await;
}

#[when("the user deletes a channel that does not exist")]
async fn the_user_deletes_a_channel_that_does_not_exist(world: &mut ServersAndChannelsWorld) {
    let missing_channel_id: ChannelId = Uuid::new_v4().into();
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
            .any(|server| payload_server_id(server, "id") == *world.server_id_ref())
    );
}

#[then("the server channel is created successfully")]
async fn the_server_channel_is_created_successfully(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(
        payload_server_id(world.latest_payload_ref(), "server_id"),
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
            .any(|channel| payload_channel_id(channel, "id") == *world.channel_id_ref())
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
        payload_channel_id(channel, "id") == *world.channel_id_ref()
            && channel["name"].as_str() == Some(updated_name.as_str())
    }));
}

#[then(regex = r#"^listing channels in server "([^"]+)" includes the updated name$"#)]
async fn listing_channels_in_named_server_includes_the_updated_name(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    listing_channels_in_that_server_includes_the_updated_name(world).await;
}

#[then("the update is denied")]
async fn the_update_is_denied(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the action fails because the channel does not exist")]
async fn the_action_fails_because_the_channel_does_not_exist(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::NOT_FOUND);
}

#[then("the server membership is created successfully")]
async fn the_server_membership_is_created_successfully(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::CREATED);
    assert_eq!(
        payload_server_id(world.latest_payload_ref(), "server_id"),
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
            .any(|server| payload_server_id(server, "id") == *world.server_id_ref())
    );
}

#[then("channel listing is denied")]
async fn channel_listing_is_denied(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("adding a member is denied")]
async fn adding_a_member_is_denied(world: &mut ServersAndChannelsWorld) {
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
    let servers = list_payload
        .as_array()
        .expect("server list payload to be array");
    assert!(
        !servers
            .iter()
            .any(|server| payload_server_id(server, "id") == *world.server_id_ref())
    );
}

#[then("the delete is denied")]
async fn the_delete_is_denied(world: &mut ServersAndChannelsWorld) {
    assert_eq!(world.latest_status(), StatusCode::FORBIDDEN);
}

#[then("the action fails because the server does not exist")]
async fn the_action_fails_because_the_server_does_not_exist(world: &mut ServersAndChannelsWorld) {
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

#[then(regex = r#"^listing channels in server "([^"]+)" returns no channels$"#)]
async fn listing_channels_in_named_server_returns_no_channels(
    world: &mut ServersAndChannelsWorld,
    _server_name: String,
) {
    listing_channels_in_that_server_returns_no_channels(world).await;
}

#[tokio::test]
async fn servers_and_channels_feature() {
    prime_feature_test_store().await;
    ServersAndChannelsWorld::cucumber()
        .run_and_exit(FEATURE_PATH)
        .await;
    shutdown_feature_test_store().await;
}

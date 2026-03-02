use axum::http::StatusCode;
use backend_api::build_app;
use std::sync::Arc;

#[path = "../common.rs"]
mod common;

use backend_api::storage::InMemoryRepository;
use common::{
    bdd_support::{
        add_server_member, add_server_member_with_token, create_channel, create_channel_with_token,
        create_server, create_server_with_token, delete_channel, delete_channel_with_token,
        delete_server, delete_server_with_token, get_me_with_token, list_channels, list_servers,
        list_servers_with_token, response_payload_json, seeded_state, seeded_state_with_store,
        update_channel, update_channel_with_token,
    },
    entity_seeder::EntitySeeder,
};

#[tokio::test]
async fn given_authenticated_user_when_create_server_then_created_status_and_server_id_returned() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_response = create_server(&app, &fixture.server.name).await;

    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    assert!(create_server_payload["id"].as_str().is_some());
}

#[tokio::test]
async fn given_existing_server_when_list_servers_then_seeded_server_is_in_response() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_response = create_server(&app, &fixture.server.name).await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let list_servers_response = list_servers(&app).await;
    assert_eq!(list_servers_response.status(), StatusCode::OK);

    let list_servers_payload = response_payload_json(list_servers_response).await;
    let listed_servers = list_servers_payload
        .as_array()
        .expect("server list payload to be array");

    assert_eq!(listed_servers.len(), 1);
    assert_eq!(
        listed_servers[0]["name"].as_str(),
        Some(fixture.server.name.as_str())
    );
}

#[tokio::test]
async fn given_existing_server_when_create_channel_then_created_status_and_channel_id_returned() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_response =
        create_channel(&app, &created_server_id, fixture.channel.name()).await;

    assert_eq!(create_channel_response.status(), StatusCode::CREATED);

    let create_channel_payload = response_payload_json(create_channel_response).await;
    assert_eq!(
        create_channel_payload["server_id"].as_str(),
        Some(created_server_id.as_str())
    );
    assert!(create_channel_payload["id"].as_str().is_some());
}

#[tokio::test]
async fn given_existing_channel_when_list_channels_then_seeded_channel_is_in_response() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_response =
        create_channel(&app, &created_server_id, fixture.channel.name()).await;
    assert_eq!(create_channel_response.status(), StatusCode::CREATED);

    let list_channels_response = list_channels(&app, &created_server_id).await;
    assert_eq!(list_channels_response.status(), StatusCode::OK);

    let list_channels_payload = response_payload_json(list_channels_response).await;
    let listed_channels = list_channels_payload
        .as_array()
        .expect("channel list payload to be array");

    assert_eq!(listed_channels.len(), 1);
    assert_eq!(
        listed_channels[0]["name"].as_str(),
        Some(fixture.channel.name())
    );
}

#[tokio::test]
async fn given_server_owner_when_add_server_member_then_created_membership_is_returned() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let additional_user = entity_seeder.user();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let add_server_member_response =
        add_server_member(&app, &created_server_id, &additional_user.id.to_string()).await;

    assert_eq!(add_server_member_response.status(), StatusCode::CREATED);

    let add_server_member_payload = response_payload_json(add_server_member_response).await;
    let additional_user_id = additional_user.id.to_string();
    assert_eq!(
        add_server_member_payload["server_id"].as_str(),
        Some(created_server_id.as_str())
    );
    assert_eq!(
        add_server_member_payload["user_id"].as_str(),
        Some(additional_user_id.as_str())
    );
}

#[tokio::test]
async fn given_server_with_added_member_when_member_lists_servers_then_server_is_in_response() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let additional_user = entity_seeder.user();

    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_state = seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        shared_store.clone(),
    );
    let owner_app = build_app(owner_state);

    let member_state = seeded_state_with_store(
        &additional_user.external_reference,
        "member-token",
        shared_store,
    );
    let member_app = build_app(member_state);

    let create_server_response =
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let member_me_payload =
        response_payload_json(get_me_with_token(&member_app, "member-token").await).await;
    let member_user_id = member_me_payload["user_id"]
        .as_str()
        .expect("member user id to be present")
        .to_owned();

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user_id,
        "owner-token",
    )
    .await;
    assert_eq!(add_member_response.status(), StatusCode::CREATED);

    let list_servers_response = list_servers_with_token(&member_app, "member-token").await;
    assert_eq!(list_servers_response.status(), StatusCode::OK);

    let list_servers_payload = response_payload_json(list_servers_response).await;
    let listed_servers = list_servers_payload
        .as_array()
        .expect("server list payload to be array");

    assert_eq!(listed_servers.len(), 1);
    assert_eq!(
        listed_servers[0]["id"].as_str(),
        Some(created_server_id.as_str())
    );
}

#[tokio::test]
async fn given_non_owner_when_add_server_member_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let existing_member = entity_seeder.user();
    let target_user = entity_seeder.user();

    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_state = seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        shared_store.clone(),
    );
    let owner_app = build_app(owner_state);

    let member_state = seeded_state_with_store(
        &existing_member.external_reference,
        "member-token",
        shared_store,
    );
    let member_app = build_app(member_state);

    let create_server_response =
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let add_owner_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &existing_member.id.to_string(),
        "owner-token",
    )
    .await;
    assert_eq!(add_owner_member_response.status(), StatusCode::CREATED);

    let non_owner_add_response = add_server_member_with_token(
        &member_app,
        &created_server_id,
        &target_user.id.to_string(),
        "member-token",
    )
    .await;

    assert_eq!(non_owner_add_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_server_owner_when_delete_server_then_status_is_204_and_server_removed() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_response = create_server(&app, &fixture.server.name).await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let delete_server_response = delete_server(&app, &created_server_id).await;
    assert_eq!(delete_server_response.status(), StatusCode::NO_CONTENT);

    let list_servers_response = list_servers(&app).await;
    assert_eq!(list_servers_response.status(), StatusCode::OK);

    let list_servers_payload = response_payload_json(list_servers_response).await;
    let listed_servers = list_servers_payload
        .as_array()
        .expect("server list payload to be array");

    assert!(listed_servers.is_empty());
}

#[tokio::test]
async fn given_non_owner_when_delete_server_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let member_user = entity_seeder.user();

    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_state = seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        shared_store.clone(),
    );
    let owner_app = build_app(owner_state);

    let member_state = seeded_state_with_store(
        &member_user.external_reference,
        "member-token",
        shared_store,
    );
    let member_app = build_app(member_state);

    let create_server_response =
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user.id.to_string(),
        "owner-token",
    )
    .await;
    assert_eq!(add_member_response.status(), StatusCode::CREATED);

    let delete_server_response =
        delete_server_with_token(&member_app, &created_server_id, "member-token").await;

    assert_eq!(delete_server_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_server_when_delete_server_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let delete_server_response = delete_server(&app, "00000000-0000-0000-0000-000000000001").await;

    assert_eq!(delete_server_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_server_owner_when_delete_channel_then_status_is_204_and_channel_removed() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_payload = response_payload_json(
        create_channel(&app, &created_server_id, fixture.channel.name()).await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let delete_channel_response = delete_channel(&app, &created_channel_id).await;
    assert_eq!(delete_channel_response.status(), StatusCode::NO_CONTENT);

    let list_channels_response = list_channels(&app, &created_server_id).await;
    assert_eq!(list_channels_response.status(), StatusCode::OK);

    let list_channels_payload = response_payload_json(list_channels_response).await;
    let listed_channels = list_channels_payload
        .as_array()
        .expect("channel list payload to be array");

    assert!(listed_channels.is_empty());
}

#[tokio::test]
async fn given_server_owner_when_update_channel_name_then_status_is_204_and_channel_is_updated() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_payload = response_payload_json(
        create_channel(&app, &created_server_id, fixture.channel.name()).await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let updated_channel_name = "updated-channel-name";
    let update_channel_response =
        update_channel(&app, &created_channel_id, updated_channel_name).await;
    assert_eq!(update_channel_response.status(), StatusCode::NO_CONTENT);

    let list_channels_response = list_channels(&app, &created_server_id).await;
    assert_eq!(list_channels_response.status(), StatusCode::OK);

    let list_channels_payload = response_payload_json(list_channels_response).await;
    let listed_channels = list_channels_payload
        .as_array()
        .expect("channel list payload to be array");

    assert_eq!(listed_channels.len(), 1);
    assert_eq!(
        listed_channels[0]["id"].as_str(),
        Some(created_channel_id.as_str())
    );
    assert_eq!(
        listed_channels[0]["name"].as_str(),
        Some(updated_channel_name)
    );
}

#[tokio::test]
async fn given_non_owner_when_update_channel_name_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let member_user = entity_seeder.user();

    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_state = seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        shared_store.clone(),
    );
    let owner_app = build_app(owner_state);

    let member_state = seeded_state_with_store(
        &member_user.external_reference,
        "member-token",
        shared_store,
    );
    let member_app = build_app(member_state);

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user.id.to_string(),
        "owner-token",
    )
    .await;
    assert_eq!(add_member_response.status(), StatusCode::CREATED);

    let create_channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &created_server_id,
            fixture.channel.name(),
            "text",
            "owner-token",
        )
        .await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let update_channel_response =
        update_channel_with_token(&member_app, &created_channel_id, "new-name", "member-token")
            .await;

    assert_eq!(update_channel_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_channel_when_update_channel_name_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let update_channel_response =
        update_channel(&app, "00000000-0000-0000-0000-000000000001", "updated").await;

    assert_eq!(update_channel_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_non_owner_when_delete_channel_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let member_user = entity_seeder.user();

    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_state = seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        shared_store.clone(),
    );
    let owner_app = build_app(owner_state);

    let member_state = seeded_state_with_store(
        &member_user.external_reference,
        "member-token",
        shared_store,
    );
    let member_app = build_app(member_state);

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user.id.to_string(),
        "owner-token",
    )
    .await;
    assert_eq!(add_member_response.status(), StatusCode::CREATED);

    let create_channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &created_server_id,
            fixture.channel.name(),
            "text",
            "owner-token",
        )
        .await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let delete_channel_response =
        delete_channel_with_token(&member_app, &created_channel_id, "member-token").await;

    assert_eq!(delete_channel_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_channel_when_delete_channel_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let delete_channel_response =
        delete_channel(&app, "00000000-0000-0000-0000-000000000001").await;

    assert_eq!(delete_channel_response.status(), StatusCode::NOT_FOUND);
}

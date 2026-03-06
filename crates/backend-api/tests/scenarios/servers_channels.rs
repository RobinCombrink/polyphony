use axum::http::StatusCode;
use backend_api::build_app;
use std::sync::Arc;
use uuid::Uuid;

use super::common::{
    bdd_support::{
        add_server_member, add_server_member_with_token, create_channel, create_channel_with_token,
        create_server, create_server_with_token, delete_channel, delete_channel_with_token,
        delete_server, delete_server_with_token, get_me_with_token, list_channels,
        list_channels_with_token, list_servers, list_servers_with_token, payload_uuid,
        response_payload_json, seeded_state, seeded_state_with_store, update_channel,
        update_channel_with_token,
    },
    entity_seeder::EntitySeeder,
};
use backend_api::storage::InMemoryRepository;

#[tokio::test]
async fn given_authenticated_user_when_creating_server_then_server_id_is_returned() {
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
async fn given_existing_server_when_creating_channel_then_channel_id_is_returned() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let create_channel_response =
        create_channel(&app, &created_server_id, fixture.channel.name()).await;

    assert_eq!(create_channel_response.status(), StatusCode::CREATED);

    let create_channel_payload = response_payload_json(create_channel_response).await;
    assert_eq!(
        payload_uuid(&create_channel_payload, "server_id"),
        created_server_id
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

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
async fn given_non_member_server_when_listing_channels_then_access_is_forbidden() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let second_user = entity_seeder.user();

    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_app = build_app(seeded_state_with_store(
        &fixture.user.external_reference,
        "owner-token",
        Arc::clone(&shared_store),
    ));

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await,
    )
    .await;
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let create_channel_response = create_channel_with_token(
        &owner_app,
        &created_server_id,
        fixture.channel.name(),
        "text",
        "owner-token",
    )
    .await;
    assert_eq!(create_channel_response.status(), StatusCode::CREATED);

    let second_user_app = build_app(seeded_state_with_store(
        &second_user.external_reference,
        "member-token",
        shared_store,
    ));

    let response =
        list_channels_with_token(&second_user_app, &created_server_id, "member-token").await;

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let add_server_member_response =
        add_server_member(&app, &created_server_id, &additional_user.id).await;

    assert_eq!(add_server_member_response.status(), StatusCode::CREATED);

    let add_server_member_payload = response_payload_json(add_server_member_response).await;
    assert_eq!(
        payload_uuid(&add_server_member_payload, "server_id"),
        created_server_id
    );
    assert_eq!(
        payload_uuid(&add_server_member_payload, "user_id"),
        additional_user.id
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let member_me_payload =
        response_payload_json(get_me_with_token(&member_app, "member-token").await).await;
    let member_user_id = payload_uuid(&member_me_payload, "user_id");

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
    assert_eq!(payload_uuid(&listed_servers[0], "id"), created_server_id);
}

#[tokio::test]
async fn given_non_owner_when_adding_server_member_then_action_is_forbidden() {
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let add_owner_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &existing_member.id,
        "owner-token",
    )
    .await;
    assert_eq!(add_owner_member_response.status(), StatusCode::CREATED);

    let non_owner_add_response = add_server_member_with_token(
        &member_app,
        &created_server_id,
        &target_user.id,
        "member-token",
    )
    .await;

    assert_eq!(non_owner_add_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_server_owner_when_deleting_server_then_server_is_removed() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_response = create_server(&app, &fixture.server.name).await;
    assert_eq!(create_server_response.status(), StatusCode::CREATED);

    let create_server_payload = response_payload_json(create_server_response).await;
    let created_server_id = payload_uuid(&create_server_payload, "id");

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
async fn given_non_owner_when_deleting_server_then_action_is_forbidden() {
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user.id,
        "owner-token",
    )
    .await;
    assert_eq!(add_member_response.status(), StatusCode::CREATED);

    let delete_server_response =
        delete_server_with_token(&member_app, &created_server_id, "member-token").await;

    assert_eq!(delete_server_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_server_when_deleting_then_reports_server_missing() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let missing_server_id = Uuid::new_v4();
    let delete_server_response = delete_server(&app, &missing_server_id).await;

    assert_eq!(delete_server_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_server_owner_when_deleting_channel_then_channel_is_removed() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let create_channel_payload = response_payload_json(
        create_channel(&app, &created_server_id, fixture.channel.name()).await,
    )
    .await;
    let created_channel_id = payload_uuid(&create_channel_payload, "id");

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
async fn given_server_owner_when_updating_channel_name_then_channel_is_updated() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let create_channel_payload = response_payload_json(
        create_channel(&app, &created_server_id, fixture.channel.name()).await,
    )
    .await;
    let created_channel_id = payload_uuid(&create_channel_payload, "id");

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
    assert_eq!(payload_uuid(&listed_channels[0], "id"), created_channel_id);
    assert_eq!(
        listed_channels[0]["name"].as_str(),
        Some(updated_channel_name)
    );
}

#[tokio::test]
async fn given_non_owner_when_updating_channel_name_then_action_is_forbidden() {
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user.id,
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
    let created_channel_id = payload_uuid(&create_channel_payload, "id");

    let update_channel_response =
        update_channel_with_token(&member_app, &created_channel_id, "new-name", "member-token")
            .await;

    assert_eq!(update_channel_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_channel_when_updating_name_then_reports_channel_missing() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let missing_channel_id = Uuid::new_v4();
    let update_channel_response = update_channel(&app, &missing_channel_id, "updated").await;

    assert_eq!(update_channel_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_non_owner_when_deleting_channel_then_action_is_forbidden() {
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
    let created_server_id = payload_uuid(&create_server_payload, "id");

    let add_member_response = add_server_member_with_token(
        &owner_app,
        &created_server_id,
        &member_user.id,
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
    let created_channel_id = payload_uuid(&create_channel_payload, "id");

    let delete_channel_response =
        delete_channel_with_token(&member_app, &created_channel_id, "member-token").await;

    assert_eq!(delete_channel_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_channel_when_deleting_then_reports_channel_missing() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let missing_channel_id = Uuid::new_v4();
    let delete_channel_response = delete_channel(&app, &missing_channel_id).await;

    assert_eq!(delete_channel_response.status(), StatusCode::NOT_FOUND);
}

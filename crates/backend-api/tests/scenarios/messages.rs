use std::sync::Arc;

use axum::http::StatusCode;
use backend_api::{build_app, storage::InMemoryRepository};

use super::common::{
    bdd_support::{
        create_channel, create_channel_with_token, create_message, create_message_with_token,
        create_server, create_server_with_token, delete_message, delete_message_with_token,
        list_messages, list_messages_with_token, response_payload_json, seeded_state,
        seeded_state_with_store,
        update_message, update_message_with_token,
    },
    entity_seeder::EntitySeeder,
};

#[tokio::test]
async fn given_existing_channel_when_create_message_then_message_is_listed_for_channel() {
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

    let create_message_response =
        create_message(&app, &created_channel_id, &fixture.message.content).await;

    assert_eq!(create_message_response.status(), StatusCode::CREATED);

    let list_messages_payload =
        response_payload_json(list_messages(&app, &created_channel_id).await).await;

    let listed_messages = list_messages_payload
        .as_array()
        .expect("messages payload to be array");

    assert_eq!(listed_messages.len(), 1);
    assert_eq!(
        listed_messages[0]["content"].as_str(),
        Some(fixture.message.content.as_str())
    );
}

#[tokio::test]
async fn given_voice_channel_when_create_message_then_status_is_422_with_kind_mismatch() {
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
        create_channel_with_token(
            &app,
            &created_server_id,
            fixture.channel.name(),
            "voice",
            "valid-token",
        )
        .await,
    )
    .await;

    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let create_message_response =
        create_message(&app, &created_channel_id, &fixture.message.content).await;

    assert_eq!(
        create_message_response.status(),
        StatusCode::UNPROCESSABLE_ENTITY
    );

    let payload = response_payload_json(create_message_response).await;
    assert_eq!(
        payload["error_code"].as_str(),
        Some("CHANNEL_KIND_MISMATCH")
    );
}

#[tokio::test]
async fn given_existing_message_when_update_message_then_updated_content_is_listed() {
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

    let create_message_payload = response_payload_json(
        create_message(&app, &created_channel_id, &fixture.message.content).await,
    )
    .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let update_response = update_message(
        &app,
        &created_channel_id,
        &created_message_id,
        "updated message",
    )
    .await;

    assert_eq!(update_response.status(), StatusCode::OK);

    let list_messages_payload =
        response_payload_json(list_messages(&app, &created_channel_id).await).await;

    let listed_messages = list_messages_payload
        .as_array()
        .expect("messages payload to be array");

    assert_eq!(listed_messages.len(), 1);
    assert_eq!(
        listed_messages[0]["content"].as_str(),
        Some("updated message")
    );
}

#[tokio::test]
async fn given_existing_message_when_delete_message_then_message_is_removed_from_list() {
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

    let create_message_payload = response_payload_json(
        create_message(&app, &created_channel_id, &fixture.message.content).await,
    )
    .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let delete_response = delete_message(&app, &created_channel_id, &created_message_id).await;
    assert_eq!(delete_response.status(), StatusCode::NO_CONTENT);

    let list_messages_payload =
        response_payload_json(list_messages(&app, &created_channel_id).await).await;

    let listed_messages = list_messages_payload
        .as_array()
        .expect("messages payload to be array");

    assert_eq!(listed_messages.len(), 0);
}

#[tokio::test]
async fn given_message_owned_by_another_user_when_update_message_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let owner_subject = "auth0|owner-user";
    let other_subject = "auth0|other-user";
    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_app = build_app(seeded_state_with_store(
        owner_subject,
        "owner-token",
        Arc::clone(&shared_store),
    ));

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

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

    let create_message_payload = response_payload_json(
        create_message_with_token(
            &owner_app,
            &created_channel_id,
            &fixture.message.content,
            "owner-token",
        )
        .await,
    )
    .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let other_user_app = build_app(seeded_state_with_store(
        other_subject,
        "other-token",
        shared_store,
    ));

    let update_response = update_message_with_token(
        &other_user_app,
        &created_channel_id,
        &created_message_id,
        "attempted edit",
        "other-token",
    )
    .await;

    assert_eq!(update_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_message_owned_by_another_user_when_delete_message_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let owner_subject = "auth0|owner-user";
    let other_subject = "auth0|other-user";
    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_app = build_app(seeded_state_with_store(
        owner_subject,
        "owner-token",
        Arc::clone(&shared_store),
    ));

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

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

    let create_message_payload = response_payload_json(
        create_message_with_token(
            &owner_app,
            &created_channel_id,
            &fixture.message.content,
            "owner-token",
        )
        .await,
    )
    .await;
    let created_message_id = create_message_payload["id"]
        .as_str()
        .expect("created message id to be present")
        .to_owned();

    let other_user_app = build_app(seeded_state_with_store(
        other_subject,
        "other-token",
        shared_store,
    ));

    let delete_response = delete_message_with_token(
        &other_user_app,
        &created_channel_id,
        &created_message_id,
        "other-token",
    )
    .await;

    assert_eq!(delete_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_channel_owned_by_another_server_when_list_messages_then_status_is_403() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();
    let other_user = entity_seeder.user();

    let owner_subject = fixture.user.external_reference.clone();
    let other_subject = other_user.external_reference.clone();
    let shared_store = Arc::new(InMemoryRepository::new());

    let owner_app = build_app(seeded_state_with_store(
        &owner_subject,
        "owner-token",
        Arc::clone(&shared_store),
    ));

    let create_server_payload = response_payload_json(
        create_server_with_token(&owner_app, &fixture.server.name, "owner-token").await,
    )
    .await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

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

    let other_user_app = build_app(seeded_state_with_store(
        &other_subject,
        "other-token",
        shared_store,
    ));

    let response = list_messages_with_token(&other_user_app, &created_channel_id, "other-token").await;

    assert_eq!(response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_missing_message_when_update_message_then_status_is_404() {
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

    let response = update_message(
        &app,
        &created_channel_id,
        "00000000-0000-0000-0000-000000000001",
        "attempted update",
    )
    .await;

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_missing_channel_when_update_message_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let response = update_message(
        &app,
        "00000000-0000-0000-0000-000000000001",
        "00000000-0000-0000-0000-000000000001",
        "attempted update",
    )
    .await;

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_missing_message_when_delete_message_then_status_is_404() {
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

    let response = delete_message(
        &app,
        &created_channel_id,
        "00000000-0000-0000-0000-000000000001",
    )
    .await;

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_missing_channel_when_delete_message_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let response = delete_message(
        &app,
        "00000000-0000-0000-0000-000000000001",
        "00000000-0000-0000-0000-000000000001",
    )
    .await;

    assert_eq!(response.status(), StatusCode::NOT_FOUND);
}

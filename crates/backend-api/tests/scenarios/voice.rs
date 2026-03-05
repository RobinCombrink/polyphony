use axum::http::StatusCode;
use backend_api::build_app;
use backend_api::storage::InMemoryRepository;
use std::sync::Arc;
use uuid::Uuid;

use super::common::{
    bdd_support::{
        connect_channel_session_with_type, connect_voice_session, connect_voice_session_with_token,
        create_channel_with_token, create_server, create_server_with_token, create_voice_channel,
        response_payload_json, seeded_state, seeded_state_with_store,
    },
    entity_seeder::EntitySeeder,
};

#[tokio::test]
async fn given_existing_voice_channel_when_connecting_then_connection_details_are_returned() {
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
        create_voice_channel(&app, &created_server_id, fixture.channel.name()).await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let connect_response = connect_voice_session(&app, &created_channel_id).await;

    assert_eq!(connect_response.status(), StatusCode::OK);

    let payload = response_payload_json(connect_response).await;

    assert_eq!(
        payload["channel_id"].as_str(),
        Some(created_channel_id.as_str())
    );
    let participant_user_id = payload["participant_user_id"]
        .as_str()
        .expect("participant user id to be present");
    assert!(Uuid::parse_str(participant_user_id).is_ok());
    assert_eq!(payload["livekit_url"].as_str(), Some("ws://127.0.0.1:7880"));
    assert!(
        payload["access_token"]
            .as_str()
            .expect("access token to be present")
            .len()
            > 10
    );
}

#[tokio::test]
async fn given_missing_channel_when_connecting_voice_then_reports_channel_missing() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let connect_response =
        connect_voice_session(&app, "00000000-0000-0000-0000-000000000001").await;

    assert_eq!(connect_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_non_member_channel_when_connecting_voice_then_access_is_forbidden() {
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
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_payload = response_payload_json(
        create_channel_with_token(
            &owner_app,
            &created_server_id,
            fixture.channel.name(),
            "voice",
            "owner-token",
        )
        .await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let second_user_app = build_app(seeded_state_with_store(
        &second_user.external_reference,
        "member-token",
        shared_store,
    ));

    let connect_response =
        connect_voice_session_with_token(&second_user_app, &created_channel_id, "member-token")
            .await;

    assert_eq!(connect_response.status(), StatusCode::FORBIDDEN);
}

#[tokio::test]
async fn given_text_channel_when_connecting_voice_then_channel_type_is_incompatible() {
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
            "text",
            "valid-token",
        )
        .await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let connect_response = connect_voice_session(&app, &created_channel_id).await;

    assert_eq!(connect_response.status(), StatusCode::UNPROCESSABLE_ENTITY);

    let payload = response_payload_json(connect_response).await;
    assert_eq!(
        payload["error_code"].as_str(),
        Some("CHANNEL_KIND_MISMATCH")
    );
}

#[tokio::test]
async fn given_voice_channel_when_connecting_text_session_then_channel_type_is_incompatible() {
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
        create_voice_channel(&app, &created_server_id, fixture.channel.name()).await,
    )
    .await;
    let created_channel_id = create_channel_payload["id"]
        .as_str()
        .expect("created channel id to be present")
        .to_owned();

    let connect_response =
        connect_channel_session_with_type(&app, &created_channel_id, "text").await;

    assert_eq!(connect_response.status(), StatusCode::UNPROCESSABLE_ENTITY);

    let payload = response_payload_json(connect_response).await;
    assert_eq!(
        payload["error_code"].as_str(),
        Some("CHANNEL_KIND_MISMATCH")
    );
}

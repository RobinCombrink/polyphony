use axum::http::StatusCode;
use backend_api::build_app;
use uuid::Uuid;

#[path = "../common.rs"]
mod common;

use common::{
    bdd_support::{
        connect_voice_session, create_channel, create_server, list_voice_sessions,
        response_payload_json, seeded_state,
    },
    entity_seeder::EntitySeeder,
};

#[tokio::test]
async fn given_existing_channel_when_connect_voice_session_then_returns_livekit_credentials() {
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
        create_channel(&app, &created_server_id, &fixture.channel.name).await,
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
async fn given_missing_channel_when_connect_voice_session_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let connect_response =
        connect_voice_session(&app, "00000000-0000-0000-0000-000000000001").await;

    assert_eq!(connect_response.status(), StatusCode::NOT_FOUND);
}

#[tokio::test]
async fn given_connected_voice_channel_when_connecting_to_another_then_only_second_channel_has_user()
 {
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

    let first_channel_payload = response_payload_json(
        create_channel(&app, &created_server_id, &fixture.channel.name).await,
    )
    .await;
    let first_channel_id = first_channel_payload["id"]
        .as_str()
        .expect("first channel id to be present")
        .to_owned();

    let second_channel_payload =
        response_payload_json(create_channel(&app, &created_server_id, "voice-two").await).await;
    let second_channel_id = second_channel_payload["id"]
        .as_str()
        .expect("second channel id to be present")
        .to_owned();

    let first_connect_response = connect_voice_session(&app, &first_channel_id).await;
    assert_eq!(first_connect_response.status(), StatusCode::OK);

    let second_connect_response = connect_voice_session(&app, &second_channel_id).await;
    assert_eq!(second_connect_response.status(), StatusCode::OK);

    let first_sessions_payload =
        response_payload_json(list_voice_sessions(&app, &first_channel_id).await).await;
    let first_sessions = first_sessions_payload
        .as_array()
        .expect("first channel sessions payload to be an array");
    assert!(
        first_sessions.is_empty(),
        "first channel should not include connected user"
    );

    let second_sessions_payload =
        response_payload_json(list_voice_sessions(&app, &second_channel_id).await).await;
    let second_sessions = second_sessions_payload
        .as_array()
        .expect("second channel sessions payload to be an array");
    assert_eq!(second_sessions.len(), 1);

    let participant_user_id = second_sessions[0]["participant_user_id"]
        .as_str()
        .expect("participant user id to be present");
    assert!(Uuid::parse_str(participant_user_id).is_ok());
    assert_eq!(
        second_sessions[0]["channel_id"].as_str(),
        Some(second_channel_id.as_str())
    );
}

use axum::http::StatusCode;
use backend_api::build_app;
use uuid::Uuid;

use super::common::{
    bdd_support::{
        connect_voice_session, create_server, create_voice_channel, response_payload_json,
        seeded_state,
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
async fn given_missing_channel_when_connect_voice_session_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.external_reference, "valid-token");
    let app = build_app(state);

    let connect_response =
        connect_voice_session(&app, "00000000-0000-0000-0000-000000000001").await;

    assert_eq!(connect_response.status(), StatusCode::NOT_FOUND);
}

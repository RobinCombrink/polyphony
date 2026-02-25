use axum::http::StatusCode;
use backend_api::build_app;

use crate::bdd_support::{
    create_channel, create_server, join_voice_session, leave_voice_session, list_voice_sessions,
    response_payload_json, seeded_state,
};
use crate::entity_seeder::EntitySeeder;

#[tokio::test]
async fn given_existing_channel_when_join_voice_session_then_participant_is_listed() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
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

    let join_response = join_voice_session(&app, &created_channel_id).await;
    assert_eq!(join_response.status(), StatusCode::CREATED);

    let list_response = list_voice_sessions(&app, &created_channel_id).await;
    assert_eq!(list_response.status(), StatusCode::OK);

    let payload = response_payload_json(list_response).await;
    let sessions = payload
        .as_array()
        .expect("voice sessions payload to be array");

    assert_eq!(sessions.len(), 1);
    assert_eq!(
        sessions[0]["participant_subject"].as_str(),
        Some(fixture.user.auth0_subject.as_str())
    );
}

#[tokio::test]
async fn given_joined_voice_session_when_leave_voice_session_then_participant_is_removed() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
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

    let join_response = join_voice_session(&app, &created_channel_id).await;
    assert_eq!(join_response.status(), StatusCode::CREATED);

    let leave_response = leave_voice_session(&app, &created_channel_id).await;
    assert_eq!(leave_response.status(), StatusCode::NO_CONTENT);

    let list_response = list_voice_sessions(&app, &created_channel_id).await;
    assert_eq!(list_response.status(), StatusCode::OK);

    let payload = response_payload_json(list_response).await;
    let sessions = payload
        .as_array()
        .expect("voice sessions payload to be array");

    assert!(sessions.is_empty());
}

#[tokio::test]
async fn given_missing_channel_when_join_voice_session_then_status_is_404() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
    let app = build_app(state);

    let join_response = join_voice_session(&app, "chn-missing").await;

    assert_eq!(join_response.status(), StatusCode::NOT_FOUND);
}

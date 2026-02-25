use axum::http::StatusCode;
use backend_api::build_app;

use crate::bdd_support::{
    create_channel, create_server, list_channels, list_servers, response_payload_json, seeded_state,
};
use crate::entity_seeder::EntitySeeder;

#[tokio::test]
async fn given_authenticated_user_when_create_server_then_created_status_and_server_id_returned() {
    let entity_seeder = EntitySeeder;
    let fixture = entity_seeder.chat_fixture();

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
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

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
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

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_response =
        create_channel(&app, &created_server_id, &fixture.channel.name).await;

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

    let state = seeded_state(&fixture.user.auth0_subject, "valid-token");
    let app = build_app(state);

    let create_server_payload =
        response_payload_json(create_server(&app, &fixture.server.name).await).await;
    let created_server_id = create_server_payload["id"]
        .as_str()
        .expect("created server id to be present")
        .to_owned();

    let create_channel_response =
        create_channel(&app, &created_server_id, &fixture.channel.name).await;
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
        Some(fixture.channel.name.as_str())
    );
}

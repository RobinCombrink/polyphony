use backend_storage::{ChatRepository, MessageRepository, PostgresChatRepository};
use testcontainers_modules::{postgres::Postgres, testcontainers::runners::AsyncRunner};

#[tokio::test]
async fn migrations_apply_and_uuid_user_identity_flow_works() {
    let container = Postgres::default()
        .with_db_name("polyphony")
        .with_user("postgres")
        .with_password("postgres")
        .start()
        .await
        .expect("postgres container to start");

    let host = container
        .get_host()
        .await
        .expect("postgres host")
        .to_string();
    let port = container
        .get_host_port_ipv4(5432)
        .await
        .expect("postgres mapped port");

    let repository =
        PostgresChatRepository::connect(&host, port, "polyphony", "postgres", "postgres", 5)
            .await
            .expect("postgres repository initialization to succeed");

    let user = repository
        .get_or_create_user_by_external_reference("auth0|integration-user")
        .await;

    let server = repository
        .create_server("Integration Server".to_owned(), user.id)
        .await;

    let channel = repository
        .create_channel(server.id, "general".to_owned())
        .await
        .expect("channel to be created");

    let message = repository
        .create_message(channel.id, user.id, "hello from integration".to_owned())
        .await
        .expect("message to be created");

    let listed_messages = repository.list_messages(channel.id).await;

    assert_eq!(listed_messages.len(), 1);
    assert_eq!(listed_messages[0].id, message.id);
    assert_eq!(listed_messages[0].author_user_id, user.id);

    let voice_session = repository
        .join_voice_session(channel.id, user.id)
        .await
        .expect("voice session to be created");

    assert_eq!(voice_session.channel_id, channel.id);
    assert_eq!(voice_session.participant_user_id, user.id);
}

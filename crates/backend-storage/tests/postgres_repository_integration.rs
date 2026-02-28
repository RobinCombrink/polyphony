use backend_storage::{ChatRepository, MessageRepository, PostgresChatRepository, UserRepository};
use sqlx::PgPool;
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

    let connection_string = format!("postgres://postgres:postgres@{host}:{port}/polyphony");
    let pool = PgPool::connect(&connection_string)
        .await
        .expect("postgres pool to connect");

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

    assert_date_created_columns(&pool).await;
    assert_inserted_rows_have_date_created(&pool).await;
}

async fn assert_date_created_columns(pool: &PgPool) {
    let table_names = [
        "users",
        "servers",
        "server_members",
        "channels",
        "messages",
        "voice_sessions",
    ];

    for table_name in table_names {
        let found = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM information_schema.columns
             WHERE table_schema = 'public'
               AND table_name = $1
               AND column_name = 'date_created'",
        )
        .bind(table_name)
        .fetch_one(pool)
        .await
        .expect("date_created column query to succeed");

        assert_eq!(found, 1, "date_created column missing for {table_name}");
    }
}

async fn assert_inserted_rows_have_date_created(pool: &PgPool) {
    let table_names = [
        "users",
        "servers",
        "server_members",
        "channels",
        "messages",
        "voice_sessions",
    ];

    for table_name in table_names {
        let null_count = sqlx::query_scalar::<_, i64>(&format!(
            "SELECT COUNT(1) FROM {table_name} WHERE date_created IS NULL"
        ))
        .fetch_one(pool)
        .await
        .expect("date_created null check query to succeed");

        assert_eq!(
            null_count, 0,
            "found rows without date_created in {table_name}"
        );
    }
}

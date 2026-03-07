use backend_domain::{ChannelType, ExternalReference};
use backend_storage::{
    ChannelRepository, CreateMessageResult, MessageRepository, PostgresRepository,
    ServerRepository, UserRepository,
};
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
        PostgresRepository::connect(&host, port, "polyphony", "postgres", "postgres", 5)
            .await
            .expect("postgres repository initialization to succeed");

    let connection_string = format!("postgres://postgres:postgres@{host}:{port}/polyphony");
    let pool = PgPool::connect(&connection_string)
        .await
        .expect("postgres pool to connect");

    let user = repository
        .get_or_create_user_by_external_reference(&ExternalReference::from(
            "auth0|integration-user",
        ))
        .await;

    let member_user = repository
        .get_or_create_user_by_external_reference(&ExternalReference::from(
            "auth0|integration-member",
        ))
        .await;

    let server = repository
        .create_server("Integration Server".to_owned(), user.id)
        .await;

    let membership_result = repository
        .add_server_member(server.id, user.id, member_user.id)
        .await;
    assert_eq!(membership_result, backend_storage::MutationResult::Updated);

    let channel = repository
        .create_channel(server.id, "general".to_owned(), ChannelType::Text)
        .await
        .expect("channel to be created");

    let message = repository
        .create_message(channel.id(), user.id, "hello from integration".to_owned())
        .await;

    let message = match message {
        CreateMessageResult::Created {
            message: created_message,
            ..
        } => created_message,
        CreateMessageResult::Forbidden => panic!("message creation should not be forbidden"),
        CreateMessageResult::ChannelKindMismatch => {
            panic!("text channel should accept message creation")
        }
        CreateMessageResult::NotFound => panic!("message creation should find text channel"),
    };

    let listed_messages = repository.list_messages(channel.id()).await;

    assert_eq!(listed_messages.len(), 1);
    assert_eq!(listed_messages[0].id, message.id);
    assert_eq!(listed_messages[0].author_user_id, user.id);

    assert_notification_outbox_and_unread_counts(
        &pool,
        message.id,
        channel.id(),
        user.id,
        member_user.id,
    )
    .await;

    let _voice_channel = repository
        .create_channel(server.id, "voice".to_owned(), ChannelType::Voice)
        .await
        .expect("voice channel to be created");

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

async fn assert_notification_outbox_and_unread_counts(
    pool: &PgPool,
    message_id: backend_domain::MessageId,
    channel_id: backend_domain::ChannelId,
    author_user_id: backend_domain::UserId,
    recipient_user_id: backend_domain::UserId,
) {
    let outbox_rows = sqlx::query_scalar::<_, i64>(
        "SELECT COUNT(1)
         FROM notification_outbox
         WHERE event_type = 'message_created'
           AND message_id = $1
           AND channel_id = $2
           AND recipient_user_id = $3
           AND author_user_id = $4",
    )
    .bind(uuid::Uuid::from(message_id))
    .bind(uuid::Uuid::from(channel_id))
    .bind(uuid::Uuid::from(recipient_user_id))
    .bind(uuid::Uuid::from(author_user_id))
    .fetch_one(pool)
    .await
    .expect("notification outbox query to succeed");

    assert_eq!(outbox_rows, 1, "expected one outbox row for recipient");

    let unread_count = sqlx::query_scalar::<_, i64>(
        "SELECT unread_count
         FROM notification_unread_counts
         WHERE user_id = $1 AND channel_id = $2",
    )
    .bind(uuid::Uuid::from(recipient_user_id))
    .bind(uuid::Uuid::from(channel_id))
    .fetch_one(pool)
    .await
    .expect("unread counter query to succeed");

    assert_eq!(unread_count, 1, "expected unread count increment");
}

use async_trait::async_trait;
use backend_domain::{Channel, ChannelType, DisplayName, Membership, Message, Server, User};
use sqlx::migrate::Migrator;
use sqlx::{
    PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};
use uuid::Uuid;

use crate::{
    ChannelRepository, CreateMessageResult, MessageRepository, MutationResult, ServerRepository,
    UserRepository,
};

#[cfg(target_family = "windows")]
static MIGRATOR: Migrator = sqlx::migrate!(".\\migrations");

#[cfg(target_family = "unix")]
static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

#[derive(Debug, Clone)]
pub struct PostgresRepository {
    pool: PgPool,
}

impl PostgresRepository {
    pub async fn connect(
        host: &str,
        port: u16,
        database: &str,
        username: &str,
        password: &str,
        max_connections: u32,
    ) -> Result<Self, sqlx::Error> {
        let connect_options = PgConnectOptions::new()
            .host(host)
            .port(port)
            .database(database)
            .username(username)
            .password(password);

        let pool = PgPoolOptions::new()
            .max_connections(max_connections)
            .connect_with(connect_options)
            .await?;

        let repository = Self { pool };
        repository.initialize_schema().await?;

        Ok(repository)
    }

    async fn initialize_schema(&self) -> Result<(), sqlx::Error> {
        MIGRATOR.run(&self.pool).await?;
        Ok(())
    }

    async fn server_exists(&self, server_id: Uuid) -> Result<bool, sqlx::Error> {
        let row = sqlx::query_scalar::<_, i64>("SELECT COUNT(1) FROM servers WHERE id = $1")
            .bind(server_id)
            .fetch_one(&self.pool)
            .await?;

        Ok(row > 0)
    }

    async fn is_user_member_of_server(
        &self,
        server_id: Uuid,
        user_id: Uuid,
    ) -> Result<Option<bool>, sqlx::Error> {
        if !self.server_exists(server_id).await? {
            return Ok(None);
        }

        let row = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1) FROM server_members WHERE server_id = $1 AND user_id = $2",
        )
        .bind(server_id)
        .bind(user_id)
        .fetch_one(&self.pool)
        .await?;

        Ok(Some(row > 0))
    }

    async fn is_user_member_of_channel(
        &self,
        channel_id: Uuid,
        user_id: Uuid,
    ) -> Result<Option<bool>, sqlx::Error> {
        let server_id =
            sqlx::query_scalar::<_, Uuid>("SELECT server_id FROM channels WHERE id = $1")
                .bind(channel_id)
                .fetch_optional(&self.pool)
                .await?;

        let Some(server_id) = server_id else {
            return Ok(None);
        };

        self.is_user_member_of_server(server_id, user_id).await
    }
}

#[async_trait]
impl MessageRepository for PostgresRepository {
    async fn create_message(
        &self,
        channel_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> CreateMessageResult {
        let is_channel_member = match self
            .is_user_member_of_channel(channel_id, author_user_id)
            .await
        {
            Ok(Some(value)) => value,
            Ok(None) | Err(_) => return CreateMessageResult::NotFound,
        };

        if !is_channel_member {
            return CreateMessageResult::Forbidden;
        }

        let Some(channel) = self.find_channel_by_id(channel_id).await else {
            return CreateMessageResult::NotFound;
        };

        if channel.kind() != ChannelType::Text {
            return CreateMessageResult::ChannelKindMismatch;
        }

        sqlx::query_as::<_, (Uuid, Uuid, Uuid, String)>(
            "INSERT INTO messages (id, channel_id, author_user_id, content)
            VALUES (gen_random_uuid(), $1, $2, $3)
            RETURNING id, channel_id, author_user_id, content",
        )
        .bind(channel_id)
        .bind(author_user_id)
        .bind(content)
        .fetch_one(&self.pool)
        .await
        .ok()
        .map(|(id, channel_id, author_user_id, content)| Message {
            id,
            channel_id,
            author_user_id,
            content,
        })
        .map(CreateMessageResult::Created)
        .unwrap_or(CreateMessageResult::NotFound)
    }

    async fn update_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> MutationResult {
        let existing_author = sqlx::query_scalar::<_, Uuid>(
            "SELECT author_user_id FROM messages WHERE channel_id = $1 AND id = $2",
        )
        .bind(channel_id)
        .bind(message_id)
        .fetch_optional(&self.pool)
        .await;

        let existing_author = match existing_author {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(existing_author) = existing_author else {
            return MutationResult::NotFound;
        };

        if existing_author != author_user_id {
            return MutationResult::Forbidden;
        }

        let updated =
            sqlx::query("UPDATE messages SET content = $3 WHERE channel_id = $1 AND id = $2")
                .bind(channel_id)
                .bind(message_id)
                .bind(content)
                .execute(&self.pool)
                .await;

        match updated {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Updated,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn delete_message(
        &self,
        channel_id: Uuid,
        message_id: Uuid,
        author_user_id: Uuid,
    ) -> MutationResult {
        let existing_author = sqlx::query_scalar::<_, Uuid>(
            "SELECT author_user_id FROM messages WHERE channel_id = $1 AND id = $2",
        )
        .bind(channel_id)
        .bind(message_id)
        .fetch_optional(&self.pool)
        .await;

        let existing_author = match existing_author {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(existing_author) = existing_author else {
            return MutationResult::NotFound;
        };

        if existing_author != author_user_id {
            return MutationResult::Forbidden;
        }

        let deleted = sqlx::query("DELETE FROM messages WHERE channel_id = $1 AND id = $2")
            .bind(channel_id)
            .bind(message_id)
            .execute(&self.pool)
            .await;

        match deleted {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Deleted,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn list_messages(&self, channel_id: Uuid) -> Vec<Message> {
        sqlx::query_as::<_, (Uuid, Uuid, Uuid, String)>(
            "SELECT id, channel_id, author_user_id, content
             FROM messages
             WHERE channel_id = $1
             ORDER BY created_order ASC",
        )
        .bind(channel_id)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|(id, channel_id, author_user_id, content)| Message {
            id,
            channel_id,
            author_user_id,
            content,
        })
        .collect()
    }
}

#[async_trait]
impl UserRepository for PostgresRepository {
    async fn find_user_by_id(&self, user_id: Uuid) -> Option<User> {
        sqlx::query_as::<_, (Uuid, String, Option<String>)>(
            "SELECT id, external_reference, display_name
             FROM users
             WHERE id = $1",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .map(|(id, external_reference, display_name)| User {
            id,
            external_reference,
            display_name: display_name.map(DisplayName::new),
        })
    }

    async fn find_user_by_external_reference(&self, external_reference: &str) -> Option<User> {
        sqlx::query_as::<_, (Uuid, String, Option<String>)>(
            "SELECT id, external_reference, display_name
             FROM users
             WHERE external_reference = $1",
        )
        .bind(external_reference)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .map(|(id, external_reference, display_name)| User {
            id,
            external_reference,
            display_name: display_name.map(DisplayName::new),
        })
    }

    async fn get_or_create_user_by_external_reference(&self, external_reference: &str) -> User {
        let _ = sqlx::query(
            "INSERT INTO users (id, external_reference, display_name)
             VALUES (gen_random_uuid(), $1, NULL)
             ON CONFLICT (external_reference) DO NOTHING",
        )
        .bind(external_reference)
        .execute(&self.pool)
        .await;

        self.find_user_by_external_reference(external_reference)
            .await
            .unwrap_or(User {
                id: Uuid::new_v4(),
                external_reference: external_reference.to_owned(),
                display_name: None,
            })
    }

    async fn set_user_display_name(&self, user_id: Uuid, display_name: String) -> Option<User> {
        let _ = sqlx::query(
            "UPDATE users
             SET display_name = $2
             WHERE id = $1",
        )
        .bind(user_id)
        .bind(display_name)
        .execute(&self.pool)
        .await;

        self.find_user_by_id(user_id).await
    }
}

#[async_trait]
impl ServerRepository for PostgresRepository {
    async fn create_server(&self, name: String, owner_user_id: Uuid) -> Server {
        let (server_id, owner_user_id_created) = sqlx::query_as::<_, (Uuid, Uuid)>(
            "WITH inserted AS (
                INSERT INTO servers (id, name, owner_user_id)
                VALUES (gen_random_uuid(), $1, $2)
                RETURNING id, owner_user_id
            )
            INSERT INTO server_members (server_id, user_id)
            SELECT id, owner_user_id
            FROM inserted
            ON CONFLICT (server_id, user_id) DO NOTHING
            RETURNING server_id, user_id",
        )
        .bind(&name)
        .bind(owner_user_id)
        .fetch_one(&self.pool)
        .await
        .expect("create server in postgres to succeed");

        Server {
            id: server_id,
            name,
            owner_user_id: owner_user_id_created,
        }
    }

    async fn list_servers_for_user(&self, user_id: Uuid) -> Vec<Server> {
        sqlx::query_as::<_, (Uuid, String, Uuid)>(
            "SELECT s.id, s.name, s.owner_user_id
             FROM servers s
             INNER JOIN server_members sm ON sm.server_id = s.id
             WHERE sm.user_id = $1
             ORDER BY s.id ASC",
        )
        .bind(user_id)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|(id, name, owner_user_id)| Server {
            id,
            name,
            owner_user_id,
        })
        .collect()
    }

    async fn is_server_member(&self, server_id: Uuid, user_id: Uuid) -> Option<bool> {
        self.is_user_member_of_server(server_id, user_id)
            .await
            .ok()?
    }

    async fn add_server_member(
        &self,
        server_id: Uuid,
        actor_user_id: Uuid,
        user_id: Uuid,
    ) -> MutationResult {
        let owner_user_id =
            sqlx::query_scalar::<_, Uuid>("SELECT owner_user_id FROM servers WHERE id = $1")
                .bind(server_id)
                .fetch_optional(&self.pool)
                .await;

        let owner_user_id = match owner_user_id {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_user_id) = owner_user_id else {
            return MutationResult::NotFound;
        };

        if owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        let inserted = sqlx::query(
            "INSERT INTO server_members (server_id, user_id)
             VALUES ($1, $2)
             ON CONFLICT (server_id, user_id) DO NOTHING",
        )
        .bind(server_id)
        .bind(user_id)
        .execute(&self.pool)
        .await;

        match inserted {
            Ok(_) => MutationResult::Updated,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn delete_server(&self, server_id: Uuid, actor_user_id: Uuid) -> MutationResult {
        let owner_user_id =
            sqlx::query_scalar::<_, Uuid>("SELECT owner_user_id FROM servers WHERE id = $1")
                .bind(server_id)
                .fetch_optional(&self.pool)
                .await;

        let owner_user_id = match owner_user_id {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_user_id) = owner_user_id else {
            return MutationResult::NotFound;
        };

        if owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        let deleted = sqlx::query("DELETE FROM servers WHERE id = $1")
            .bind(server_id)
            .execute(&self.pool)
            .await;

        match deleted {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Deleted,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn list_server_members(&self, server_id: Uuid) -> Option<Vec<Membership>> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let members = sqlx::query_as::<_, (Uuid, Uuid)>(
            "SELECT server_id, user_id
             FROM server_members
             WHERE server_id = $1
             ORDER BY user_id ASC",
        )
        .bind(server_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(|(server_id, user_id)| Membership { user_id, server_id })
        .collect();

        Some(members)
    }
}

#[async_trait]
impl ChannelRepository for PostgresRepository {
    async fn create_channel(
        &self,
        server_id: Uuid,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let channel_type_value = match channel_type {
            ChannelType::Text => "text",
            ChannelType::Voice => "voice",
        };

        sqlx::query_as::<_, (Uuid, Uuid, String, String)>(
            "INSERT INTO channels (id, server_id, name, channel_type)
            VALUES (gen_random_uuid(), $1, $2, $3)
            RETURNING id, server_id, name, channel_type",
        )
        .bind(server_id)
        .bind(name)
        .bind(channel_type_value)
        .fetch_one(&self.pool)
        .await
        .ok()
        .and_then(
            |(id, server_id, name, channel_type)| match channel_type.as_str() {
                "text" => Some(Channel::new_text(id, server_id, name)),
                "voice" => Some(Channel::new_voice(id, server_id, name)),
                _ => None,
            },
        )
    }

    async fn update_channel_name(
        &self,
        channel_id: Uuid,
        actor_user_id: Uuid,
        name: String,
    ) -> MutationResult {
        let owner_user_id = sqlx::query_scalar::<_, Uuid>(
            "SELECT s.owner_user_id
             FROM channels c
             INNER JOIN servers s ON s.id = c.server_id
             WHERE c.id = $1",
        )
        .bind(channel_id)
        .fetch_optional(&self.pool)
        .await;

        let owner_user_id = match owner_user_id {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_user_id) = owner_user_id else {
            return MutationResult::NotFound;
        };

        if owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        let updated = sqlx::query("UPDATE channels SET name = $1 WHERE id = $2")
            .bind(name)
            .bind(channel_id)
            .execute(&self.pool)
            .await;

        match updated {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Updated,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn delete_channel(&self, channel_id: Uuid, actor_user_id: Uuid) -> MutationResult {
        let owner_user_id = sqlx::query_scalar::<_, Uuid>(
            "SELECT s.owner_user_id
             FROM channels c
             INNER JOIN servers s ON s.id = c.server_id
             WHERE c.id = $1",
        )
        .bind(channel_id)
        .fetch_optional(&self.pool)
        .await;

        let owner_user_id = match owner_user_id {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_user_id) = owner_user_id else {
            return MutationResult::NotFound;
        };

        if owner_user_id != actor_user_id {
            return MutationResult::Forbidden;
        }

        let deleted = sqlx::query("DELETE FROM channels WHERE id = $1")
            .bind(channel_id)
            .execute(&self.pool)
            .await;

        match deleted {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Deleted,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn list_channels_for_server(&self, server_id: Uuid) -> Option<Vec<Channel>> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let channels = sqlx::query_as::<_, (Uuid, Uuid, String, String)>(
            "SELECT id, server_id, name, channel_type
             FROM channels
             WHERE server_id = $1
             ORDER BY id ASC",
        )
        .bind(server_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .filter_map(
            |(id, server_id, name, channel_type)| match channel_type.as_str() {
                "text" => Some(Channel::new_text(id, server_id, name)),
                "voice" => Some(Channel::new_voice(id, server_id, name)),
                _ => None,
            },
        )
        .collect();

        Some(channels)
    }

    async fn find_channel_by_id(&self, channel_id: Uuid) -> Option<Channel> {
        sqlx::query_as::<_, (Uuid, Uuid, String, String)>(
            "SELECT id, server_id, name, channel_type
             FROM channels
             WHERE id = $1",
        )
        .bind(channel_id)
        .fetch_optional(&self.pool)
        .await
        .ok()?
        .and_then(
            |(id, server_id, name, channel_type)| match channel_type.as_str() {
                "text" => Some(Channel::new_text(id, server_id, name)),
                "voice" => Some(Channel::new_voice(id, server_id, name)),
                _ => None,
            },
        )
    }

    async fn is_channel_member(&self, channel_id: Uuid, user_id: Uuid) -> Option<bool> {
        self.is_user_member_of_channel(channel_id, user_id)
            .await
            .ok()?
    }
}

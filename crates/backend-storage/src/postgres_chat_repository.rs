use async_trait::async_trait;
use backend_domain::{Channel, DisplayName, Membership, Message, Server, User, VoiceSession};
use sqlx::migrate::Migrator;
use sqlx::{PgPool, postgres::PgPoolOptions};
use uuid::Uuid;

use crate::{
    ChannelRepository, MessageRepository, MutationResult, ServerRepository, UserRepository,
    VoiceRepository,
};

#[cfg(target_family = "windows")]
static MIGRATOR: Migrator = sqlx::migrate!(".\\migrations");

#[cfg(target_family = "unix")]
static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

#[derive(Debug, Clone)]
pub struct PostgresChatRepository {
    pool: PgPool,
}

impl PostgresChatRepository {
    pub async fn connect(
        host: &str,
        port: u16,
        database: &str,
        username: &str,
        password: &str,
        max_connections: u32,
    ) -> Result<Self, sqlx::Error> {
        let connection_string =
            format!("postgres://{username}:{password}@{host}:{port}/{database}");

        let pool = PgPoolOptions::new()
            .max_connections(max_connections)
            .connect(&connection_string)
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

    async fn channel_exists(&self, channel_id: Uuid) -> Result<bool, sqlx::Error> {
        let row = sqlx::query_scalar::<_, i64>("SELECT COUNT(1) FROM channels WHERE id = $1")
            .bind(channel_id)
            .fetch_one(&self.pool)
            .await?;

        Ok(row > 0)
    }
}

#[async_trait]
impl MessageRepository for PostgresChatRepository {
    async fn create_message(
        &self,
        channel_id: Uuid,
        author_user_id: Uuid,
        content: String,
    ) -> Option<Message> {
        if !self.channel_exists(channel_id).await.ok()? {
            return None;
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
impl UserRepository for PostgresChatRepository {
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
impl ServerRepository for PostgresChatRepository {
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
impl ChannelRepository for PostgresChatRepository {
    async fn create_channel(&self, server_id: Uuid, name: String) -> Option<Channel> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        sqlx::query_as::<_, (Uuid, Uuid, String)>(
            "INSERT INTO channels (id, server_id, name)
            VALUES (gen_random_uuid(), $1, $2)
            RETURNING id, server_id, name",
        )
        .bind(server_id)
        .bind(name)
        .fetch_one(&self.pool)
        .await
        .ok()
        .map(|(id, server_id, name)| Channel {
            id,
            server_id,
            name,
        })
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

        let channels = sqlx::query_as::<_, (Uuid, Uuid, String)>(
            "SELECT id, server_id, name
             FROM channels
             WHERE server_id = $1
             ORDER BY id ASC",
        )
        .bind(server_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(|(id, server_id, name)| Channel {
            id,
            server_id,
            name,
        })
        .collect();

        Some(channels)
    }
}

#[async_trait]
impl VoiceRepository for PostgresChatRepository {
    async fn join_voice_session(
        &self,
        channel_id: Uuid,
        participant_user_id: Uuid,
    ) -> Option<VoiceSession> {
        if !self.channel_exists(channel_id).await.ok()? {
            return None;
        }

        let upserted = sqlx::query_as::<_, (bool,)>(
            "INSERT INTO voice_sessions (channel_id, participant_user_id, is_muted)
             VALUES ($1, $2, FALSE)
               ON CONFLICT (participant_user_id)
               DO UPDATE SET channel_id = EXCLUDED.channel_id
             RETURNING is_muted",
        )
        .bind(channel_id)
        .bind(participant_user_id)
        .fetch_one(&self.pool)
        .await;

        let is_muted = upserted.ok()?.0;

        Some(VoiceSession {
            channel_id,
            participant_user_id,
            is_muted,
        })
    }

    async fn leave_voice_session(
        &self,
        channel_id: Uuid,
        participant_user_id: Uuid,
    ) -> MutationResult {
        if !self.channel_exists(channel_id).await.unwrap_or(false) {
            return MutationResult::NotFound;
        }

        let deleted = sqlx::query(
            "DELETE FROM voice_sessions
               WHERE channel_id = $1 AND participant_user_id = $2",
        )
        .bind(channel_id)
        .bind(participant_user_id)
        .execute(&self.pool)
        .await;

        match deleted {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Deleted,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn set_voice_session_muted(
        &self,
        channel_id: Uuid,
        participant_user_id: Uuid,
        is_muted: bool,
    ) -> MutationResult {
        if !self.channel_exists(channel_id).await.unwrap_or(false) {
            return MutationResult::NotFound;
        }

        let updated = sqlx::query(
            "UPDATE voice_sessions
             SET is_muted = $3
             WHERE channel_id = $1 AND participant_user_id = $2",
        )
        .bind(channel_id)
        .bind(participant_user_id)
        .bind(is_muted)
        .execute(&self.pool)
        .await;

        match updated {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Updated,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn list_voice_sessions(&self, channel_id: Uuid) -> Option<Vec<VoiceSession>> {
        if !self.channel_exists(channel_id).await.ok()? {
            return None;
        }

        let sessions = sqlx::query_as::<_, (Uuid, Uuid, bool)>(
            "SELECT channel_id, participant_user_id, is_muted
             FROM voice_sessions
             WHERE channel_id = $1
             ORDER BY participant_user_id ASC",
        )
        .bind(channel_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(|(channel_id, participant_user_id, is_muted)| VoiceSession {
            channel_id,
            participant_user_id,
            is_muted,
        })
        .collect();

        Some(sessions)
    }
}

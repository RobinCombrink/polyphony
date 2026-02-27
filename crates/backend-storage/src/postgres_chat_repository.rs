use async_trait::async_trait;
use backend_domain::{Channel, DisplayName, Membership, Message, Server, User, VoiceSession};
use sqlx::{PgPool, postgres::PgPoolOptions};

use crate::{ChatRepository, MessageRepository, MutationResult};

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
        sqlx::query("CREATE SEQUENCE IF NOT EXISTS server_id_seq")
            .execute(&self.pool)
            .await?;
        sqlx::query("CREATE SEQUENCE IF NOT EXISTS channel_id_seq")
            .execute(&self.pool)
            .await?;
        sqlx::query("CREATE SEQUENCE IF NOT EXISTS message_id_seq")
            .execute(&self.pool)
            .await?;

        sqlx::query(
            "CREATE TABLE IF NOT EXISTS users (
                auth0_subject TEXT PRIMARY KEY,
                display_name TEXT NULL
            )",
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            "CREATE TABLE IF NOT EXISTS servers (
                id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                owner_subject TEXT NOT NULL
            )",
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            "CREATE TABLE IF NOT EXISTS server_members (
                server_id TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
                user_subject TEXT NOT NULL,
                PRIMARY KEY (server_id, user_subject)
            )",
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            "CREATE TABLE IF NOT EXISTS channels (
                id TEXT PRIMARY KEY,
                server_id TEXT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
                name TEXT NOT NULL
            )",
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            "CREATE TABLE IF NOT EXISTS messages (
                id TEXT PRIMARY KEY,
                channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
                author_subject TEXT NOT NULL,
                content TEXT NOT NULL,
                created_order BIGSERIAL NOT NULL
            )",
        )
        .execute(&self.pool)
        .await?;

        sqlx::query(
            "CREATE TABLE IF NOT EXISTS voice_sessions (
                channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
                participant_subject TEXT NOT NULL,
                PRIMARY KEY (channel_id, participant_subject)
            )",
        )
        .execute(&self.pool)
        .await?;

        Ok(())
    }

    async fn server_exists(&self, server_id: &str) -> Result<bool, sqlx::Error> {
        let row = sqlx::query_scalar::<_, i64>("SELECT COUNT(1) FROM servers WHERE id = $1")
            .bind(server_id)
            .fetch_one(&self.pool)
            .await?;

        Ok(row > 0)
    }

    async fn channel_exists(&self, channel_id: &str) -> Result<bool, sqlx::Error> {
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
        channel_id: &str,
        author_subject: String,
        content: String,
    ) -> Option<Message> {
        if !self.channel_exists(channel_id).await.ok()? {
            return None;
        }

        sqlx::query_as::<_, (String, String, String, String)>(
            "WITH generated AS (
                SELECT CONCAT('msg-', nextval('message_id_seq')::TEXT) AS id
            )
            INSERT INTO messages (id, channel_id, author_subject, content)
            SELECT generated.id, $1, $2, $3
            FROM generated
            RETURNING id, channel_id, author_subject, content",
        )
        .bind(channel_id)
        .bind(author_subject)
        .bind(content)
        .fetch_one(&self.pool)
        .await
        .ok()
        .map(|(id, channel_id, author_subject, content)| Message {
            id,
            channel_id,
            author_subject,
            content,
        })
    }

    async fn update_message(
        &self,
        channel_id: &str,
        message_id: &str,
        author_subject: &str,
        content: String,
    ) -> MutationResult {
        let existing_author = sqlx::query_scalar::<_, String>(
            "SELECT author_subject FROM messages WHERE channel_id = $1 AND id = $2",
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

        if existing_author != author_subject {
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
        channel_id: &str,
        message_id: &str,
        author_subject: &str,
    ) -> MutationResult {
        let existing_author = sqlx::query_scalar::<_, String>(
            "SELECT author_subject FROM messages WHERE channel_id = $1 AND id = $2",
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

        if existing_author != author_subject {
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

    async fn list_messages(&self, channel_id: &str) -> Vec<Message> {
        sqlx::query_as::<_, (String, String, String, String)>(
            "SELECT id, channel_id, author_subject, content
             FROM messages
             WHERE channel_id = $1
             ORDER BY created_order ASC",
        )
        .bind(channel_id)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|(id, channel_id, author_subject, content)| Message {
            id,
            channel_id,
            author_subject,
            content,
        })
        .collect()
    }
}

#[async_trait]
impl ChatRepository for PostgresChatRepository {
    async fn find_user_by_subject(&self, auth0_subject: &str) -> Option<User> {
        sqlx::query_as::<_, (String, Option<String>)>(
            "SELECT auth0_subject, display_name
             FROM users
             WHERE auth0_subject = $1",
        )
        .bind(auth0_subject)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .map(|(auth0_subject, display_name)| User {
            auth0_subject,
            display_name: display_name.map(DisplayName::new),
        })
    }

    async fn get_or_create_user(&self, auth0_subject: &str) -> User {
        let _ = sqlx::query(
            "INSERT INTO users (auth0_subject, display_name)
             VALUES ($1, NULL)
             ON CONFLICT (auth0_subject) DO NOTHING",
        )
        .bind(auth0_subject)
        .execute(&self.pool)
        .await;

        self.find_user_by_subject(auth0_subject)
            .await
            .unwrap_or(User {
                auth0_subject: auth0_subject.to_owned(),
                display_name: None,
            })
    }

    async fn set_user_display_name(&self, auth0_subject: &str, display_name: String) -> User {
        let _ = sqlx::query(
            "INSERT INTO users (auth0_subject, display_name)
             VALUES ($1, $2)
             ON CONFLICT (auth0_subject)
             DO UPDATE SET display_name = EXCLUDED.display_name",
        )
        .bind(auth0_subject)
        .bind(display_name)
        .execute(&self.pool)
        .await;

        self.find_user_by_subject(auth0_subject)
            .await
            .unwrap_or(User {
                auth0_subject: auth0_subject.to_owned(),
                display_name: None,
            })
    }

    async fn create_server(&self, name: String, owner_subject: String) -> Server {
        let (server_id, owner_subject_created) = sqlx::query_as::<_, (String, String)>(
            "WITH generated AS (
                SELECT CONCAT('srv-', nextval('server_id_seq')::TEXT) AS id
            ), inserted AS (
                INSERT INTO servers (id, name, owner_subject)
                SELECT generated.id, $1, $2
                FROM generated
                RETURNING id, owner_subject
            )
            INSERT INTO server_members (server_id, user_subject)
            SELECT id, owner_subject
            FROM inserted
            ON CONFLICT (server_id, user_subject) DO NOTHING
            RETURNING server_id, user_subject",
        )
        .bind(&name)
        .bind(&owner_subject)
        .fetch_one(&self.pool)
        .await
        .expect("create server in postgres to succeed");

        Server {
            id: server_id,
            name,
            owner_subject: owner_subject_created,
        }
    }

    async fn list_servers_for_user(&self, owner_subject: &str) -> Vec<Server> {
        sqlx::query_as::<_, (String, String, String)>(
            "SELECT s.id, s.name, s.owner_subject
             FROM servers s
             INNER JOIN server_members sm ON sm.server_id = s.id
             WHERE sm.user_subject = $1
             ORDER BY s.id ASC",
        )
        .bind(owner_subject)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(|(id, name, owner_subject)| Server {
            id,
            name,
            owner_subject,
        })
        .collect()
    }

    async fn add_server_member(
        &self,
        server_id: &str,
        actor_subject: &str,
        user_subject: String,
    ) -> MutationResult {
        let owner_subject =
            sqlx::query_scalar::<_, String>("SELECT owner_subject FROM servers WHERE id = $1")
                .bind(server_id)
                .fetch_optional(&self.pool)
                .await;

        let owner_subject = match owner_subject {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_subject) = owner_subject else {
            return MutationResult::NotFound;
        };

        if owner_subject != actor_subject {
            return MutationResult::Forbidden;
        }

        let inserted = sqlx::query(
            "INSERT INTO server_members (server_id, user_subject)
             VALUES ($1, $2)
             ON CONFLICT (server_id, user_subject) DO NOTHING",
        )
        .bind(server_id)
        .bind(user_subject)
        .execute(&self.pool)
        .await;

        match inserted {
            Ok(_) => MutationResult::Updated,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn delete_server(&self, server_id: &str, actor_subject: &str) -> MutationResult {
        let owner_subject =
            sqlx::query_scalar::<_, String>("SELECT owner_subject FROM servers WHERE id = $1")
                .bind(server_id)
                .fetch_optional(&self.pool)
                .await;

        let owner_subject = match owner_subject {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_subject) = owner_subject else {
            return MutationResult::NotFound;
        };

        if owner_subject != actor_subject {
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

    async fn list_server_members(&self, server_id: &str) -> Option<Vec<Membership>> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let members = sqlx::query_as::<_, (String, String)>(
            "SELECT server_id, user_subject
             FROM server_members
             WHERE server_id = $1
             ORDER BY user_subject ASC",
        )
        .bind(server_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(|(server_id, user_subject)| Membership {
            user_subject,
            server_id,
        })
        .collect();

        Some(members)
    }

    async fn create_channel(&self, server_id: &str, name: String) -> Option<Channel> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        sqlx::query_as::<_, (String, String, String)>(
            "WITH generated AS (
                SELECT CONCAT('chn-', nextval('channel_id_seq')::TEXT) AS id
            )
            INSERT INTO channels (id, server_id, name)
            SELECT generated.id, $1, $2
            FROM generated
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

    async fn delete_channel(&self, channel_id: &str, actor_subject: &str) -> MutationResult {
        let owner_subject = sqlx::query_scalar::<_, String>(
            "SELECT s.owner_subject
             FROM channels c
             INNER JOIN servers s ON s.id = c.server_id
             WHERE c.id = $1",
        )
        .bind(channel_id)
        .fetch_optional(&self.pool)
        .await;

        let owner_subject = match owner_subject {
            Ok(value) => value,
            Err(_) => return MutationResult::NotFound,
        };

        let Some(owner_subject) = owner_subject else {
            return MutationResult::NotFound;
        };

        if owner_subject != actor_subject {
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

    async fn list_channels_for_server(&self, server_id: &str) -> Option<Vec<Channel>> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let channels = sqlx::query_as::<_, (String, String, String)>(
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

    async fn join_voice_session(
        &self,
        channel_id: &str,
        participant_subject: String,
    ) -> Option<VoiceSession> {
        if !self.channel_exists(channel_id).await.ok()? {
            return None;
        }

        let inserted = sqlx::query(
            "INSERT INTO voice_sessions (channel_id, participant_subject)
             VALUES ($1, $2)
             ON CONFLICT (channel_id, participant_subject) DO NOTHING",
        )
        .bind(channel_id)
        .bind(&participant_subject)
        .execute(&self.pool)
        .await;

        if inserted.is_err() {
            return None;
        }

        Some(VoiceSession {
            channel_id: channel_id.to_owned(),
            participant_subject,
        })
    }

    async fn leave_voice_session(
        &self,
        channel_id: &str,
        participant_subject: &str,
    ) -> MutationResult {
        if !self.channel_exists(channel_id).await.unwrap_or(false) {
            return MutationResult::NotFound;
        }

        let deleted = sqlx::query(
            "DELETE FROM voice_sessions
             WHERE channel_id = $1 AND participant_subject = $2",
        )
        .bind(channel_id)
        .bind(participant_subject)
        .execute(&self.pool)
        .await;

        match deleted {
            Ok(result) if result.rows_affected() > 0 => MutationResult::Deleted,
            Ok(_) => MutationResult::NotFound,
            Err(_) => MutationResult::NotFound,
        }
    }

    async fn list_voice_sessions(&self, channel_id: &str) -> Option<Vec<VoiceSession>> {
        if !self.channel_exists(channel_id).await.ok()? {
            return None;
        }

        let sessions = sqlx::query_as::<_, (String, String)>(
            "SELECT channel_id, participant_subject
             FROM voice_sessions
             WHERE channel_id = $1
             ORDER BY participant_subject ASC",
        )
        .bind(channel_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(|(channel_id, participant_subject)| VoiceSession {
            channel_id,
            participant_subject,
        })
        .collect();

        Some(sessions)
    }
}

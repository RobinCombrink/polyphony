use async_trait::async_trait;
use backend_domain::{
    BlockRelationship, Channel, ChannelId, ChannelType, DirectMessage, DirectMessageThread,
    DirectMessageThreadId, DisplayName, ExternalReference, FriendRequest, FriendRequestId,
    FriendRequestState, Friendship, Membership, Message, MessageId, NotificationCategoryPreference,
    NotificationEventType, NotificationMuteState, Server, ServerId, User, UserId,
};
use sqlx::migrate::Migrator;
use sqlx::{
    FromRow, PgPool,
    postgres::{PgConnectOptions, PgPoolOptions},
};
use uuid::Uuid;

use crate::{
    BlockRepository, BlockUserResult, ChannelRepository, CreateMessageResult,
    DirectMessageRepository, FriendRepository, MessageRepository, MutationResult,
    NotificationRepository, OpenOrGetDirectMessageThreadResult, SendDirectMessageResult,
    SendFriendRequestResult, ServerRepository, UpdateFriendRequestResult, UserRepository,
};

#[cfg(target_family = "windows")]
static MIGRATOR: Migrator = sqlx::migrate!(".\\migrations");

#[cfg(target_family = "unix")]
static MIGRATOR: Migrator = sqlx::migrate!("./migrations");

#[derive(Debug, Clone)]
pub struct PostgresRepository {
    pool: PgPool,
}

#[derive(Debug, Clone, FromRow)]
struct FriendRequestRow {
    id: Uuid,
    requester_user_id: Uuid,
    addressee_user_id: Uuid,
    state: FriendRequestState,
}

impl From<FriendRequestRow> for FriendRequest {
    fn from(value: FriendRequestRow) -> Self {
        Self {
            id: value.id.into(),
            requester_user_id: value.requester_user_id.into(),
            addressee_user_id: value.addressee_user_id.into(),
            state: value.state,
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct FriendshipRow {
    id: Uuid,
    user_a_id: Uuid,
    user_b_id: Uuid,
}

impl From<FriendshipRow> for Friendship {
    fn from(value: FriendshipRow) -> Self {
        Self {
            id: value.id.into(),
            user_a_id: value.user_a_id.into(),
            user_b_id: value.user_b_id.into(),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct BlockRelationshipRow {
    id: Uuid,
    blocker_user_id: Uuid,
    blocked_user_id: Uuid,
    restored_friendship_id: Option<Uuid>,
}

impl From<BlockRelationshipRow> for BlockRelationship {
    fn from(value: BlockRelationshipRow) -> Self {
        Self {
            id: value.id.into(),
            blocker_user_id: value.blocker_user_id.into(),
            blocked_user_id: value.blocked_user_id.into(),
            restored_friendship_id: value.restored_friendship_id.map(Into::into),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct DirectMessageThreadRow {
    id: Uuid,
    participant_a_user_id: Uuid,
    participant_b_user_id: Uuid,
}

impl From<DirectMessageThreadRow> for DirectMessageThread {
    fn from(value: DirectMessageThreadRow) -> Self {
        Self {
            id: value.id.into(),
            participant_a_user_id: value.participant_a_user_id.into(),
            participant_b_user_id: value.participant_b_user_id.into(),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct DirectMessageRow {
    id: Uuid,
    thread_id: Uuid,
    author_user_id: Uuid,
    content: String,
}

impl From<DirectMessageRow> for DirectMessage {
    fn from(value: DirectMessageRow) -> Self {
        Self {
            id: value.id.into(),
            thread_id: value.thread_id.into(),
            author_user_id: value.author_user_id.into(),
            content: value.content,
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct DirectMessageThreadParticipantsRow {
    participant_a_user_id: Uuid,
    participant_b_user_id: Uuid,
}

#[derive(Debug, Clone, FromRow)]
struct MessageRow {
    id: Uuid,
    channel_id: Uuid,
    author_user_id: Uuid,
    content: String,
    mentioned_user_id: Option<Uuid>,
}

impl From<MessageRow> for Message {
    fn from(value: MessageRow) -> Self {
        if let Some(mentioned_user_id) = value.mentioned_user_id {
            return Message::new_mentioned(
                value.id.into(),
                value.channel_id.into(),
                value.author_user_id.into(),
                value.content,
                mentioned_user_id.into(),
            );
        }

        Message::new_regular(
            value.id.into(),
            value.channel_id.into(),
            value.author_user_id.into(),
            value.content,
        )
    }
}

#[derive(Debug, Clone, FromRow)]
struct UserRow {
    id: Uuid,
    external_reference: String,
    display_name: Option<String>,
}

impl From<UserRow> for User {
    fn from(value: UserRow) -> Self {
        Self {
            id: value.id.into(),
            external_reference: value.external_reference.into(),
            display_name: value.display_name.map(DisplayName::new),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct ServerRow {
    id: Uuid,
    name: String,
    owner_user_id: Uuid,
}

impl From<ServerRow> for Server {
    fn from(value: ServerRow) -> Self {
        Self {
            id: value.id.into(),
            name: value.name,
            owner_user_id: value.owner_user_id.into(),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct ServerMemberRow {
    server_id: Uuid,
    user_id: Uuid,
}

impl From<ServerMemberRow> for Membership {
    fn from(value: ServerMemberRow) -> Self {
        Self {
            user_id: value.user_id.into(),
            server_id: value.server_id.into(),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct ChannelRow {
    id: Uuid,
    server_id: Uuid,
    name: String,
    channel_type: String,
}

impl TryFrom<ChannelRow> for Channel {
    type Error = ();

    fn try_from(value: ChannelRow) -> Result<Self, Self::Error> {
        match value.channel_type.as_str() {
            "text" => Ok(Channel::new_text(
                value.id.into(),
                value.server_id.into(),
                value.name,
            )),
            "voice" => Ok(Channel::new_voice(
                value.id.into(),
                value.server_id.into(),
                value.name,
            )),
            _ => Err(()),
        }
    }
}

#[derive(Debug, Clone, FromRow)]
struct CreatedServerMembershipRow {
    server_id: Uuid,
    user_id: Uuid,
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

    async fn server_exists(&self, server_id: ServerId) -> Result<bool, sqlx::Error> {
        let server_id = Uuid::from(server_id);

        let row = sqlx::query_scalar::<_, i64>("SELECT COUNT(1) FROM servers WHERE id = $1")
            .bind(server_id)
            .fetch_one(&self.pool)
            .await?;

        Ok(row > 0)
    }

    async fn is_user_member_of_server(
        &self,
        server_id: ServerId,
        user_id: UserId,
    ) -> Result<Option<bool>, sqlx::Error> {
        let server_id_uuid = Uuid::from(server_id);
        let user_id_uuid = Uuid::from(user_id);

        if !self.server_exists(server_id).await? {
            return Ok(None);
        }

        let row = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1) FROM server_members WHERE server_id = $1 AND user_id = $2",
        )
        .bind(server_id_uuid)
        .bind(user_id_uuid)
        .fetch_one(&self.pool)
        .await?;

        Ok(Some(row > 0))
    }

    async fn is_user_member_of_channel(
        &self,
        channel_id: ChannelId,
        user_id: UserId,
    ) -> Result<Option<bool>, sqlx::Error> {
        let channel_id = Uuid::from(channel_id);

        let server_id =
            sqlx::query_scalar::<_, Uuid>("SELECT server_id FROM channels WHERE id = $1")
                .bind(channel_id)
                .fetch_optional(&self.pool)
                .await?;

        let Some(server_id) = server_id else {
            return Ok(None);
        };

        self.is_user_member_of_server(server_id.into(), user_id)
            .await
    }

    async fn effective_notification_category_for_channel(
        &self,
        user_id: UserId,
        server_id: ServerId,
        channel_id: ChannelId,
    ) -> NotificationCategoryPreference {
        let scoped_category = if let Some(channel_category) = self
            .channel_notification_category_for_user(user_id, channel_id)
            .await
        {
            channel_category
        } else if let Some(server_category) = self
            .server_notification_category_for_user(user_id, server_id)
            .await
        {
            server_category
        } else {
            self.global_channel_default_notification_category_for_user(user_id)
                .await
        };

        let global_category = self.global_notification_category_for_user(user_id).await;

        match (global_category, scoped_category) {
            (NotificationCategoryPreference::None, _) => NotificationCategoryPreference::None,
            (
                NotificationCategoryPreference::OnlyMentions,
                NotificationCategoryPreference::AllMessages,
            ) => NotificationCategoryPreference::OnlyMentions,
            _ => scoped_category,
        }
    }
}

#[async_trait]
impl MessageRepository for PostgresRepository {
    async fn create_message(
        &self,
        channel_id: ChannelId,
        author_user_id: UserId,
        content: String,
        mentioned_user_id: Option<UserId>,
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

        let channel_id = Uuid::from(channel_id);
        let author_user_id = Uuid::from(author_user_id);

        let mut transaction = match self.pool.begin().await {
            Ok(value) => value,
            Err(_) => return CreateMessageResult::NotFound,
        };

        let created_message = sqlx::query_as::<_, MessageRow>(
            "INSERT INTO messages (id, channel_id, author_user_id, content, mentioned_user_id)
             VALUES (gen_random_uuid(), $1, $2, $3, $4)
             RETURNING id, channel_id, author_user_id, content, mentioned_user_id",
        )
        .bind(channel_id)
        .bind(author_user_id)
        .bind(content)
        .bind(mentioned_user_id.map(Uuid::from))
        .fetch_one(&mut *transaction)
        .await;

        let message_row = match created_message {
            Ok(value) => value,
            Err(_) => return CreateMessageResult::NotFound,
        };

        let message_id = message_row.id;
        let message_channel_id = message_row.channel_id;
        let message_author_user_id = message_row.author_user_id;
        let mentioned_user_id = message_row.mentioned_user_id;

        let candidate_user_ids = sqlx::query_scalar::<_, Uuid>(
            "SELECT sm.user_id
             FROM server_members sm
             INNER JOIN channels c ON c.server_id = sm.server_id
             WHERE c.id = $1
               AND sm.user_id != $2",
        )
        .bind(channel_id)
        .bind(author_user_id)
        .fetch_all(&mut *transaction)
        .await
        .unwrap_or_default();

        let server_id = channel.server_id();
        let channel_id_typed: ChannelId = message_channel_id.into();
        let is_mentioned = mentioned_user_id.is_some();

        let mut notified_user_ids = Vec::new();
        for candidate_user_id in candidate_user_ids {
            let candidate_user_id_typed: UserId = candidate_user_id.into();

            if self
                .channel_temporary_mute_expires_at_epoch_seconds(
                    candidate_user_id_typed,
                    channel_id_typed,
                )
                .await
                .is_some()
            {
                continue;
            }

            if self
                .global_mute_state_for_user(candidate_user_id_typed)
                .await
                .is_muted()
            {
                continue;
            }

            if self
                .server_mute_state_for_user(candidate_user_id_typed, server_id)
                .await
                .is_muted()
            {
                continue;
            }

            let category = self
                .effective_notification_category_for_channel(
                    candidate_user_id_typed,
                    server_id,
                    channel_id_typed,
                )
                .await;

            let should_notify = match category {
                NotificationCategoryPreference::None => false,
                NotificationCategoryPreference::AllMessages => true,
                NotificationCategoryPreference::OnlyMentions => is_mentioned,
            };

            if should_notify {
                notified_user_ids.push(candidate_user_id);
            }
        }

        let event_type = if is_mentioned {
            NotificationEventType::Mentioned
        } else {
            NotificationEventType::UnreadMessage
        };

        let payload = serde_json::json!({
            "event_type": event_type.as_str(),
            "message_id": message_id,
            "channel_id": message_channel_id,
            "author_user_id": message_author_user_id,
        });

        for recipient_user_id in &notified_user_ids {
            let _ = sqlx::query(
                "INSERT INTO notification_outbox (
                    id,
                    event_type,
                    message_id,
                    channel_id,
                    recipient_user_id,
                    author_user_id,
                    payload
                 )
                 VALUES (gen_random_uuid(), $1, $2, $3, $4, $5, $6)
                 ON CONFLICT (event_type, message_id, recipient_user_id) DO NOTHING",
            )
            .bind(String::from(event_type))
            .bind(message_id)
            .bind(message_channel_id)
            .bind(recipient_user_id)
            .bind(message_author_user_id)
            .bind(payload.clone())
            .execute(&mut *transaction)
            .await;

            let _ = sqlx::query(
                "INSERT INTO notification_unread_counts (
                    user_id,
                    channel_id,
                    unread_count
                 )
                 VALUES ($1, $2, 1)
                 ON CONFLICT (user_id, channel_id)
                 DO UPDATE SET unread_count = notification_unread_counts.unread_count + 1,
                               updated_at = NOW()",
            )
            .bind(recipient_user_id)
            .bind(message_channel_id)
            .execute(&mut *transaction)
            .await;
        }

        if transaction.commit().await.is_err() {
            return CreateMessageResult::NotFound;
        }

        CreateMessageResult::Created {
            message: Message::from(message_row),
            notified_user_ids: notified_user_ids
                .into_iter()
                .map(Into::into)
                .collect::<Vec<_>>(),
        }
    }

    async fn update_message(
        &self,
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
        content: String,
    ) -> MutationResult {
        let channel_id = Uuid::from(channel_id);
        let message_id = Uuid::from(message_id);
        let author_user_id = Uuid::from(author_user_id);

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
        channel_id: ChannelId,
        message_id: MessageId,
        author_user_id: UserId,
    ) -> MutationResult {
        let channel_id = Uuid::from(channel_id);
        let message_id = Uuid::from(message_id);
        let author_user_id = Uuid::from(author_user_id);

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

    async fn list_messages(&self, channel_id: ChannelId) -> Vec<Message> {
        let channel_id = Uuid::from(channel_id);

        sqlx::query_as::<_, MessageRow>(
            "SELECT id, channel_id, author_user_id, content, mentioned_user_id
             FROM messages
             WHERE channel_id = $1
             ORDER BY created_order ASC",
        )
        .bind(channel_id)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(Message::from)
        .collect()
    }
}

#[async_trait]
impl UserRepository for PostgresRepository {
    async fn find_user_by_id(&self, user_id: UserId) -> Option<User> {
        let user_id = Uuid::from(user_id);

        sqlx::query_as::<_, UserRow>(
            "SELECT id, external_reference, display_name
             FROM users
             WHERE id = $1",
        )
        .bind(user_id)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .map(User::from)
    }

    async fn find_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> Option<User> {
        sqlx::query_as::<_, UserRow>(
            "SELECT id, external_reference, display_name
             FROM users
             WHERE external_reference = $1",
        )
        .bind(external_reference.as_str())
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .map(User::from)
    }

    async fn get_or_create_user_by_external_reference(
        &self,
        external_reference: &ExternalReference,
    ) -> User {
        let _ = sqlx::query(
            "INSERT INTO users (id, external_reference, display_name)
             VALUES (gen_random_uuid(), $1, NULL)
             ON CONFLICT (external_reference) DO NOTHING",
        )
        .bind(external_reference.as_str())
        .execute(&self.pool)
        .await;

        self.find_user_by_external_reference(external_reference)
            .await
            .unwrap_or(User {
                id: Uuid::new_v4().into(),
                external_reference: external_reference.clone(),
                display_name: None,
            })
    }

    async fn set_user_display_name(&self, user_id: UserId, display_name: String) -> Option<User> {
        let user_id_uuid = Uuid::from(user_id);

        let _ = sqlx::query(
            "UPDATE users
             SET display_name = $2
             WHERE id = $1",
        )
        .bind(user_id_uuid)
        .bind(display_name)
        .execute(&self.pool)
        .await;

        self.find_user_by_id(user_id).await
    }
}

#[async_trait]
impl NotificationRepository for PostgresRepository {
    async fn unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId) -> u64 {
        sqlx::query_scalar::<_, i64>(
            "SELECT unread_count
             FROM notification_unread_counts
             WHERE user_id = $1 AND channel_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| u64::try_from(value).ok())
        .unwrap_or(0)
    }

    async fn total_unread_count_for_user(&self, user_id: UserId) -> u64 {
        sqlx::query_scalar::<_, i64>(
            "SELECT COALESCE(SUM(unread_count), 0)::BIGINT
             FROM notification_unread_counts
             WHERE user_id = $1",
        )
        .bind(Uuid::from(user_id))
        .fetch_one(&self.pool)
        .await
        .ok()
        .and_then(|value| u64::try_from(value).ok())
        .unwrap_or(0)
    }

    async fn clear_unread_count_for_channel(&self, user_id: UserId, channel_id: ChannelId) {
        let _ = sqlx::query(
            "DELETE FROM notification_unread_counts
             WHERE user_id = $1
               AND channel_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .execute(&self.pool)
        .await;
    }

    async fn global_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference {
        sqlx::query_scalar::<_, String>(
            "SELECT COALESCE(notification_category, 'only_mentions')
             FROM notification_user_preferences
             WHERE user_id = $1",
        )
        .bind(Uuid::from(user_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| value.parse().ok())
        .unwrap_or_default()
    }

    async fn global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
    ) -> NotificationCategoryPreference {
        sqlx::query_scalar::<_, String>(
            "SELECT COALESCE(channel_default_category, 'only_mentions')
             FROM notification_user_preferences
             WHERE user_id = $1",
        )
        .bind(Uuid::from(user_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| value.parse().ok())
        .unwrap_or_default()
    }

    async fn server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> Option<NotificationCategoryPreference> {
        sqlx::query_scalar::<_, String>(
            "SELECT notification_category
             FROM notification_server_preferences
             WHERE user_id = $1
               AND server_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(server_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| value.parse().ok())
    }

    async fn channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<NotificationCategoryPreference> {
        sqlx::query_scalar::<_, String>(
            "SELECT notification_category
             FROM notification_channel_preferences
             WHERE user_id = $1
               AND channel_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| value.parse().ok())
    }

    async fn set_global_notification_category_for_user(
        &self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    ) {
        let _ = sqlx::query(
            "INSERT INTO notification_user_preferences (
                user_id,
                notification_category,
                channel_default_category,
                muted,
                updated_at
             )
             VALUES ($1, $2, 'only_mentions', $3, NOW())
             ON CONFLICT (user_id)
             DO UPDATE SET notification_category = EXCLUDED.notification_category,
                           muted = EXCLUDED.muted,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(category.as_str())
        .bind(category == NotificationCategoryPreference::None)
        .execute(&self.pool)
        .await;
    }

    async fn set_global_channel_default_notification_category_for_user(
        &self,
        user_id: UserId,
        category: NotificationCategoryPreference,
    ) {
        let _ = sqlx::query(
            "INSERT INTO notification_user_preferences (
                user_id,
                notification_category,
                channel_default_category,
                muted,
                updated_at
             )
             VALUES ($1, 'only_mentions', $2, FALSE, NOW())
             ON CONFLICT (user_id)
             DO UPDATE SET channel_default_category = EXCLUDED.channel_default_category,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(category.as_str())
        .execute(&self.pool)
        .await;
    }

    async fn set_server_notification_category_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
        category: NotificationCategoryPreference,
    ) {
        let _ = sqlx::query(
            "INSERT INTO notification_server_preferences (
                user_id,
                server_id,
                notification_category,
                updated_at
             )
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT (user_id, server_id)
             DO UPDATE SET notification_category = EXCLUDED.notification_category,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(server_id))
        .bind(category.as_str())
        .execute(&self.pool)
        .await;
    }

    async fn set_channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        category: NotificationCategoryPreference,
    ) {
        let _ = sqlx::query(
            "INSERT INTO notification_channel_preferences (
                user_id,
                channel_id,
                notification_category,
                updated_at
             )
             VALUES ($1, $2, $3, NOW())
             ON CONFLICT (user_id, channel_id)
             DO UPDATE SET notification_category = EXCLUDED.notification_category,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .bind(category.as_str())
        .execute(&self.pool)
        .await;
    }

    async fn clear_channel_notification_category_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) {
        let _ = sqlx::query(
            "DELETE FROM notification_channel_preferences
             WHERE user_id = $1
               AND channel_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .execute(&self.pool)
        .await;
    }

    async fn global_mute_state_for_user(&self, user_id: UserId) -> NotificationMuteState {
        let muted = sqlx::query_scalar::<_, bool>(
            "SELECT COALESCE(muted, FALSE)
             FROM notification_user_preferences
             WHERE user_id = $1",
        )
        .bind(Uuid::from(user_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .unwrap_or(false);

        NotificationMuteState::from_muted_flag(muted)
    }

    async fn server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
    ) -> NotificationMuteState {
        let muted = sqlx::query_scalar::<_, bool>(
            "SELECT COALESCE(muted, FALSE)
             FROM notification_server_preferences
             WHERE user_id = $1
               AND server_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(server_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .unwrap_or(false);

        NotificationMuteState::from_muted_flag(muted)
    }

    async fn set_global_mute_state_for_user(
        &self,
        user_id: UserId,
        mute_state: NotificationMuteState,
    ) {
        let _ = sqlx::query(
            "INSERT INTO notification_user_preferences (
                user_id,
                notification_category,
                channel_default_category,
                muted,
                updated_at
             )
             VALUES ($1, 'only_mentions', 'only_mentions', $2, NOW())
             ON CONFLICT (user_id)
             DO UPDATE SET muted = EXCLUDED.muted,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(mute_state.is_muted())
        .execute(&self.pool)
        .await;
    }

    async fn set_server_mute_state_for_user(
        &self,
        user_id: UserId,
        server_id: ServerId,
        mute_state: NotificationMuteState,
    ) {
        let _ = sqlx::query(
            "INSERT INTO notification_server_preferences (
                user_id,
                server_id,
                notification_category,
                muted,
                updated_at
             )
             VALUES ($1, $2, 'only_mentions', $3, NOW())
             ON CONFLICT (user_id, server_id)
             DO UPDATE SET muted = EXCLUDED.muted,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(server_id))
        .bind(mute_state.is_muted())
        .execute(&self.pool)
        .await;
    }

    async fn channel_temporary_mute_expires_at_epoch_seconds(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
    ) -> Option<u64> {
        sqlx::query_scalar::<_, i64>(
            "SELECT FLOOR(EXTRACT(EPOCH FROM muted_until))::BIGINT
             FROM notification_channel_mutes
             WHERE user_id = $1
               AND channel_id = $2
               AND muted_until > NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten()
        .and_then(|value| u64::try_from(value).ok())
    }

    async fn set_channel_temporary_mute_for_user(
        &self,
        user_id: UserId,
        channel_id: ChannelId,
        duration_minutes: u32,
    ) {
        let duration_minutes = i32::try_from(duration_minutes).unwrap_or(i32::MAX);
        let _ = sqlx::query(
            "INSERT INTO notification_channel_mutes (
                user_id,
                channel_id,
                muted_until,
                updated_at
             )
             VALUES ($1, $2, NOW() + make_interval(mins => $3), NOW())
             ON CONFLICT (user_id, channel_id)
             DO UPDATE SET muted_until = EXCLUDED.muted_until,
                           updated_at = NOW()",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .bind(duration_minutes)
        .execute(&self.pool)
        .await;
    }

    async fn clear_channel_temporary_mute_for_user(&self, user_id: UserId, channel_id: ChannelId) {
        let _ = sqlx::query(
            "UPDATE notification_channel_mutes
             SET muted_until = NOW() - INTERVAL '1 second',
                 updated_at = NOW()
             WHERE user_id = $1
               AND channel_id = $2",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(channel_id))
        .execute(&self.pool)
        .await;
    }

    async fn outbox_count_for_message_recipient(
        &self,
        message_id: MessageId,
        recipient_user_id: UserId,
    ) -> u64 {
        sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM notification_outbox
             WHERE message_id = $1
               AND recipient_user_id = $2",
        )
        .bind(Uuid::from(message_id))
        .bind(Uuid::from(recipient_user_id))
        .fetch_one(&self.pool)
        .await
        .ok()
        .and_then(|value| u64::try_from(value).ok())
        .unwrap_or(0)
    }

    async fn outbox_total_count_for_recipient(&self, recipient_user_id: UserId) -> u64 {
        sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM notification_outbox
             WHERE recipient_user_id = $1",
        )
        .bind(Uuid::from(recipient_user_id))
        .fetch_one(&self.pool)
        .await
        .ok()
        .and_then(|value| u64::try_from(value).ok())
        .unwrap_or(0)
    }
}

#[async_trait]
impl ServerRepository for PostgresRepository {
    async fn create_server(&self, name: String, owner_user_id: UserId) -> Server {
        let owner_user_id = Uuid::from(owner_user_id);

        let created_server_membership = sqlx::query_as::<_, CreatedServerMembershipRow>(
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
            id: created_server_membership.server_id.into(),
            name,
            owner_user_id: created_server_membership.user_id.into(),
        }
    }

    async fn list_servers_for_user(&self, user_id: UserId) -> Vec<Server> {
        let user_id = Uuid::from(user_id);

        sqlx::query_as::<_, ServerRow>(
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
        .map(Server::from)
        .collect()
    }

    async fn is_server_member(&self, server_id: ServerId, user_id: UserId) -> Option<bool> {
        self.is_user_member_of_server(server_id, user_id)
            .await
            .ok()?
    }

    async fn add_server_member(
        &self,
        server_id: ServerId,
        actor_user_id: UserId,
        user_id: UserId,
    ) -> MutationResult {
        let server_id = Uuid::from(server_id);
        let actor_user_id = Uuid::from(actor_user_id);
        let user_id = Uuid::from(user_id);

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

    async fn delete_server(&self, server_id: ServerId, actor_user_id: UserId) -> MutationResult {
        let server_id = Uuid::from(server_id);
        let actor_user_id = Uuid::from(actor_user_id);

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

    async fn list_server_members(&self, server_id: ServerId) -> Option<Vec<Membership>> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let server_id = Uuid::from(server_id);

        let members = sqlx::query_as::<_, ServerMemberRow>(
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
        .map(Membership::from)
        .collect();

        Some(members)
    }
}

#[async_trait]
impl ChannelRepository for PostgresRepository {
    async fn create_channel(
        &self,
        server_id: ServerId,
        name: String,
        channel_type: ChannelType,
    ) -> Option<Channel> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let server_id = Uuid::from(server_id);

        let channel_type_value = match channel_type {
            ChannelType::Text => "text",
            ChannelType::Voice => "voice",
        };

        sqlx::query_as::<_, ChannelRow>(
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
        .and_then(|row| Channel::try_from(row).ok())
    }

    async fn update_channel_name(
        &self,
        channel_id: ChannelId,
        actor_user_id: UserId,
        name: String,
    ) -> MutationResult {
        let channel_id = Uuid::from(channel_id);
        let actor_user_id = Uuid::from(actor_user_id);

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

    async fn delete_channel(&self, channel_id: ChannelId, actor_user_id: UserId) -> MutationResult {
        let channel_id = Uuid::from(channel_id);
        let actor_user_id = Uuid::from(actor_user_id);

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

    async fn list_channels_for_server(&self, server_id: ServerId) -> Option<Vec<Channel>> {
        if !self.server_exists(server_id).await.ok()? {
            return None;
        }

        let server_id = Uuid::from(server_id);

        let channels = sqlx::query_as::<_, ChannelRow>(
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
        .filter_map(|row| Channel::try_from(row).ok())
        .collect();

        Some(channels)
    }

    async fn find_channel_by_id(&self, channel_id: ChannelId) -> Option<Channel> {
        let channel_id = Uuid::from(channel_id);

        sqlx::query_as::<_, ChannelRow>(
            "SELECT id, server_id, name, channel_type
             FROM channels
             WHERE id = $1",
        )
        .bind(channel_id)
        .fetch_optional(&self.pool)
        .await
        .ok()?
        .and_then(|row| Channel::try_from(row).ok())
    }

    async fn is_channel_member(&self, channel_id: ChannelId, user_id: UserId) -> Option<bool> {
        self.is_user_member_of_channel(channel_id, user_id)
            .await
            .ok()?
    }
}

#[async_trait]
impl FriendRepository for PostgresRepository {
    async fn send_friend_request(
        &self,
        requester_user_id: UserId,
        addressee_user_id: UserId,
    ) -> SendFriendRequestResult {
        if requester_user_id == addressee_user_id {
            return SendFriendRequestResult::Forbidden;
        }

        let requester_user_id = Uuid::from(requester_user_id);
        let addressee_user_id = Uuid::from(addressee_user_id);

        let existing_users = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM users
             WHERE id = ANY($1)",
        )
        .bind(vec![requester_user_id, addressee_user_id])
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if existing_users < 2 {
            return SendFriendRequestResult::NotFound;
        }

        let blocked_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(requester_user_id)
        .bind(addressee_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if blocked_count > 0 {
            return SendFriendRequestResult::Blocked;
        }

        let friendships_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM friendships
             WHERE LEAST(user_a_id, user_b_id) = LEAST($1, $2)
               AND GREATEST(user_a_id, user_b_id) = GREATEST($1, $2)",
        )
        .bind(requester_user_id)
        .bind(addressee_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if friendships_count > 0 {
            return SendFriendRequestResult::AlreadyFriends;
        }

        let pending_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM friend_requests
                         WHERE state = $3
                             AND LEAST(requester_user_id, addressee_user_id) = LEAST($1, $2)
                             AND GREATEST(requester_user_id, addressee_user_id) = GREATEST($1, $2)",
        )
        .bind(requester_user_id)
        .bind(addressee_user_id)
        .bind(FriendRequestState::Pending)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if pending_count > 0 {
            return SendFriendRequestResult::AlreadyPending;
        }

        let inserted = sqlx::query_as::<_, FriendRequestRow>(
            "INSERT INTO friend_requests (id, requester_user_id, addressee_user_id, state)
               VALUES (gen_random_uuid(), $1, $2, $3)
             RETURNING id, requester_user_id, addressee_user_id, state",
        )
        .bind(requester_user_id)
        .bind(addressee_user_id)
        .bind(FriendRequestState::Pending)
        .fetch_one(&self.pool)
        .await;

        let Ok(friend_request_row) = inserted else {
            return SendFriendRequestResult::NotFound;
        };

        let friend_request = FriendRequest::from(friend_request_row);

        SendFriendRequestResult::Created(friend_request)
    }

    async fn set_friend_request_state(
        &self,
        actor_user_id: UserId,
        friend_request_id: FriendRequestId,
        state: FriendRequestState,
    ) -> UpdateFriendRequestResult {
        if state == FriendRequestState::Pending {
            return UpdateFriendRequestResult::InvalidState;
        }

        let actor_user_id = Uuid::from(actor_user_id);
        let friend_request_id = Uuid::from(friend_request_id);

        let existing = sqlx::query_as::<_, FriendRequestRow>(
            "SELECT id, requester_user_id, addressee_user_id, state
             FROM friend_requests
             WHERE id = $1",
        )
        .bind(friend_request_id)
        .fetch_optional(&self.pool)
        .await;

        let Ok(existing) = existing else {
            return UpdateFriendRequestResult::NotFound;
        };

        let Some(existing_friend_request_row) = existing else {
            return UpdateFriendRequestResult::NotFound;
        };

        let existing_friend_request = FriendRequest::from(existing_friend_request_row);

        let requester_user_id = Uuid::from(existing_friend_request.requester_user_id);
        let addressee_user_id = Uuid::from(existing_friend_request.addressee_user_id);
        let existing_state = existing_friend_request.state;

        if existing_state != FriendRequestState::Pending {
            return UpdateFriendRequestResult::InvalidState;
        }

        match state {
            FriendRequestState::Accepted | FriendRequestState::Declined => {
                if addressee_user_id != actor_user_id {
                    return UpdateFriendRequestResult::Forbidden;
                }
            }
            FriendRequestState::Cancelled => {
                if requester_user_id != actor_user_id {
                    return UpdateFriendRequestResult::Forbidden;
                }
            }
            FriendRequestState::Pending => return UpdateFriendRequestResult::InvalidState,
        }

        let updated = sqlx::query_as::<_, FriendRequestRow>(
            "UPDATE friend_requests
             SET state = $2,
                 updated_at = NOW()
             WHERE id = $1
             RETURNING id, requester_user_id, addressee_user_id, state",
        )
        .bind(friend_request_id)
        .bind(state)
        .fetch_one(&self.pool)
        .await;

        let Ok(updated_friend_request_row) = updated else {
            return UpdateFriendRequestResult::NotFound;
        };

        if state == FriendRequestState::Accepted {
            let _ = sqlx::query(
                "INSERT INTO friendships (id, user_a_id, user_b_id)
                 VALUES (gen_random_uuid(), LEAST($1, $2), GREATEST($1, $2))
                 ON CONFLICT DO NOTHING",
            )
            .bind(requester_user_id)
            .bind(addressee_user_id)
            .execute(&self.pool)
            .await;
        }

        let updated_friend_request = FriendRequest::from(updated_friend_request_row);

        UpdateFriendRequestResult::Updated(updated_friend_request)
    }

    async fn list_friendships_for_user(&self, user_id: UserId) -> Vec<Friendship> {
        sqlx::query_as::<_, FriendshipRow>(
            "SELECT id, user_a_id, user_b_id
             FROM friendships
             WHERE user_a_id = $1 OR user_b_id = $1
             ORDER BY created_at ASC",
        )
        .bind(Uuid::from(user_id))
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(Friendship::from)
        .collect::<Vec<_>>()
    }

    async fn list_pending_incoming_friend_requests(&self, user_id: UserId) -> Vec<FriendRequest> {
        sqlx::query_as::<_, FriendRequestRow>(
            "SELECT id, requester_user_id, addressee_user_id, state
             FROM friend_requests
             WHERE addressee_user_id = $1
                             AND state = $2
             ORDER BY created_at ASC",
        )
        .bind(Uuid::from(user_id))
        .bind(FriendRequestState::Pending)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(FriendRequest::from)
        .collect::<Vec<_>>()
    }

    async fn list_pending_outgoing_friend_requests(&self, user_id: UserId) -> Vec<FriendRequest> {
        sqlx::query_as::<_, FriendRequestRow>(
            "SELECT id, requester_user_id, addressee_user_id, state
             FROM friend_requests
             WHERE requester_user_id = $1
                             AND state = $2
             ORDER BY created_at ASC",
        )
        .bind(Uuid::from(user_id))
        .bind(FriendRequestState::Pending)
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(FriendRequest::from)
        .collect::<Vec<_>>()
    }

    async fn are_friends(&self, user_id: UserId, other_user_id: UserId) -> bool {
        let count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM friendships
             WHERE LEAST(user_a_id, user_b_id) = LEAST($1, $2)
               AND GREATEST(user_a_id, user_b_id) = GREATEST($1, $2)",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(other_user_id))
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        count > 0
    }
}

#[async_trait]
impl BlockRepository for PostgresRepository {
    async fn block_user(
        &self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> BlockUserResult {
        if blocker_user_id == blocked_user_id {
            return BlockUserResult::Forbidden;
        }

        let blocker_user_id = Uuid::from(blocker_user_id);
        let blocked_user_id = Uuid::from(blocked_user_id);

        let existing_users = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM users
             WHERE id = ANY($1)",
        )
        .bind(vec![blocker_user_id, blocked_user_id])
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if existing_users < 2 {
            return BlockUserResult::NotFound;
        }

        let already_blocked = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(blocker_user_id)
        .bind(blocked_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if already_blocked > 0 {
            return BlockUserResult::AlreadyBlocked;
        }

        let restored_friendship_id = sqlx::query_scalar::<_, Uuid>(
            "SELECT id
             FROM friendships
             WHERE LEAST(user_a_id, user_b_id) = LEAST($1, $2)
               AND GREATEST(user_a_id, user_b_id) = GREATEST($1, $2)",
        )
        .bind(blocker_user_id)
        .bind(blocked_user_id)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten();

        if let Some(friendship_id) = restored_friendship_id {
            let _ = sqlx::query("DELETE FROM friendships WHERE id = $1")
                .bind(friendship_id)
                .execute(&self.pool)
                .await;
        }

        let inserted = sqlx::query_as::<_, BlockRelationshipRow>(
            "INSERT INTO blocks (id, blocker_user_id, blocked_user_id, restored_friendship_id)
             VALUES (gen_random_uuid(), $1, $2, $3)
             RETURNING id, blocker_user_id, blocked_user_id, restored_friendship_id",
        )
        .bind(blocker_user_id)
        .bind(blocked_user_id)
        .bind(restored_friendship_id)
        .fetch_one(&self.pool)
        .await;

        let Ok(block_relationship_row) = inserted else {
            return BlockUserResult::NotFound;
        };

        BlockUserResult::Created(BlockRelationship::from(block_relationship_row))
    }

    async fn unblock_user(
        &self,
        blocker_user_id: UserId,
        blocked_user_id: UserId,
    ) -> MutationResult {
        let blocker_user_id = Uuid::from(blocker_user_id);
        let blocked_user_id = Uuid::from(blocked_user_id);

        let block_record = sqlx::query_as::<_, BlockRelationshipRow>(
            "SELECT id, blocker_user_id, blocked_user_id, restored_friendship_id
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(blocker_user_id)
        .bind(blocked_user_id)
        .fetch_optional(&self.pool)
        .await;

        let Ok(block_record) = block_record else {
            return MutationResult::NotFound;
        };

        let Some(block_relationship_row) = block_record else {
            return MutationResult::NotFound;
        };

        let block_relationship = BlockRelationship::from(block_relationship_row);

        if Uuid::from(block_relationship.blocker_user_id) != blocker_user_id {
            return MutationResult::Forbidden;
        }

        let deleted = sqlx::query("DELETE FROM blocks WHERE id = $1")
            .bind(Uuid::from(block_relationship.id))
            .execute(&self.pool)
            .await;

        let Ok(delete_result) = deleted else {
            return MutationResult::NotFound;
        };

        if delete_result.rows_affected() == 0 {
            return MutationResult::NotFound;
        }

        if let Some(friendship_id) = block_relationship.restored_friendship_id {
            let _ = sqlx::query(
                "INSERT INTO friendships (id, user_a_id, user_b_id)
                 VALUES ($1, LEAST($2, $3), GREATEST($2, $3))
                 ON CONFLICT DO NOTHING",
            )
            .bind(Uuid::from(friendship_id))
            .bind(Uuid::from(block_relationship.blocker_user_id))
            .bind(Uuid::from(block_relationship.blocked_user_id))
            .execute(&self.pool)
            .await;
        }

        MutationResult::Deleted
    }

    async fn list_blocked_users(&self, blocker_user_id: UserId) -> Vec<BlockRelationship> {
        sqlx::query_as::<_, BlockRelationshipRow>(
            "SELECT id, blocker_user_id, blocked_user_id, restored_friendship_id
             FROM blocks
             WHERE blocker_user_id = $1
             ORDER BY created_at ASC",
        )
        .bind(Uuid::from(blocker_user_id))
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(BlockRelationship::from)
        .collect::<Vec<_>>()
    }

    async fn users_are_blocked(&self, user_id: UserId, other_user_id: UserId) -> bool {
        let count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(Uuid::from(user_id))
        .bind(Uuid::from(other_user_id))
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        count > 0
    }
}

#[async_trait]
impl DirectMessageRepository for PostgresRepository {
    async fn open_or_get_direct_message_thread(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
    ) -> OpenOrGetDirectMessageThreadResult {
        if actor_user_id == other_user_id {
            return OpenOrGetDirectMessageThreadResult::Forbidden;
        }

        let actor_user_id = Uuid::from(actor_user_id);
        let other_user_id = Uuid::from(other_user_id);

        let existing_users = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM users
             WHERE id = ANY($1)",
        )
        .bind(vec![actor_user_id, other_user_id])
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if existing_users < 2 {
            return OpenOrGetDirectMessageThreadResult::NotFound;
        }

        let blocked_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if blocked_count > 0 {
            return OpenOrGetDirectMessageThreadResult::Blocked;
        }

        let friends_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM friendships
             WHERE LEAST(user_a_id, user_b_id) = LEAST($1, $2)
               AND GREATEST(user_a_id, user_b_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if friends_count == 0 {
            return OpenOrGetDirectMessageThreadResult::Forbidden;
        }

        let existing_thread = sqlx::query_as::<_, DirectMessageThreadRow>(
            "SELECT id, participant_a_user_id, participant_b_user_id
             FROM direct_message_threads
             WHERE LEAST(participant_a_user_id, participant_b_user_id) = LEAST($1, $2)
               AND GREATEST(participant_a_user_id, participant_b_user_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_optional(&self.pool)
        .await;

        let Ok(existing_thread) = existing_thread else {
            return OpenOrGetDirectMessageThreadResult::NotFound;
        };

        if let Some(direct_message_thread_row) = existing_thread {
            return OpenOrGetDirectMessageThreadResult::Opened(DirectMessageThread::from(
                direct_message_thread_row,
            ));
        }

        let inserted = sqlx::query_as::<_, DirectMessageThreadRow>(
            "INSERT INTO direct_message_threads (id, participant_a_user_id, participant_b_user_id)
             VALUES (gen_random_uuid(), LEAST($1, $2), GREATEST($1, $2))
             RETURNING id, participant_a_user_id, participant_b_user_id",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await;

        let Ok(direct_message_thread_row) = inserted else {
            return OpenOrGetDirectMessageThreadResult::NotFound;
        };

        OpenOrGetDirectMessageThreadResult::Opened(DirectMessageThread::from(
            direct_message_thread_row,
        ))
    }

    async fn list_direct_message_threads_for_user(
        &self,
        user_id: UserId,
    ) -> Vec<DirectMessageThread> {
        sqlx::query_as::<_, DirectMessageThreadRow>(
            "SELECT id, participant_a_user_id, participant_b_user_id
             FROM direct_message_threads
             WHERE participant_a_user_id = $1 OR participant_b_user_id = $1
             ORDER BY created_at ASC",
        )
        .bind(Uuid::from(user_id))
        .fetch_all(&self.pool)
        .await
        .unwrap_or_default()
        .into_iter()
        .map(DirectMessageThread::from)
        .collect::<Vec<_>>()
    }

    async fn send_direct_message(
        &self,
        actor_user_id: UserId,
        thread_id: DirectMessageThreadId,
        content: String,
    ) -> SendDirectMessageResult {
        let actor_user_id = Uuid::from(actor_user_id);
        let thread_id = Uuid::from(thread_id);

        let thread = sqlx::query_as::<_, DirectMessageThreadRow>(
            "SELECT id, participant_a_user_id, participant_b_user_id
             FROM direct_message_threads
             WHERE id = $1",
        )
        .bind(thread_id)
        .fetch_optional(&self.pool)
        .await;

        let Ok(thread) = thread else {
            return SendDirectMessageResult::NotFound;
        };

        let Some(direct_message_thread_row) = thread else {
            return SendDirectMessageResult::NotFound;
        };

        let direct_message_thread = DirectMessageThread::from(direct_message_thread_row);
        let thread_id = Uuid::from(direct_message_thread.id);
        let participant_a_user_id = Uuid::from(direct_message_thread.participant_a_user_id);
        let participant_b_user_id = Uuid::from(direct_message_thread.participant_b_user_id);

        if actor_user_id != participant_a_user_id && actor_user_id != participant_b_user_id {
            return SendDirectMessageResult::Forbidden;
        }

        let other_user_id = if actor_user_id == participant_a_user_id {
            participant_b_user_id
        } else {
            participant_a_user_id
        };

        let blocked_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if blocked_count > 0 {
            return SendDirectMessageResult::Blocked;
        }

        let friends_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM friendships
             WHERE LEAST(user_a_id, user_b_id) = LEAST($1, $2)
               AND GREATEST(user_a_id, user_b_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if friends_count == 0 {
            return SendDirectMessageResult::Forbidden;
        }

        let inserted = sqlx::query_as::<_, DirectMessageRow>(
            "INSERT INTO direct_messages (id, thread_id, author_user_id, content)
             VALUES (gen_random_uuid(), $1, $2, $3)
             RETURNING id, thread_id, author_user_id, content",
        )
        .bind(thread_id)
        .bind(actor_user_id)
        .bind(content)
        .fetch_one(&self.pool)
        .await;

        let Ok(direct_message_row) = inserted else {
            return SendDirectMessageResult::NotFound;
        };

        SendDirectMessageResult::Created(DirectMessage::from(direct_message_row))
    }

    async fn list_direct_messages(
        &self,
        actor_user_id: UserId,
        thread_id: DirectMessageThreadId,
    ) -> Option<Vec<DirectMessage>> {
        let actor_user_id = Uuid::from(actor_user_id);
        let thread_id = Uuid::from(thread_id);

        let thread = sqlx::query_as::<_, DirectMessageThreadParticipantsRow>(
            "SELECT participant_a_user_id, participant_b_user_id
             FROM direct_message_threads
             WHERE id = $1",
        )
        .bind(thread_id)
        .fetch_optional(&self.pool)
        .await
        .ok()??;

        if actor_user_id != thread.participant_a_user_id
            && actor_user_id != thread.participant_b_user_id
        {
            return None;
        }

        let messages = sqlx::query_as::<_, DirectMessageRow>(
            "SELECT id, thread_id, author_user_id, content
             FROM direct_messages
             WHERE thread_id = $1
             ORDER BY created_at ASC",
        )
        .bind(thread_id)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(DirectMessage::from)
        .collect::<Vec<_>>();

        Some(messages)
    }

    async fn search_direct_messages_for_person(
        &self,
        actor_user_id: UserId,
        other_user_id: UserId,
        query: &str,
    ) -> Option<Vec<DirectMessage>> {
        let actor_user_id = Uuid::from(actor_user_id);
        let other_user_id = Uuid::from(other_user_id);

        let blocked_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM blocks
             WHERE LEAST(blocker_user_id, blocked_user_id) = LEAST($1, $2)
               AND GREATEST(blocker_user_id, blocked_user_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if blocked_count > 0 {
            return None;
        }

        let friends_count = sqlx::query_scalar::<_, i64>(
            "SELECT COUNT(1)
             FROM friendships
             WHERE LEAST(user_a_id, user_b_id) = LEAST($1, $2)
               AND GREATEST(user_a_id, user_b_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_one(&self.pool)
        .await
        .unwrap_or(0);

        if friends_count == 0 {
            return None;
        }

        let thread_id = sqlx::query_scalar::<_, Uuid>(
            "SELECT id
             FROM direct_message_threads
             WHERE LEAST(participant_a_user_id, participant_b_user_id) = LEAST($1, $2)
               AND GREATEST(participant_a_user_id, participant_b_user_id) = GREATEST($1, $2)",
        )
        .bind(actor_user_id)
        .bind(other_user_id)
        .fetch_optional(&self.pool)
        .await
        .ok()
        .flatten();

        let Some(thread_id) = thread_id else {
            return Some(Vec::new());
        };

        let matches = sqlx::query_as::<_, DirectMessageRow>(
            "SELECT id, thread_id, author_user_id, content
             FROM direct_messages
             WHERE thread_id = $1
               AND content ILIKE CONCAT('%', $2, '%')
             ORDER BY created_at ASC",
        )
        .bind(thread_id)
        .bind(query)
        .fetch_all(&self.pool)
        .await
        .ok()?
        .into_iter()
        .map(DirectMessage::from)
        .collect::<Vec<_>>();

        Some(matches)
    }
}

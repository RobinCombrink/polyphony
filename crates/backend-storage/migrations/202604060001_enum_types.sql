-- Create Postgres enum types for channel_type, notification_category_preference, and notification_event_type.
-- These replace TEXT columns with CHECK constraints / manual parsing.

-- 1. channel_type enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'channel_type') THEN
        CREATE TYPE channel_type AS ENUM ('text', 'voice');
    END IF;
END $$;

ALTER TABLE channels
    DROP CONSTRAINT IF EXISTS channels_channel_type_check;

ALTER TABLE channels
    ALTER COLUMN channel_type DROP DEFAULT;

ALTER TABLE channels
    ALTER COLUMN channel_type TYPE channel_type USING channel_type::channel_type;

ALTER TABLE channels
    ALTER COLUMN channel_type SET DEFAULT 'text'::channel_type;

-- 2. notification_category_preference enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_category_preference') THEN
        CREATE TYPE notification_category_preference AS ENUM ('all_messages', 'only_mentions', 'none');
    END IF;
END $$;

ALTER TABLE notification_user_preferences
    ALTER COLUMN notification_category DROP DEFAULT,
    ALTER COLUMN channel_default_category DROP DEFAULT;

ALTER TABLE notification_user_preferences
    ALTER COLUMN notification_category TYPE notification_category_preference
        USING notification_category::notification_category_preference,
    ALTER COLUMN channel_default_category TYPE notification_category_preference
        USING channel_default_category::notification_category_preference;

ALTER TABLE notification_user_preferences
    ALTER COLUMN notification_category SET DEFAULT 'only_mentions'::notification_category_preference,
    ALTER COLUMN channel_default_category SET DEFAULT 'only_mentions'::notification_category_preference;

ALTER TABLE notification_server_preferences
    ALTER COLUMN notification_category DROP DEFAULT;

ALTER TABLE notification_server_preferences
    ALTER COLUMN notification_category TYPE notification_category_preference
        USING notification_category::notification_category_preference;

ALTER TABLE notification_server_preferences
    ALTER COLUMN notification_category SET DEFAULT 'only_mentions'::notification_category_preference;

ALTER TABLE notification_channel_preferences
    ALTER COLUMN notification_category DROP DEFAULT;

ALTER TABLE notification_channel_preferences
    ALTER COLUMN notification_category TYPE notification_category_preference
        USING notification_category::notification_category_preference;

ALTER TABLE notification_channel_preferences
    ALTER COLUMN notification_category SET DEFAULT 'only_mentions'::notification_category_preference;

-- 3. notification_event_type enum
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'notification_event_type') THEN
        CREATE TYPE notification_event_type AS ENUM ('unread_message', 'mentioned');
    END IF;
END $$;

ALTER TABLE notification_outbox
    ALTER COLUMN event_type TYPE notification_event_type
        USING event_type::notification_event_type;

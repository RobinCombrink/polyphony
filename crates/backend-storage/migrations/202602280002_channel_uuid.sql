CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE SEQUENCE IF NOT EXISTS message_id_seq;

DO $$
DECLARE
    channels_id_is_text BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'channels'
          AND column_name = 'id'
          AND data_type = 'text'
    ) INTO channels_id_is_text;

    IF channels_id_is_text THEN
        ALTER TABLE channels ADD COLUMN IF NOT EXISTS id_uuid UUID;
        UPDATE channels
        SET id_uuid = COALESCE(id_uuid, gen_random_uuid());

        ALTER TABLE messages ADD COLUMN IF NOT EXISTS channel_id_uuid UUID;
        UPDATE messages m
        SET channel_id_uuid = c.id_uuid
        FROM channels c
        WHERE m.channel_id = c.id;

        ALTER TABLE voice_sessions ADD COLUMN IF NOT EXISTS channel_id_uuid UUID;
        UPDATE voice_sessions vs
        SET channel_id_uuid = c.id_uuid
        FROM channels c
        WHERE vs.channel_id = c.id;

        ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_channel_id_fkey;
        ALTER TABLE voice_sessions DROP CONSTRAINT IF EXISTS voice_sessions_channel_id_fkey;
        ALTER TABLE voice_sessions DROP CONSTRAINT IF EXISTS voice_sessions_pkey;
        ALTER TABLE channels DROP CONSTRAINT IF EXISTS channels_pkey;

        ALTER TABLE channels DROP COLUMN id;
        ALTER TABLE channels RENAME COLUMN id_uuid TO id;
        ALTER TABLE channels ALTER COLUMN id SET NOT NULL;
        ALTER TABLE channels ADD PRIMARY KEY (id);

        ALTER TABLE messages DROP COLUMN channel_id;
        ALTER TABLE messages RENAME COLUMN channel_id_uuid TO channel_id;
        ALTER TABLE messages ALTER COLUMN channel_id SET NOT NULL;
        ALTER TABLE messages
            ADD CONSTRAINT messages_channel_id_fkey
            FOREIGN KEY (channel_id)
            REFERENCES channels(id)
            ON DELETE CASCADE;

        ALTER TABLE voice_sessions DROP COLUMN channel_id;
        ALTER TABLE voice_sessions RENAME COLUMN channel_id_uuid TO channel_id;
        ALTER TABLE voice_sessions ALTER COLUMN channel_id SET NOT NULL;
        ALTER TABLE voice_sessions ADD PRIMARY KEY (channel_id, participant_subject);
        ALTER TABLE voice_sessions
            ADD CONSTRAINT voice_sessions_channel_id_fkey
            FOREIGN KEY (channel_id)
            REFERENCES channels(id)
            ON DELETE CASCADE;
    END IF;
END $$;

DROP SEQUENCE IF EXISTS channel_id_seq;

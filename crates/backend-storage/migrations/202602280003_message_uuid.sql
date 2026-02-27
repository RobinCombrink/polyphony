CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    messages_id_is_text BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'messages'
          AND column_name = 'id'
          AND data_type = 'text'
    ) INTO messages_id_is_text;

    IF messages_id_is_text THEN
        ALTER TABLE messages ADD COLUMN IF NOT EXISTS id_uuid UUID;
        UPDATE messages
        SET id_uuid = COALESCE(id_uuid, gen_random_uuid());

        ALTER TABLE messages DROP CONSTRAINT IF EXISTS messages_pkey;
        ALTER TABLE messages DROP COLUMN id;
        ALTER TABLE messages RENAME COLUMN id_uuid TO id;
        ALTER TABLE messages ALTER COLUMN id SET NOT NULL;
        ALTER TABLE messages ADD PRIMARY KEY (id);
    END IF;
END $$;

DROP SEQUENCE IF EXISTS message_id_seq;

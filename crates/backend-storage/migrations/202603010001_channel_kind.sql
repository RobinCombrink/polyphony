ALTER TABLE channels
    ADD COLUMN IF NOT EXISTS channel_type TEXT;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'channels'
          AND column_name = 'channel_kind'
    ) THEN
        UPDATE channels
        SET channel_type = COALESCE(channel_type, channel_kind, 'text')
        WHERE channel_type IS NULL;
    ELSE
        UPDATE channels
        SET channel_type = COALESCE(channel_type, 'text')
        WHERE channel_type IS NULL;
    END IF;
END $$;

ALTER TABLE channels
    ALTER COLUMN channel_type SET DEFAULT 'text';

ALTER TABLE channels
    ALTER COLUMN channel_type SET NOT NULL;

ALTER TABLE channels
    DROP CONSTRAINT IF EXISTS channels_channel_kind_check;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'channels_channel_type_check'
    ) THEN
        ALTER TABLE channels
            ADD CONSTRAINT channels_channel_type_check
            CHECK (channel_type IN ('text', 'voice'));
    END IF;
END $$;

ALTER TABLE channels
    DROP COLUMN IF EXISTS channel_kind;

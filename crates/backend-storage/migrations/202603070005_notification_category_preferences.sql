ALTER TABLE notification_user_preferences
    ADD COLUMN IF NOT EXISTS notification_category TEXT NOT NULL DEFAULT 'only_mentions',
    ADD COLUMN IF NOT EXISTS channel_default_category TEXT NOT NULL DEFAULT 'only_mentions';

ALTER TABLE notification_server_preferences
    ADD COLUMN IF NOT EXISTS notification_category TEXT NOT NULL DEFAULT 'only_mentions';

CREATE TABLE IF NOT EXISTS notification_channel_preferences (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    notification_category TEXT NOT NULL DEFAULT 'only_mentions',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, channel_id)
);

UPDATE notification_user_preferences
SET notification_category = CASE WHEN muted THEN 'none' ELSE 'only_mentions' END,
    channel_default_category = 'only_mentions'
WHERE notification_category IS DISTINCT FROM CASE WHEN muted THEN 'none' ELSE 'only_mentions' END
   OR channel_default_category IS DISTINCT FROM 'only_mentions';

UPDATE notification_server_preferences
SET notification_category = CASE WHEN muted THEN 'none' ELSE 'only_mentions' END
WHERE notification_category IS DISTINCT FROM CASE WHEN muted THEN 'none' ELSE 'only_mentions' END;

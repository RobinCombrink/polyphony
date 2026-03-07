ALTER TABLE messages
ADD COLUMN IF NOT EXISTS mentioned_user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS messages_mentioned_user_id_idx
    ON messages (mentioned_user_id)
    WHERE mentioned_user_id IS NOT NULL;

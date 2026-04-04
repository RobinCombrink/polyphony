CREATE TABLE IF NOT EXISTS pinned_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    pinned_by_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    date_created TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (server_id, message_id)
);

CREATE INDEX IF NOT EXISTS pinned_messages_server_id_idx
    ON pinned_messages (server_id);

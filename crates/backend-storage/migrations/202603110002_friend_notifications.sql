DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'friend_notification_event_type') THEN
        CREATE TYPE friend_notification_event_type AS ENUM (
            'friend_request_received',
            'friend_request_accepted'
        );
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS friend_notification_outbox (
    id UUID PRIMARY KEY,
    event_type friend_notification_event_type NOT NULL,
    friend_request_id UUID NOT NULL REFERENCES friend_requests (id) ON DELETE CASCADE,
    recipient_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    actor_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (event_type, friend_request_id, recipient_user_id)
);

CREATE INDEX IF NOT EXISTS friend_notification_outbox_recipient_idx
    ON friend_notification_outbox (recipient_user_id, created_at DESC);

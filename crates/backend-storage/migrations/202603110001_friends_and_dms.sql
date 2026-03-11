DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'friend_request_state') THEN
        CREATE TYPE friend_request_state AS ENUM ('pending', 'accepted', 'declined', 'cancelled');
    END IF;
END
$$;

CREATE TABLE IF NOT EXISTS friend_requests (
    id UUID PRIMARY KEY,
    requester_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    addressee_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    state friend_request_state NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT friend_requests_users_distinct CHECK (requester_user_id <> addressee_user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS friend_requests_unique_pending_pair_idx
    ON friend_requests (requester_user_id, addressee_user_id)
    WHERE state = 'pending';

CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY,
    user_a_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    user_b_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT friendships_users_distinct CHECK (user_a_id <> user_b_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS friendships_unique_pair_idx
    ON friendships (LEAST(user_a_id, user_b_id), GREATEST(user_a_id, user_b_id));

CREATE TABLE IF NOT EXISTS blocks (
    id UUID PRIMARY KEY,
    blocker_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    blocked_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    restored_friendship_id UUID NULL REFERENCES friendships (id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT blocks_users_distinct CHECK (blocker_user_id <> blocked_user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS blocks_unique_pair_idx
    ON blocks (LEAST(blocker_user_id, blocked_user_id), GREATEST(blocker_user_id, blocked_user_id));

CREATE TABLE IF NOT EXISTS direct_message_threads (
    id UUID PRIMARY KEY,
    participant_a_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    participant_b_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT direct_message_threads_participants_distinct CHECK (participant_a_user_id <> participant_b_user_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS direct_message_threads_unique_pair_idx
    ON direct_message_threads (LEAST(participant_a_user_id, participant_b_user_id), GREATEST(participant_a_user_id, participant_b_user_id));

CREATE TABLE IF NOT EXISTS direct_messages (
    id UUID PRIMARY KEY,
    thread_id UUID NOT NULL REFERENCES direct_message_threads (id) ON DELETE CASCADE,
    author_user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS direct_messages_thread_created_at_idx
    ON direct_messages (thread_id, created_at DESC);

CREATE INDEX IF NOT EXISTS direct_messages_content_search_idx
    ON direct_messages USING GIN (to_tsvector('simple', content));

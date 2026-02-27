CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
    auth0_subject TEXT PRIMARY KEY,
    display_name TEXT NULL
);

CREATE TABLE IF NOT EXISTS servers (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    owner_subject TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS server_members (
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    user_subject TEXT NOT NULL,
    PRIMARY KEY (server_id, user_subject)
);

CREATE TABLE IF NOT EXISTS channels (
    id TEXT PRIMARY KEY,
    server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    author_subject TEXT NOT NULL,
    content TEXT NOT NULL,
    created_order BIGSERIAL NOT NULL
);

CREATE TABLE IF NOT EXISTS voice_sessions (
    channel_id TEXT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    participant_subject TEXT NOT NULL,
    PRIMARY KEY (channel_id, participant_subject)
);

DO $$
DECLARE
    servers_id_is_text BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'servers'
          AND column_name = 'id'
          AND data_type = 'text'
    ) INTO servers_id_is_text;

    IF servers_id_is_text THEN
        ALTER TABLE servers ADD COLUMN IF NOT EXISTS id_uuid UUID;
        UPDATE servers
        SET id_uuid = COALESCE(id_uuid, gen_random_uuid());

        ALTER TABLE server_members ADD COLUMN IF NOT EXISTS server_id_uuid UUID;
        UPDATE server_members sm
        SET server_id_uuid = s.id_uuid
        FROM servers s
        WHERE sm.server_id = s.id;

        ALTER TABLE channels ADD COLUMN IF NOT EXISTS server_id_uuid UUID;
        UPDATE channels c
        SET server_id_uuid = s.id_uuid
        FROM servers s
        WHERE c.server_id = s.id;

        ALTER TABLE server_members DROP CONSTRAINT IF EXISTS server_members_server_id_fkey;
        ALTER TABLE channels DROP CONSTRAINT IF EXISTS channels_server_id_fkey;
        ALTER TABLE server_members DROP CONSTRAINT IF EXISTS server_members_pkey;
        ALTER TABLE servers DROP CONSTRAINT IF EXISTS servers_pkey;

        ALTER TABLE servers DROP COLUMN id;
        ALTER TABLE servers RENAME COLUMN id_uuid TO id;
        ALTER TABLE servers ALTER COLUMN id SET NOT NULL;
        ALTER TABLE servers ADD PRIMARY KEY (id);

        ALTER TABLE server_members DROP COLUMN server_id;
        ALTER TABLE server_members RENAME COLUMN server_id_uuid TO server_id;
        ALTER TABLE server_members ALTER COLUMN server_id SET NOT NULL;
        ALTER TABLE server_members ADD PRIMARY KEY (server_id, user_subject);
        ALTER TABLE server_members
            ADD CONSTRAINT server_members_server_id_fkey
            FOREIGN KEY (server_id)
            REFERENCES servers(id)
            ON DELETE CASCADE;

        ALTER TABLE channels DROP COLUMN server_id;
        ALTER TABLE channels RENAME COLUMN server_id_uuid TO server_id;
        ALTER TABLE channels ALTER COLUMN server_id SET NOT NULL;
        ALTER TABLE channels
            ADD CONSTRAINT channels_server_id_fkey
            FOREIGN KEY (server_id)
            REFERENCES servers(id)
            ON DELETE CASCADE;
    END IF;
END $$;

DROP SEQUENCE IF EXISTS server_id_seq;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE users ADD COLUMN IF NOT EXISTS id UUID;
ALTER TABLE users ADD COLUMN IF NOT EXISTS external_reference TEXT;

UPDATE users
SET id = COALESCE(id, gen_random_uuid());

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND column_name = 'auth0_subject'
    ) THEN
        UPDATE users
        SET external_reference = COALESCE(external_reference, auth0_subject)
        WHERE external_reference IS NULL;
    END IF;
END $$;

INSERT INTO users (id, external_reference, display_name)
SELECT gen_random_uuid(), external_references.external_reference, NULL
FROM (
    SELECT DISTINCT owner_subject AS external_reference
    FROM servers
    WHERE owner_subject IS NOT NULL
    UNION
    SELECT DISTINCT user_subject AS external_reference
    FROM server_members
    WHERE user_subject IS NOT NULL
    UNION
    SELECT DISTINCT author_subject AS external_reference
    FROM messages
    WHERE author_subject IS NOT NULL
    UNION
    SELECT DISTINCT participant_subject AS external_reference
    FROM voice_sessions
    WHERE participant_subject IS NOT NULL
) AS external_references
LEFT JOIN users ON users.external_reference = external_references.external_reference
WHERE users.external_reference IS NULL;

ALTER TABLE users ALTER COLUMN id SET NOT NULL;
ALTER TABLE users ALTER COLUMN external_reference SET NOT NULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.table_constraints
        WHERE table_schema = 'public'
          AND table_name = 'users'
          AND constraint_name = 'users_pkey'
    ) THEN
        ALTER TABLE users DROP CONSTRAINT users_pkey;
    END IF;
END $$;

ALTER TABLE users ADD PRIMARY KEY (id);
ALTER TABLE users ADD CONSTRAINT users_external_reference_key UNIQUE (external_reference);

ALTER TABLE servers ADD COLUMN IF NOT EXISTS owner_user_id UUID;
UPDATE servers s
SET owner_user_id = u.id
FROM users u
WHERE s.owner_subject = u.external_reference;
ALTER TABLE servers ALTER COLUMN owner_user_id SET NOT NULL;
ALTER TABLE servers DROP COLUMN IF EXISTS owner_subject;

ALTER TABLE server_members ADD COLUMN IF NOT EXISTS user_id UUID;
UPDATE server_members sm
SET user_id = u.id
FROM users u
WHERE sm.user_subject = u.external_reference;
ALTER TABLE server_members ALTER COLUMN user_id SET NOT NULL;
ALTER TABLE server_members DROP CONSTRAINT IF EXISTS server_members_pkey;
ALTER TABLE server_members DROP COLUMN IF EXISTS user_subject;
ALTER TABLE server_members ADD PRIMARY KEY (server_id, user_id);

ALTER TABLE messages ADD COLUMN IF NOT EXISTS author_user_id UUID;
UPDATE messages m
SET author_user_id = u.id
FROM users u
WHERE m.author_subject = u.external_reference;
ALTER TABLE messages ALTER COLUMN author_user_id SET NOT NULL;
ALTER TABLE messages DROP COLUMN IF EXISTS author_subject;

ALTER TABLE voice_sessions ADD COLUMN IF NOT EXISTS participant_user_id UUID;
UPDATE voice_sessions vs
SET participant_user_id = u.id
FROM users u
WHERE vs.participant_subject = u.external_reference;
ALTER TABLE voice_sessions ALTER COLUMN participant_user_id SET NOT NULL;
ALTER TABLE voice_sessions DROP CONSTRAINT IF EXISTS voice_sessions_pkey;
ALTER TABLE voice_sessions DROP COLUMN IF EXISTS participant_subject;
ALTER TABLE voice_sessions ADD PRIMARY KEY (channel_id, participant_user_id);

ALTER TABLE servers
    ADD CONSTRAINT servers_owner_user_id_fkey
    FOREIGN KEY (owner_user_id)
    REFERENCES users(id)
    ON DELETE RESTRICT;

ALTER TABLE server_members
    ADD CONSTRAINT server_members_user_id_fkey
    FOREIGN KEY (user_id)
    REFERENCES users(id)
    ON DELETE CASCADE;

ALTER TABLE messages
    ADD CONSTRAINT messages_author_user_id_fkey
    FOREIGN KEY (author_user_id)
    REFERENCES users(id)
    ON DELETE RESTRICT;

ALTER TABLE voice_sessions
    ADD CONSTRAINT voice_sessions_participant_user_id_fkey
    FOREIGN KEY (participant_user_id)
    REFERENCES users(id)
    ON DELETE CASCADE;

ALTER TABLE users DROP COLUMN IF EXISTS auth0_subject;

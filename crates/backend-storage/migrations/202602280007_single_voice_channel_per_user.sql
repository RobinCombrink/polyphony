WITH ranked AS (
    SELECT
        ctid,
        ROW_NUMBER() OVER (
            PARTITION BY participant_user_id
            ORDER BY date_created DESC, channel_id DESC
        ) AS row_number
    FROM voice_sessions
)
DELETE FROM voice_sessions voice_session
USING ranked
WHERE voice_session.ctid = ranked.ctid
  AND ranked.row_number > 1;

CREATE UNIQUE INDEX IF NOT EXISTS voice_sessions_participant_user_id_unique
    ON voice_sessions (participant_user_id);

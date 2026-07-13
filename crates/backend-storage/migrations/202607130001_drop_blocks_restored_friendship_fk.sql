-- blocks.restored_friendship_id is a tombstone of the friendship row deleted when the block
-- was created (unblock re-inserts the friendship under this id). A live foreign key to
-- friendships(id) can never hold for it — the referenced row is deleted in the same operation
-- that stores the id — so the FK made every block-while-friends insert fail.
ALTER TABLE blocks DROP CONSTRAINT IF EXISTS blocks_restored_friendship_id_fkey;

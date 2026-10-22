-- Additive migration: do not edit v1 or discard users' prior local memories.
-- GRDB executes the table rebuild and copy atomically within its migration transaction.
CREATE TABLE memoryValue_v4 (
    profile TEXT NOT NULL,
    namespace TEXT NOT NULL,
    id TEXT NOT NULL,
    payload BLOB NOT NULL CHECK (length(payload) BETWEEN 1 AND
        CASE namespace
            WHEN 'room-recall' THEN 8388608
            WHEN 'item-appearance' THEN 1048576
            ELSE 64000
        END),
    updated REAL NOT NULL,
    PRIMARY KEY (profile, namespace, id)
);
INSERT INTO memoryValue_v4(profile,namespace,id,payload,updated)
    SELECT profile,namespace,id,payload,updated FROM memoryValue;
DROP TABLE memoryValue;
ALTER TABLE memoryValue_v4 RENAME TO memoryValue;
-- The API rejects unknown namespaces. The fallback budget above preserves any legacy
-- rows written outside the API instead of failing or silently dropping them on upgrade.

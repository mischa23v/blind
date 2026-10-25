-- Additive v5 migration; preserve every old row and all unrelated budgets.
-- Only the paired, bounded conversation snapshot keys receive larger caps.
CREATE TABLE memoryValue_v5 (
    profile TEXT NOT NULL,
    namespace TEXT NOT NULL,
    id TEXT NOT NULL,
    payload BLOB NOT NULL CHECK (length(payload) BETWEEN 1 AND
        CASE
            WHEN namespace='dialogue' AND id='active' THEN 131072
            WHEN namespace='companion' AND id='working-state' THEN 8388608
            WHEN namespace='room-recall' THEN 8388608
            WHEN namespace='item-appearance' THEN 1048576
            ELSE 64000
        END),
    updated REAL NOT NULL,
    PRIMARY KEY (profile, namespace, id)
);
INSERT INTO memoryValue_v5(profile,namespace,id,payload,updated)
    SELECT profile,namespace,id,payload,updated FROM memoryValue;
DROP TABLE memoryValue;
ALTER TABLE memoryValue_v5 RENAME TO memoryValue;

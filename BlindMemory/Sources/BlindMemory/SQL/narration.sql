CREATE TABLE narrationReceipt (
    profile TEXT NOT NULL,
    id TEXT NOT NULL,
    sessionID TEXT NOT NULL,
    goalRevision TEXT NOT NULL,
    snapshotID TEXT NOT NULL,
    sourceIDs BLOB NOT NULL CHECK (length(sourceIDs) BETWEEN 2 AND 8192),
    text TEXT NOT NULL CHECK (length(text) BETWEEN 1 AND 2000),
    outcome TEXT NOT NULL CHECK (outcome IN ('pending', 'completed', 'interrupted', 'unknown')),
    created REAL NOT NULL,
    finished REAL,
    PRIMARY KEY (profile, id)
);
CREATE INDEX narrationReceiptRecent ON narrationReceipt(profile, created DESC);

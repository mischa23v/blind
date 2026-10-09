CREATE TABLE room (
    profile TEXT NOT NULL,
    id TEXT NOT NULL,
    currentRevision TEXT,
    PRIMARY KEY (profile, id),
    FOREIGN KEY (profile, id, currentRevision) REFERENCES roomRevision(profile, room, id)
        DEFERRABLE INITIALLY DEFERRED
);
CREATE TABLE roomRevision (
    profile TEXT NOT NULL,
    room TEXT NOT NULL,
    id TEXT NOT NULL,
    parent TEXT,
    payload BLOB NOT NULL CHECK (length(payload) BETWEEN 1 AND 2000000),
    source TEXT NOT NULL CHECK (source IN ('scan', 'legacy', 'user', 'ai_reviewed', 'restore')),
    created REAL NOT NULL,
    PRIMARY KEY (profile, room, id),
    FOREIGN KEY (profile, room) REFERENCES room(profile, id) ON DELETE CASCADE,
    FOREIGN KEY (profile, room, parent) REFERENCES roomRevision(profile, room, id)
);
CREATE TABLE roomProposal (
    profile TEXT NOT NULL,
    room TEXT NOT NULL,
    id TEXT NOT NULL,
    baseRevision TEXT NOT NULL,
    payload BLOB NOT NULL CHECK (length(payload) BETWEEN 1 AND 2000000),
    source TEXT NOT NULL CHECK (source IN ('user', 'ai_reviewed', 'restore')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created REAL NOT NULL,
    PRIMARY KEY (profile, room, id),
    FOREIGN KEY (profile, room, baseRevision) REFERENCES roomRevision(profile, room, id) ON DELETE CASCADE
);
CREATE TABLE memoryValue (
    profile TEXT NOT NULL,
    namespace TEXT NOT NULL,
    id TEXT NOT NULL,
    payload BLOB NOT NULL CHECK (length(payload) BETWEEN 1 AND 64000),
    updated REAL NOT NULL,
    PRIMARY KEY (profile, namespace, id)
);

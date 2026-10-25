-- Dedicated observation database only. Never rebuild or query ordinary memoryValue.
-- Payloads are immutable; quota accounting reads cached lengths, not historical blobs.
CREATE TABLE nativeObservation (
    insertionSequence INTEGER PRIMARY KEY AUTOINCREMENT,
    profile TEXT NOT NULL CHECK (length(profile) BETWEEN 1 AND 100),
    id TEXT NOT NULL COLLATE NOCASE CHECK (
        length(id)=36 AND substr(id,9,1)='-' AND substr(id,14,1)='-'
        AND substr(id,19,1)='-' AND substr(id,24,1)='-'
        AND length(replace(id,'-',''))=32 AND replace(id,'-','') NOT GLOB '*[^0-9a-fA-F]*'),
    sessionID TEXT NOT NULL COLLATE NOCASE CHECK (
        length(sessionID)=36 AND substr(sessionID,9,1)='-' AND substr(sessionID,14,1)='-'
        AND substr(sessionID,19,1)='-' AND substr(sessionID,24,1)='-'
        AND length(replace(sessionID,'-',''))=32 AND replace(sessionID,'-','') NOT GLOB '*[^0-9a-fA-F]*'),
    capturedAt REAL NOT NULL CHECK (capturedAt>=0 AND capturedAt<=1.7976931348623157e308),
    payload BLOB NOT NULL CHECK (typeof(payload)='blob'),
    encodedBytes INTEGER NOT NULL CHECK (encodedBytes BETWEEN 1 AND 2097152 AND encodedBytes=length(payload)),
    UNIQUE (profile,id)
);
CREATE INDEX nativeObservationProfileOrder ON nativeObservation(profile,insertionSequence);
CREATE INDEX nativeObservationSessionTime ON nativeObservation(profile,sessionID,capturedAt);
CREATE TABLE nativeObservationState (
    profile TEXT PRIMARY KEY NOT NULL CHECK (length(profile) BETWEEN 1 AND 100),
    evictedRecordCount INTEGER NOT NULL CHECK (
        typeof(evictedRecordCount)='integer' AND evictedRecordCount BETWEEN 0 AND 1000000000)
);

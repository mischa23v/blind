-- Private, bounded diagnostic events. No photos, cloud sharing or live authority.
CREATE TABLE navigationTestSession (
 profile TEXT NOT NULL REFERENCES recordedTrip(profile) ON DELETE CASCADE,
 id TEXT NOT NULL, epoch TEXT NOT NULL,
 schemaVersion INTEGER NOT NULL DEFAULT 1 CHECK(schemaVersion=1),
 startedAt REAL NOT NULL CHECK(startedAt>=0), createdAt REAL NOT NULL CHECK(createdAt>=0),
 nextSequence INTEGER NOT NULL DEFAULT 0 CHECK(nextSequence BETWEEN 0 AND 3257),
 retainedBytes INTEGER NOT NULL DEFAULT 0 CHECK(retainedBytes BETWEEN 0 AND 16777216),
 status TEXT NOT NULL DEFAULT 'recording' CHECK(status IN ('recording','stopped','capacityReached')),
 PRIMARY KEY(profile,id)
);
CREATE TABLE navigationTestEvent (
 profile TEXT NOT NULL, sessionID TEXT NOT NULL,
 sequence INTEGER NOT NULL CHECK(sequence BETWEEN 0 AND 3256),
 payload BLOB NOT NULL CHECK(typeof(payload)='blob' AND length(payload) BETWEEN 1 AND 262144),
 encodedBytes INTEGER NOT NULL CHECK(encodedBytes=length(payload)),
 chargedBytes INTEGER NOT NULL CHECK(chargedBytes=max(encodedBytes,256)),
 PRIMARY KEY(profile,sessionID,sequence),
 FOREIGN KEY(profile,sessionID) REFERENCES navigationTestSession(profile,id) ON DELETE CASCADE
);

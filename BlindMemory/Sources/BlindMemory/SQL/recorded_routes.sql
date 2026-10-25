-- Private camera route history. Not live pose, ordinary model context or public maps.
CREATE TABLE recordedTrip (
 profile TEXT PRIMARY KEY NOT NULL, id TEXT NOT NULL, epoch TEXT NOT NULL,
 nextSequence INTEGER NOT NULL DEFAULT 0 CHECK(nextSequence>=0),
 retainedBytes INTEGER NOT NULL DEFAULT 0 CHECK(retainedBytes>=0),
 retainedCount INTEGER NOT NULL DEFAULT 0 CHECK(retainedCount>=0),
 evictedCount INTEGER NOT NULL DEFAULT 0 CHECK(evictedCount>=0),
 legacyImportFinished INTEGER NOT NULL DEFAULT 0 CHECK(legacyImportFinished IN (0,1))
);
CREATE TABLE recordedRouteSample (
 profile TEXT NOT NULL REFERENCES recordedTrip(profile) ON DELETE CASCADE,
 sequence INTEGER NOT NULL CHECK(sequence>=0), id TEXT NOT NULL,
 sessionID TEXT NOT NULL, sourceFrameID TEXT NOT NULL,
 capturedAt REAL NOT NULL CHECK(capturedAt>=0),
 payload BLOB NOT NULL CHECK(typeof(payload)='blob' AND length(payload) BETWEEN 1 AND 4096),
 encodedBytes INTEGER NOT NULL CHECK(encodedBytes=length(payload)),
 chargedBytes INTEGER NOT NULL CHECK(chargedBytes=max(encodedBytes,256)),
 PRIMARY KEY(profile,sequence), UNIQUE(profile,id)
);
CREATE TABLE recordedRouteAnchor (
 profile TEXT NOT NULL, id TEXT NOT NULL, sequence INTEGER NOT NULL,
 kind TEXT NOT NULL CHECK(kind IN ('start','entrance','meetingPoint')),
 label TEXT NOT NULL CHECK(length(label)<=160),
 PRIMARY KEY(profile,id), FOREIGN KEY(profile,sequence) REFERENCES recordedRouteSample(profile,sequence) ON DELETE RESTRICT
);
CREATE UNIQUE INDEX recordedRouteStart ON recordedRouteAnchor(profile) WHERE kind='start';
CREATE INDEX recordedRouteAnchorSequence ON recordedRouteAnchor(profile,sequence);

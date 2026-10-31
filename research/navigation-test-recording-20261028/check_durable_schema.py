#!/usr/bin/env python3
"""SQLite schema constraints only: not Swift, GRDB API or device validation."""
import hashlib
import json
import sqlite3
from pathlib import Path

root = Path(__file__).resolve().parents[2]
paths = [root / 'BlindMemory/Sources/BlindMemory/SQL' / name
         for name in ('recorded_routes.sql', 'navigation_test_recordings.sql')]
db = sqlite3.connect(':memory:')
db.execute('PRAGMA foreign_keys=ON')
for path in paths:
    db.executescript(path.read_text())
checks = ['both_migrations_parse']
db.execute("INSERT INTO recordedTrip(profile,id,epoch) VALUES ('synthetic','trip','epoch')")
db.execute("INSERT INTO navigationTestSession(profile,id,epoch,startedAt,createdAt) VALUES ('synthetic','test','epoch',1,1)")
db.execute("INSERT INTO recordedRouteSample VALUES ('synthetic',0,'pose','session','frame',1,?,4,256)", (b'pose',))
db.execute("INSERT INTO navigationTestEvent VALUES ('synthetic','test',0,?,9,256)", (b'synthetic',))
assert db.execute('SELECT payload FROM navigationTestEvent').fetchone()[0] == b'synthetic'
checks.append('opaque_bytes_unchanged')
db.execute('DELETE FROM recordedRouteSample')
assert db.execute('SELECT count(*) FROM navigationTestEvent').fetchone()[0] == 1
checks.append('ordinary_route_eviction_does_not_delete_diagnostic')
for name, sequence, payload, encoded in [
    ('negative_sequence_rejected', -1, b'x', 1),
    ('past_event_cap_rejected', 3257, b'x', 1),
    ('text_payload_rejected', 1, 'x', 1),
    ('wrong_byte_count_rejected', 1, b'x', 2),
    ('oversized_event_rejected', 1, b'x' * 262145, 262145),
]:
    try:
        db.execute("INSERT INTO navigationTestEvent VALUES ('synthetic','test',?,?,?,?)",
                   (sequence, payload, encoded, max(encoded, 256)))
    except sqlite3.IntegrityError:
        checks.append(name)
    else:
        raise AssertionError(name)
db.execute("DELETE FROM recordedTrip WHERE profile='synthetic'")
assert db.execute('SELECT count(*) FROM navigationTestSession').fetchone()[0] == 0
assert db.execute('SELECT count(*) FROM navigationTestEvent').fetchone()[0] == 0
checks.append('explicit_trip_clear_cascades_diagnostics')
print(json.dumps({'checks_passed': checks, 'count': len(checks), 'swift_or_grdb_executed': False,
                  'schema_sha256': {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
                                    for p in paths}}, indent=2))

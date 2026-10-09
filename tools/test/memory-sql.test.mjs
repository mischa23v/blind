import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';

const sql = name => readFileSync(new URL(`../../BlindMemory/Sources/BlindMemory/SQL/${name}.sql`, import.meta.url), 'utf8');
function fixture(t) {
  const db = new DatabaseSync(':memory:'); t.after(() => db.close());
  db.exec('PRAGMA foreign_keys=ON'); db.exec(sql('schema')); db.exec(sql('deletion')); db.exec(sql('narration'));
  db.exec("BEGIN; INSERT INTO room(profile,id) VALUES ('a','bedroom'),('a','bathroom'),('b','bedroom');");
  for (const [profile, room, next] of [['a', 'bedroom', 'r1'], ['a', 'bathroom', 'r2'], ['b', 'bedroom', 'r3']]) {
    db.prepare(sql('insert_revision')).run({ profile, room, next, base: null, payload: Buffer.from('measured scan'), source: 'scan', created: 1 });
    db.prepare('UPDATE room SET currentRevision=? WHERE profile=? AND id=?').run(next, profile, room);
  }
  db.exec('COMMIT'); return db;
}
test('production SQL keeps drafts separate and rejects cross-room and cross-profile references', t => {
  const db = fixture(t);
  const proposal = db.prepare('INSERT INTO roomProposal(profile,room,id,baseRevision,payload,source,created) VALUES (?,?,?,?,?,?,?)');
  proposal.run('a', 'bedroom', 'p1', 'r1', Buffer.from('draft'), 'ai_reviewed', 2);
  assert.equal(db.prepare("SELECT currentRevision FROM room WHERE profile='a' AND id='bedroom'").get().currentRevision, 'r1');
  assert.throws(() => proposal.run('a', 'bedroom', 'bad', 'r2', Buffer.from('bad'), 'user', 2), /FOREIGN KEY/);
  assert.throws(() => proposal.run('b', 'bedroom', 'bad', 'r1', Buffer.from('bad'), 'user', 2), /FOREIGN KEY/);
  assert.throws(() => proposal.run('a', 'bedroom', 'bad', 'r1', Buffer.from('bad'), 'auto_approved', 2), /CHECK/);
});
test('production compare-and-swap cannot advance a changed room and rollback removes uncommitted revision', t => {
  const db = fixture(t), insert = db.prepare(sql('insert_revision')), advance = db.prepare(sql('advance_room'));
  db.exec('BEGIN');
  insert.run({ profile: 'a', room: 'bedroom', next: 'r4', base: 'r1', payload: Buffer.from('approved'), source: 'user', created: 2 });
  assert.equal(advance.run({ profile: 'a', room: 'bedroom', next: 'r4', base: 'r1' }).changes, 1);
  db.exec('COMMIT; BEGIN');
  insert.run({ profile: 'a', room: 'bedroom', next: 'stale', base: 'r1', payload: Buffer.from('stale draft'), source: 'ai_reviewed', created: 3 });
  assert.equal(advance.run({ profile: 'a', room: 'bedroom', next: 'stale', base: 'r1' }).changes, 0);
  db.exec('ROLLBACK');
  assert.equal(db.prepare("SELECT count(*) n FROM roomRevision WHERE id='stale'").get().n, 0);
  assert.equal(db.prepare("SELECT currentRevision FROM room WHERE profile='a' AND id='bedroom'").get().currentRevision, 'r4');
  assert.equal(db.prepare("SELECT count(*) n FROM roomRevision WHERE profile='a' AND room='bedroom'").get().n, 2);
});
test('database rejects invalid heads at commit and empty or oversized payloads', t => {
  const db = fixture(t);
  db.exec("BEGIN; UPDATE room SET currentRevision='missing' WHERE profile='a' AND id='bedroom'");
  assert.throws(() => db.exec('COMMIT'), /FOREIGN KEY/); db.exec('ROLLBACK');
  const insert = db.prepare(sql('insert_revision'));
  for (const payload of [Buffer.alloc(0), Buffer.alloc(2_000_001)]) {
    assert.throws(() => insert.run({ profile: 'a', room: 'bedroom', next: 'bad', base: 'r1', payload, source: 'user', created: 2 }), /CHECK/);
  }
});
test('deletion removes revision chains and proposals but preserves other rooms and deletion marker', t => {
  const db = fixture(t);
  db.prepare(sql('insert_revision')).run({ profile: 'a', room: 'bedroom', next: 'r4', base: 'r1', payload: Buffer.from('approved'), source: 'user', created: 2 });
  db.prepare(sql('advance_room')).run({ profile: 'a', room: 'bedroom', next: 'r4', base: 'r1' });
  db.exec("INSERT INTO roomProposal VALUES ('a','bedroom','p1','r4',X'01','user','pending',3);");
  db.exec("BEGIN; INSERT INTO deletedRoom VALUES ('a','bedroom'); UPDATE room SET currentRevision=NULL WHERE profile='a' AND id='bedroom'; DELETE FROM room WHERE profile='a' AND id='bedroom'; COMMIT;");
  for (const table of ['roomRevision', 'roomProposal']) assert.equal(db.prepare(`SELECT count(*) n FROM ${table} WHERE profile='a' AND room='bedroom'`).get().n, 0);
  assert.equal(db.prepare('SELECT count(*) n FROM room').get().n, 2);
  assert.equal(db.prepare('SELECT count(*) n FROM deletedRoom').get().n, 1);
  assert.deepEqual(db.prepare('PRAGMA foreign_key_check').all(), []);
});

test('production narration schema distinguishes outcomes, bounds text and isolates profile IDs', t => {
  const db = fixture(t);
  const insert = db.prepare('INSERT INTO narrationReceipt(profile,id,sessionID,goalRevision,snapshotID,sourceIDs,text,outcome,created) VALUES (?,?,?,?,?,?,?,?,?)');
  for (const [id, outcome] of ['pending', 'completed', 'interrupted', 'unknown'].entries())
    insert.run('a', `speech-${id}`, 'session', 'goal', 'snapshot', Buffer.from('[]'), 'Observed artwork.', outcome, 1);
  insert.run('b', 'speech-0', 'session', 'goal', 'snapshot', Buffer.from('[]'), 'Other profile.', 'pending', 1);
  assert.equal(db.prepare("SELECT count(*) n FROM narrationReceipt WHERE profile='a'").get().n, 4);
  assert.throws(() => insert.run('a', 'bad', 'session', 'goal', 'snapshot', Buffer.from('[]'), 'Guess.', 'assumed-heard', 1), /CHECK/);
  assert.throws(() => insert.run('a', 'bad', 'session', 'goal', 'snapshot', Buffer.from('[]'), 'x'.repeat(2001), 'pending', 1), /CHECK/);
  assert.throws(() => insert.run('a', 'speech-0', 'session', 'goal', 'snapshot', Buffer.from('[]'), 'Replacement.', 'pending', 1), /UNIQUE/);
  assert.equal(db.prepare("SELECT text FROM narrationReceipt WHERE profile='b'").get().text, 'Other profile.');
});

import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const root = new URL('../../', import.meta.url);
const read = p => readFileSync(new URL(p, root), 'utf8');
const store = read('ios/BlindAssist/PlaceStore.swift');
const view = read('ios/BlindAssist/RoomDetailView.swift');
const between = (s, a, b) => { assert.ok(s.includes(a), a); assert.ok(s.includes(b), b); return s.slice(s.indexOf(a), s.indexOf(b, s.indexOf(a))); };
const moves = between(store, '@MainActor func trashPhoto', '/// Call only after');
test('trash and restore move fixed UUID-owned files without replacing destinations', () => {
  assert.match(moves, /source: "photo.jpg", destination: "photo-trash.jpg"/);
  assert.match(moves, /source: "photo-trash.jpg", destination: "photo.jpg"/);
  assert.match(moves, /places.contains\(where: \{ \$0.id == place.id \}\)/);
  assert.match(moves, /guard !FileManager.default.fileExists\(atPath: to.path\)/);
  assert.ok(moves.indexOf('guard !FileManager') < moves.indexOf('moveItem(at: from, to: to)'));
  assert.doesNotMatch(moves, /removeItem|copyItem|replaceItem|URLSession|deleteRoom|deleteValue/);
});
test('permanent deletion is restricted to one trash file and requires visible confirmation', () => {
  const purge = between(store, '@MainActor func deleteTrashedPhoto', 'func savePhoto(');
  assert.match(purge, /places.contains/);
  assert.match(purge, /removeItem\(at: directory.appendingPathComponent\("\\\(place.id\).photo-trash.jpg"\)\)/);
  assert.doesNotMatch(purge, /contentsOfDirectory|deleteRoom|deleteValue|photo.jpg"/);
  const confirmation = between(view, '.confirmationDialog(t("Permanently delete', '.onDisappear');
  assert.match(confirmation, /isPresented: \$confirmDeletePhoto/);
  assert.match(confirmation, /role: \.destructive/);
  assert.match(confirmation, /deleteTrashedPhoto\(for: place\)/);
  assert.match(confirmation, /role: \.cancel/);
  assert.equal((view.match(/deleteTrashedPhoto\(/g) ?? []).length, 1);
});
test('pending imports cannot resurrect a moved photo and UI reports storage errors', () => {
  const change = between(view, 'private func changeReferencePhoto', 'private func confidence');
  assert.ok(change.indexOf('photoRevision = UUID(); photo = nil') < change.indexOf('try operation()'));
  assert.match(change, /catch/); assert.match(change, /refreshReferencePhoto\(\)/);
  const load = between(view, '.task(id: photo)', 'private func refreshReferencePhoto');
  assert.ok(load.indexOf('guard revision == photoRevision, self.photo == photo') < load.indexOf('savePhoto(jpeg'));
  assert.match(load, /Task.checkCancellation\(\)/);
  assert.equal((load.match(/guard revision == photoRevision, self.photo == photo/g) ?? []).length, 2, 'stale success and failure are both fenced');
  assert.match(view, /\.onDisappear \{ photoRevision = UUID\(\); photo = nil \}/);
});
test('one-slot limits, existing room tombstone cleanup, and local protection remain', () => {
  assert.match(view, /\.disabled\(hasTrashedPhoto\)/);
  assert.match(view, /\.disabled\(photoURL != nil\)/);
  const cleanup = between(store, 'func retryDeletionCleanup()', '\n    func ');
  assert.match(cleanup, /"photo.jpg", "photo-trash.jpg"/);
  assert.match(store, /isExcludedFromBackup = true/);
  assert.match(store, /jpeg.count <= 2_000_000/);
  assert.match(store, /completeFileProtectionUntilFirstUserAuthentication/);
});
test('automatic appearance retention remains bounded and is not coupled to reference trash', () => {
  const recall = read('ios/BlindAssist/RoomRecall.swift');
  const items = read('ios/BlindAssist/ItemAppearance.swift');
  assert.match(recall, /sectors = 8, maxPerSector = 2/);
  assert.match(items, /maxViews = 6/);
  assert.doesNotMatch(moves, /RoomRecall|ItemAppearance|worldmap|layout/);
});

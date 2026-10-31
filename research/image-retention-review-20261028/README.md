# Private reference-photo trash — 2026-10-28

## Delivered, not a navigation result

Room settings now offer **Move photo to trash**, **Restore trashed photo**, and a separately confirmed **Delete trashed photo permanently**. This affects only the manually selected private room reference photo. No room map, room-recall identity, item fingerprint, original Photos-library image, or navigation evidence is deleted by these controls.

- Reuses `PlaceStore` and its existing protected, backup-excluded local Places directory; no new database or cloud transfer.
- One active `UUID.photo.jpg` and one `UUID.photo-trash.jpg`, each originally limited to 2 MB by the existing save API. A move preserves the file rather than copying it. Existing active-image replacement still follows the explicitly labelled Add/replace action.
- Moving or restoring refuses an occupied destination, including at the filesystem move operation. There is no silent trash rotation or automatic expiry. With an active photo and occupied trash, the user must explicitly purge trash before moving the active photo; restoration cannot overwrite the active photo.
- Permanent deletion is limited to that room's exact trash filename and exists only behind its separate visible destructive confirmation. No actual user data was deleted in this development session.
- Existing full-room tombstone cleanup includes the trash filename, so deleting an entire room does not leave its discarded photo behind.
- Picker tasks check cancellation, selected-item ownership and an operation revision before saving. Trash/restore/purge invalidate pending transfers first, preventing a late imported image from resurrecting a cleared photo. Leaving the view also invalidates its transfer.
- User-facing labels and errors are English/Arabic. Errors remain visible; no success is claimed after a failed move/delete.

## What was already bounded

Continuous perception does not append every camera frame to a photo album. `RoomRecall` caps view thumbnails at eight sectors × two views, with 320-pixel thumbnails and a learning interval; `ItemAppearance` caps six feature-print views rather than storing raw camera photos. Their existing forget operations and work-revision fencing are unchanged. This change is deliberately not a new cleanup policy for perception evidence.

## Evidence and limits

`node --test tools/test/room-reference-photo-trash.test.mjs`: **5/5 source-contract checks pass**. These inspect implementation contracts, not native execution. `git diff --check` on the two implementation files passes.

Privacy + selected-photo regression run: **15/16 checks pass**. One pre-existing/shared-worktree project-membership consistency check fails at `selected-photo-reference.test.mjs:129`; checked-in PBX differs from the in-memory generated project. The project was not changed by this agent. See compact logs here.

No Swift executable is installed in this environment; no Swift compilation, filesystem failure-injection, simulator, VoiceOver or device test is claimed. Root's native CI and supervised UI review remain required. No navigation/collision reliability conclusion follows from these tests.

## Native acceptance still required

1. Add reference image, trash it, restart app, restore it; verify bytes and backup/protection metadata remain unchanged.
2. With both active and trash present, verify disabled actions plus store-level refusal preserve both bytes.
3. Cancel permanent-deletion dialog: both files unchanged. Confirm: only trash disappears; room/map/Photos remain.
4. Delay a PhotosPicker load, then trash/restore or leave the view: delayed completion must not save.
5. Simulate move/delete failure: show error and existing state, no false success. Restart during same-directory move: at most one of the active/trash names holds the moved image.
6. Delete a whole room: tombstoned cleanup removes both image files, including retry after interrupted cleanup.
7. VoiceOver can identify all actions and destructive confirmation in English/Arabic.

## Independent review

The localization-contract agent independently reviewed the two implementation files and reran all five scoped checks: no blocker found. Its minor observation about an obsolete picker failure overwriting newer status was addressed by applying the same revision/item guard in the error branch. Native execution remains unverified.

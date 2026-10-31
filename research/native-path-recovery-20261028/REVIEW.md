# Independent review — native path diagnostic recovery

Reviewed 2026-10-28 against the exact published baseline dc32a9bad9a75566f27924fb9f7aa8fe50a46e95. The historical failure baseline in README.md is unchanged.

## Source review outcome

No blocking issue found in this source-only review of the metadata/oracle/collector candidate. This is **not** an Apple compilation, native execution, performance improvement or path-success claim.

- **Metadata adapter:** missingMetadata is separated into content-free read/decode/empty/invalid-entry/missing-node/unknown-feature failures. Exact node-name/inherited-ID matching and all geometry bounds remain fail-closed. No JSON/plist or geometry fallback was introduced.
- **Public-fixture inventory:** test-only source digest admission occurs before either export. The attachment contains only bounded structural fields, safe names plus hashes, known public UUIDs and content-free failures. Format signatures distinguish json/binaryPlist/xmlPlist/unknown without retaining raw metadata. Diagnostic export does not create physical authority or silently adopt unknown section geometry.
- **Collision oracle:** retained offscreen renderer/update and default source collision-mask candidate remain hypotheses pending Apple execution. Ten exact positive/negative controls run without early failure short-circuit; both directions, initial/terminal overlap, contained-solid separation, overhead-height and floor separation are required. The 4-by-10 matrix cannot replace the selected candidate with a passing alternate cell. Fixed speed-one cells do not isolate the old speed-zero variable.
- **Collector:** only the original three and two exact additional authored attachment/test pairs are admitted. Source pins, explicit failure verdicts, fixed synthetic UUID categories, exact control predicates and budgets remain checked. Unknown/raw/private fields and arbitrary error strings are rejected.
- **Classified test:** nil callback result after the unchanged 10-second wait now requests terminal stopAndDiscard before XCTUnwrap throws. Existing nonnil path still performs ordinary discard. Test-only submitted/callback/discard receipts do not separate native queue/build/route/callback delay and do not prove cleanup completion before its actual callback. The collision worker independently reviewed this change with no blocker.

## Executed bounded checks

- Updated `tools/test/roomplan-route-diagnostic.test.mjs`: **9 passed, 0 failed**. The old literal error-message/signature assertions were replaced by the stronger mandatory-candidate and ten-control contract, not deleted.
- `tools/ci/test-native-route-diagnostic-evidence.py`: **51 passed** in the independent rerun.
- Unchanged `tools/ci/test-native-unit-statuses.py`: **31 passed** in the independent rerun.
- Python syntax compilation: passed for the collector and its test module.
- Direct `tools/test/room-route-project.test.mjs`: **1 passed, 1 failed**. The mutation-rejection test passed. The canonical-directory comparison failed because the resumed workspace contains 2 of the remote tree's 65 app Swift files, not because of a proven project change. The production test was not edited.
- A separate exact-tree check supplied the canonical generator with all 65 app filenames read from the GitHub tree at dc32a9b; generated output matched the unchanged canonical project byte-for-byte (SHA256 d65a2d9eaa66fdb5a46e89ac27438cf1340cc31f096423d16abaa6adbc37c543). This validates source membership only, not nonexistent local source contents or an Apple build.

Swift/Xcode are unavailable in this executor. Full repository tests, native startup/export/collision/path and device acceptance remain unrun on these candidate edits.

## Narrow changed-file scope owned by this reviewer

1. `ios/BlindAssistTests/ClassifiedRoomMeshTests.swift`
2. `tools/test/roomplan-route-diagnostic.test.mjs`
3. The separately named review evidence files in this directory.

Other restored dependencies came unchanged from exact dc32a9b for bounded source checks; do not republish them as edits. The full local partial-checkout assertion dump is diagnostic scratch, excluded from the publication allowlist. `REVIEW_SHA256SUMS.txt` records the reviewed code plus compact evidence. Other workers retain ownership of the metadata, collision and collector files.

The next acceptance gate is the same native tests on the exact final published commit. Any remaining failure remains a failure; missing routes or no-contact arrays from an unready backend do not prove successful navigation.


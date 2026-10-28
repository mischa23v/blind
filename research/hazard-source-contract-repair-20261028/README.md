# Helper-aware hazard source-contract repair — 2026-10-28

This is a **separate test-only successor** to the saved-frame camera-association candidate. It changes only `tools/test/native-depth-policy.test.mjs` and `tools/test/passive-object-memory.test.mjs`. No runtime cadence, detector, camera, helper, physical gate or app source changed.

## Original failures and proof

The broader saved-frame source run had 67 passes and two failures. Both failures were then reproduced with exact unchanged recorder-era NavigationModel SHA-256 `f101f67cb88c6b2ea8847a380ce09a351322f73e01df0dcb9e0893146d4264d1` in a disposable fixture: 9/11 passes, the same two failures. See [baseline fixture](../saved-frame-diagnostic-association-20261028/BASELINE_FIXTURE.json) and [retained baseline output](../saved-frame-diagnostic-association-20261028/node-baseline-two-failures.tap).

- The native-depth contract searched from the frame callback through the remainder of the file. A later helper's repeated invalidation token could satisfy the mutated check, so its negative test failed to throw.
- The passive-memory contract expected inline `detector.process(observation)` before background work, but the source had already extracted that work into the synchronous `processDepthHazards` helper. This was an outdated source-shape assumption, not evidence that the runtime detector was moved behind RGB.

## Repair and retained strength

Both tests now inspect a bounded callback declaration. They reuse the existing `assertDepthHazardsBefore` helper, which verifies the actual detector helper body and both direct hazard assignments, a single top-level synchronous call, no `Task`/`defer`/conditional-compilation wrapper, and ordering before the actual background consumer.

The native-depth test binds the specific nil-depth guard, not a later token elsewhere. Its first statement must synchronously retire observed-scene evidence, and its suffix must synchronously invalidate detector evidence, publish the unavailable result, then perform nonspatial fallback and return. Its four original removal mutations remain, with additional mutations for asynchronous retirement, missing publication, `Task`/`defer` hazard calls, moved hazard calls and altered detector/publication.

The passive-memory test preserves the 15 Hz pose cadence and the ban on ordinary-work admission guards before sampling. Its visual-observation interval is checked in the actual `passiveMemoryEligible` producer and utility task in `updatePassiveObjectMemory`, not an unrelated textual occurrence. New mutations reject cadence removal, busy gating, deferred/asynchronous/reordered hazard work, a replaced detector and loss of the actual visual interval/utility task.

There are **20 negative mutations** across the two repaired test cases. These remain source contracts, not ARKit execution or physical-safety proof.

## Results

- `node-corrected.tap`: **11/11 passed** for the two affected files.
- `node-affected.tap`: **69/69 passed** for the same broader affected source set that previously yielded 67/69.
- The original test preimages are retained in `preimage/`.
- `node-initial.tap` and `node-final.tap` retain intermediate repair failures: one assertion was initially scoped to the dispatcher rather than the actual eligibility producer, and Node's generated assertion-message parser threw a SyntaxError on a multiline template. Scoping was corrected and an explicit assertion message avoided the parser issue; no mutation was suppressed.
- All six saved-frame candidate pins were rechecked unchanged after this repair, including NavigationModel SHA-256 `fcea783bbbbaa4e1bdda04740fc38f11c10f30de1e6160d8eb5072d7b4a01298`.
- No Swift/Apple runtime tests were run by this test-only slice. Independent review requested separately.

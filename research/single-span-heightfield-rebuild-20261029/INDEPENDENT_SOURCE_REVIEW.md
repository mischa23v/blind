# Independent source review — 2026-10-29

## Decision and exact scope

No remaining source-review blocker identified **to a separately admitted, bounded synthetic experiment** for the frozen rebuilt candidate. This is not a compile/test pass, API-adoption approval, app activation, route acceptance or physical navigation authority. Root retains admission/publication responsibility.

Reviewed independently from the author; the lost candidate and its reported results are not evidence here. Candidate identity is `single-span-heightfield-rebuild-20261029-v1`, receipt schema 4. Final candidate manifest SHA-256:

`9f3db3063c97a312b11d48180c117472faf31a29c91fd3fd1b4dfbf2d77e98b2`

Exact hashes of all candidate files, published reference pins, local API header and Recast compile inputs/headers are in `REVIEW_INPUT_HASHES.json`. Compiler/system-library identity is not established by this source review and must be recorded at execution admission. Reviewed checkout HEAD was `006a698dc7f1eabc4122369bd73fc5562fae0429`; published reference base is `c79fbd33171f78608f9eb2a1484fbc9266e3a695`.

## Finding repaired during review

**Single-use contract mismatch:** before repair, `apply` called before `prepare` refused but left `attempted_` false, allowing a later successful `prepare`. This contradicted the documented all-attempts consumption contract. Author added `attempted_=true` at apply entry and a fixture requiring apply-before-prepare followed by prepare to refuse without changing areas. Re-read final source and refreshed hashes; source defect is resolved, regression remains unexecuted.

Early observed fixture-description discrepancies were also reconciled before the final freeze: the center with `h == walkableHeight` is correctly described as minimum-clearance, not disconnected; invalid-prepare case count includes isolated under-height span. Final plan has **23 authored mask comparisons and 37 authored refusal cases**, not passing results.

## Reviewed invariants

- **Raw-pointer boundary:** dimensions/count caps precede indexed traversal; contiguous single-span cursor validation, range checks and neighbor index checks prevent metadata-based overrun within the declared live allocation precondition. The helper cannot validate allocation sizes/lifetime, pointer reuse, allocator correctness or races. Caller must supply correctly typed/aligned, live, nonaliasing storage and serialize operations through destruction. Receipt storage must also remain live and separate. This is a trusted internal API, not an arbitrary-pointer sandbox.
- **Variable Y and clearance:** constant-Y rejection is removed only in the new research helper. Every span, including null-area and isolated spans, must have `h >= walkableHeight`. Existing edge offsets must be zero into exactly one in-bounds neighbor and reciprocal. Overlap `min(y+h)-max(y)` and absolute climb match the pinned `Recast.cpp::rcBuildCompactHeightfield` predicate. Missing edges remain missing; no floor choice, flattening or connectivity repair occurs. Climb/overlap arithmetic stays within int range for Recast field widths.
- **World/grid admission:** positive finite cs/ch; finite strictly ordered bounds; positive bounded height and nonnegative bounded climb; guarded X/Z nearest-integer conversion uses the pinned `rcCalcGridSize` arithmetic. This is consistency checking, not proof that an authored field came from an actual measured-world rasterization.
- **Immutable transaction ownership:** exact field, cells, spans, areas and receipt identities are bound. Bounds, dimensions, scales, compact metadata and dist pointer are compared; cell/span object bytes are frozen. Replaced pointers fail before snapshot dereferences. Dist array contents are not snapshotted or consumed by this helper; no dist-content integrity claim is made. Receipt comparison covers every named field, not padding. Prepared internal budget is used rather than trusting later public receipt fields.
- **Area contract:** only original values or null are admitted after stock erosion; relabeling non-null areas or reviving originally null areas refuses. This cannot prove that the caller really ran stock erosion or used the intended radius. The required unchanged stock erosion operation and success check remain caller obligations.
- **Original seeds and predicate:** original null spans, absent connections, adjacency to original null areas and the one-cell exterior perimeter are captured before erosion. Absent columns remain zero in stock grid and do not independently seed the transform. Pinned Maurer kernel is unchanged. Its keep mask is stock keep AND squared integer XZ distance at least radius squared; equality alone never resurrects stock-removed spans.
- **Budget/transaction:** span/padded-cell/radius/work/scratch caps stay bounded. Declared scratch includes three padded byte masks, int64 grid/two lines, original areas, topology copies and nine 64-byte allocation reserves. It is not an allocator/RSS bound. Partial allocation failures remain destructible and consume preparation. Apply consumes readiness on every attempt; topology/area validation and kernel success precede the first area write. Refusals preserve apply-entry areas, not pre-stock-erosion areas. Receipt counters/status may change on failure as documented.
- **Reuse/isolation:** new class and receipt are distinct research symbols. Referenced flat helper, disk veto, integer kernel, Recast sources, licenses and C ABI remain unchanged. The tracked diff against published base contains only `research/recovery-checkpoint-20261029/README.md`; all new work is under separate research directories. No active app, policy/default, Swift wrapper or build-path edit was observed.

## Finite fixture and admission review

The authored 7 shapes x 3 radii plus two null-center ripple cases total 23 masks. Refusals total 1 pre-prepare apply + 13 malformed preparations + 3 budgets + 20 apply mutations = 37. Source uses unchanged stock erosion, freezes stock output, checks all original seeds, compares present-span final bytes against an integer all-seed oracle, checks receipt counts/topology bytes and rejects second apply. Pointer-mutation fixtures restore ownership before fixture destruction. Original seed packing is a separate test implementation, not independent real-world geometry evidence.

The test plan requires one serial compile/execution, aggregate 60 CPU seconds/120 wall seconds/512 MiB memory and output cap, no installs/network, whole-process-group termination and exact compiler/source recording. These enforcement mechanisms were not executed or verified here. Admission must stop if they cannot be enforced/observed; `timeout` alone is insufficient. Every failed run requires a new reviewed checkpoint before retry.

## Coverage gaps retained before adoption

The first suite is deliberately finite. Allocation-failure injection for all nine helper allocations, malformed dimension/cap boundaries, near-budget cases, direct area-revival/relabel refusal fixtures, mutation of every metadata/receipt field and field-owner identity, and a pure overlap-only failure with each individual h valid remain further coverage. The current below-height fixture exercises the stronger all-span rule, not an isolated proof of the edge-overlap branch. Minimum-clearance positive center is connected, not a disconnected-ceiling fixture. Actual `rcBuildCompactHeightfield` integration, additional sanitizers/platform compilation, qualified callers and fresh sensor/full-body/support/current-hazard evidence remain mandatory separate gates. No synthetic pass would establish continuous 3D clearance or safe child use.

## Actions and restrictions

Performed read-only source/diff inspection and lightweight Python SHA-256/JSON consistency checks; wrote only this review and its hash record in the research directory. All nine published pins and all five final candidate manifest entries matched. `git diff --check` reported no tracked patch whitespace issue (new untracked candidate files are not covered by that command).

No native compilation, executable/test run, dependency install, download, Docker/container, API/model call, app edit, commit, push or workflow dispatch was attempted. No tool permission denial occurred. Execution results, compiler compatibility, actual memory/time behavior and remote publication remain unverified and must not be inferred from this review.

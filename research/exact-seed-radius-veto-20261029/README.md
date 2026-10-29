# Exact seed-radius veto — research preservation, not integrated

**Stage A passed:** one compiled C++ helper-fixture execution, 20 ordered semantic groups (eight distinct output labels), including exact stock post-erosion areas and every frozen mask bit for six full layouts. **The production C ABI build, Swift bridge/runtime tests, Apple discovery and 50-control/25-candidate route matrix remain untested for this candidate. No caller is activated.**

This directory preserves authored source and aggregate evidence only. The patch and `candidate/` files are **inert review material**, not applied production code. Base: `2c390d9c5096bba7af6d34c33329a9dc55a375b6`. The original private candidate manifest is `b09393d2e7f9ba3ec69a26259fa077cd09782e6390094c65d94b385ae1cdde4e`.

## What the adapter does

Stock Recast's 2/3 chamfer erosion can retain cells inside the exact integer seed radius. The minimal opt-in adapter retains stock-kept cells only if no original seed offset satisfies `dx² + dz² < R²`; **equality is retained**. R remains the original `ceil(radius/cell size)`. It captures pre-erosion null/missing-cardinal/null-neighbor seeds plus the frozen one-cell outside perimeter. Absent columns are not new seeds or candidates. It does not promote cells, change body margins/contours, propagate new seeds, replace Recast/Detour or introduce an EDT dependency.

The supported domain is a single common quantized height, at most one span per column and valid reciprocal cardinal connections. Unsupported topology or insufficient allocation/work budget returns a typed refusal with no stock fallback. Bounds include 250,000 columns, 65,536 spans, radius at most 80 cells, 2 MiB helper allocations and an explicit ceiling of 10,000,000 offset tests per build. These are bounded-work claims, not device timing guarantees.

Stock defaults, recovery/quarantine/snapshot lifecycle checks, strict endpoint rules and existing legacy diagnostic expectations remain unchanged. The optional exact policy requires classified floor support and strict endpoint admission. **This is a discrete mask correction, not continuous source-wall clearance, full-footprint support, live-obstacle or navigation-readiness proof.** Every new receipt denies physical authority.

## Preserved source and evidence

- [Candidate patch](CANDIDATE.patch) and five byte-pinned inert sources in `candidate/BlindRoomMesh/`.
- [Original reviewed manifest](REVIEWED_CANDIDATE_MANIFEST.json), [base pins](BASE_MANIFEST.json), and [44 unchanged upstream/license/include pins](UNCHANGED_UPSTREAM_PINS.json).
- Authored C++ fixtures, lossless input-preparation code and five **unrun** Swift runtime/C-ABI tests in `tests/`.
- [Source review](reviews/SOURCE_REVIEW.md), [launch review](reviews/STAGE_A_LAUNCH_REVIEW.md), and [actual-result reconciliation](reviews/STAGE_A_RESULT_REVIEW.md).
- [Aggregate Stage A result](stage-a/AGGREGATE_RESULT.json), [complete fixture stdout](stage-a/fixture.stdout.txt), [compiler executable pins](stage-a/COMPILER_PINS.json), and [six-layout identity/count metadata](FIXTURE_PREPARATION.json).

Stage A used one CPU: 1.379597 aggregate CPU seconds, 1.404393 wall seconds and 83,492,864-byte conservative observed aggregate RSS. All 74 workspace input pins and five compiler/helper executable pins matched before and after. Compiler and test exits were zero, with empty stderr. RSS was sampled with peak-rusage fallback, not a kernel hard aggregate resident-memory quota. Compiler binary pins are not a full SDK/shared-library attestation.

The frozen [pre-execution plan](PRE_EXECUTION_APPLE_PLAN.md) and source reviews remain historical records; their “native unrun” statements describe their original checkpoint. Stage A's later result is added separately, not retroactively inserted into the old proof. Stage B/C and caller integration remain pending.

## Deliberate publication exclusions

No derived source geometry, full compact-field arrays, keep-mask arrays, captured room data, native binary/object/archive, runtime executable, admission token, or private absolute-path command log is included. Fixture code reads separately authorized local inputs; their hashes/counts are not redistribution permission. The original reviewed manifest names excluded private artifacts so provenance is retained, **not** so this public directory can be mistaken for the complete private execution packet. Local `coordination/` paths in historical reviews are provenance references, not published artifacts.

The upstream code/license remains unchanged under its existing provenance. This local adapter has source review and bounded helper-fixture evidence only; it is not claimed upstream-reviewed, battle-tested, iPhone-tested, safe for independent use, or ready to issue physical guidance. Further integration/execution requires separate review and root admission. The seated iPhone build has priority and is independent of this preservation packet.

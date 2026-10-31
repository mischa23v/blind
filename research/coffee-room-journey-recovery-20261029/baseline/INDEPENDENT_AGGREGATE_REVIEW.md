# Independent Coffee aggregate adapter source review — 2026-10-29

**No remaining source-review blocker to root's separately admitted single trusted baseline compile/query replay.** No Coffee native compile, query payload or guard was executed by this reviewer. This decision is not a result, navigation acceptance or safety authority.

Frozen SHA-256:

- `run_aggregate.py`: `37beada6679b871c6d9edf20e530f017f0999f69e1e037146210067a33cc75ae`
- `COFFEE_RUN_PINS.json`: `516562e86812c9eca3c688087fd471473bdc8f9f1d398a02604ee9fbf3c44abc`
- `AGGREGATE_GUARD.md`: `10c0494a121abcb5ad9627b48304f2b14a6b0fb6145e5d53163d80d4775ed54d`

## Focused checks

Reviewed the complete diff against the already executed heightfield guard `c4dc7b1c9b438d5199114339447b089293dc7741fc674a3d743577c1c89968e5`, plus the historical query/imported loading path and command manifest. Independently checked every one of 67 pinned inputs as a regular matching file. The prepared tree contains exactly the 58 prepared inputs, totaling 11,682,659 bytes; none is omitted from the manifest. Python AST parse succeeds without importing/executing the guard.

A final portability/privacy change replaces prepared-workspace prefixes with `@PREPARED@`. Independently rechecked deterministic expansion to the repository parent plus `coffee-native-replay-prepared`: all 67 pins still match, all 58 prepared files remain covered, compiler argv still matches BUILD_COMMAND except resolved compiler, and query path is identical. No source bytes, query parameters or command semantics changed.

Root path indexing resolves to the intended repository; work paths are frozen in the committed manifest. Before/after input verification and committed-manifest equality remain intact. Existing GUARD_RUN, ADMITTED_RUN, library and query outputs refuse prior to compilation; all were absent at review. Original source files and expected reference results remain immutable inputs.

Compile argv matches prepared BUILD_COMMAND.json except for resolving the compiler executable to its pinned absolute path. The compiler directly builds the new shared library. The guard hashes it before queries and verifies it again afterward. Historical run.py uses ctypes through the reviewed native binding; no subprocess, new-session or nested runner is launched. The superseded run_admitted.py is not invoked. Bytecode output is disabled. No alternative policy, mesh transformation, exclusion geometry or query retuning is introduced.

Nine authored endpoint coordinates produce 9*8 = 72 directed non-self queries. The guard requires 72 unique start/goal pairs, identical requested endpoint/config values, and exact equality of saved endpoints, queries, meshCounts and nativeMarkedExclusionSpans against immutable historical results. Timing/RSS and regenerated provenance hashes are intentionally not historical equality targets. Mismatch fails rather than being repaired or relabeled. This is a topology/query replay, not a moving actor or full room journey.

The minimal adapter changes caps to aggregate 120 CPU seconds, 180 elapsed seconds, 1 GiB observed RSS, 64 MiB for the entire prepared working tree and one CPU affinity. Compiler/query run serially; temporary files reside inside the accounted tree. Historical run.py sets its own (120,120) CPU rlimit, so the adapted per-process backstop preserves that value while the supervisor enforces aggregate remaining time. The historical 2 MiB query-folder check remains. Receipt cap/reserve is 256 KiB within the unchanged 64 MiB tree budget, accommodating repeated 58-file inventories/pins rather than truncating evidence.

Inherited bounded no-follow descriptor scans, strict terminal inventories, unexpected-child rejection, observed group retirement, safe receipt writing, failure evidence, no-retry semantics and final resource/pin accounting remain unchanged in purpose. GUARD_RUN/RESULT.json is excluded from payload hashes only, not byte accounting. No prior heightfield guard/result file was modified.

## Evidence boundaries retained

This is a trusted workload observer, not a hostile sandbox: sampled RSS/CPU/output may overshoot or miss transients; blocked system calls/external supervisor kill can prevent complete cleanup/evidence. Selected compiler/Python inputs are pinned, not every OS/library/NumPy implementation. Historical runtime equality is explicitly not established. These limits must accompany eventual results.

The original Coffee OBJ is used in original XYZ with a candidate Y-up interpretation; source scale, camera alignment and room semantics at the nine authored points are not validated here. No camera evidence is consumed, no current obstacles/support/body trajectory is evaluated and no physical guidance/app activation follows. Exact baseline reproduction would not qualify the new single-span-heightfield policy or prove usable room navigation.

Only source/diff/hash/AST inspection was performed. No compiler/guard/query execution, install, download, push, app edit or permission escalation occurred; no tool denial occurred. Root owns exact-commit publication, admission and later result review.

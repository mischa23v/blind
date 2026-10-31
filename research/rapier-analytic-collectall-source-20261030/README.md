# V3 collect-all analytic assertions: prepared, not executed

This packet supersedes only the fail-fast reporting behavior of V2. Attempt001 at source commit3be40379c861e8a580643f2cdbec69a6164b5a9a failed on the horizontal-margin/raw-trimesh 1cm down-step after52 completed wrapper checks. That failed result remains preserved separately. There is no new successful engine result.

All fixture geometry, initial poses, numeric expectations/tolerances, exact package, engine adapter, body/margin, limits and runtime permissions remain unchanged. Only geometric fixture assertion failures are collected. Each independent wrapper still owns/frees its own world. Structural/API, mutation, authority, call-budget and resource errors still terminate immediately. Raw rows stream before assertions. A new assertion-results.jsonl stream records each wrapper's unchanged assertion verdict and reasons. The worker and aggregate both remain failed and return nonzero if any original fixture assertion failed, even after all72 wrappers/108 rows/104 calls complete. Full inventory and failure totals are verified before the aggregate reports the expected failure.

The sole new work directory is rapier-analytic-controls-attempt-002. This is a fresh experiment, not a resumed or altered attempt001. Never-run controls remain unrun until root reviews, publishes and executes this packet. No room queries are admitted.

See COLLECT_ALL_CHANGE.diff and SOURCE_PREPARATION.json for the exact diagnostic-only changes and source-only checks. All original package/API/frame/safety limitations continue to apply; REAL_ROOM_PROTOCOL.md and RUNTIME_CONTRACT.md retain those details. The original full source rationale is preserved in ../rapier-analytic-comparator-source-20261030/README.md.

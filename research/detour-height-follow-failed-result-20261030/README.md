# Detour height-follow attempt 001: recording-budget failure

Actual source: `1521e1af78606cbf716d8209adef2da9294b05ee`; source freeze SHA-256 `e02170937778950e2eda06e357f32f71c1630db8753d8c8e86a2db4399af49ab`. Local run: `detour-height-follow-attempt-001`. This packet preserves the failed attempt; it does not replace its source, evidence or limits.

## Terminal evidence

- Aggregate **failed**: 79.853469 CPU seconds, 79.894916 wall seconds; observed aggregate peak RSS 197,959,680 bytes. The RSS guard is sampled, not a hard cgroup bound; no address-space rlimit was applied. Original guard receipt and limitations are copied unchanged.
- Compilation and height worker exited **0**. All **3,696** scheduled local native-height events were valid: Conference 2,052; Coffee 1,644. This confirms the fixed schedule can retain released local polygon-height state, not that a person moved, had support, avoided obstacles or arrived.
- VTK worker exited **1** at its frozen **64 MiB uncompressed evidence budget**. The final catalog-size check raised another exception during cleanup and masked the first as the terminal error. Both exceptions remain in `vtk.stderr`. No final triangle catalog or VTK summary was written.
- Streaming stdlib audit found **29,069 of 29,568** expected complete JSON records, **499 missing**: Conference 16,416, Coffee 12,653. Saved decompressed bytes: **67,107,620**. Gzip was readable through EOF; the compressed stream itself is not corrupt. A query may have executed immediately before its row failed the writer limit; saved rows must not be represented as a complete executed-query count.
- Raw gzip retained locally, not copied into this packet: 2,228,166 bytes; SHA-256 `87763475a58525523340dd33f1380c7bd8cf90fd5a4f73f3b4d6ce79a2ced950`. Original height-events SHA-256: `c1c0abfd3ee792da4f0c06e257aec17d67cf8f12e19ab571fa6442335f746c57` (4,364,308 bytes). `GUARD_RESULT.json` retains the original inventory and all input pins.

## Meaning and next work

This is an **evidence-recorder failure**, not a failed native-height association, an impassable-room result or a completed collision comparison. Partial contact rows are preserved but do not justify a full-route collision verdict. There were **zero applied physical movements**; support, semantic floor, arrival and physical clearance remain unestablished. App defaults and geometry were not changed.

Repair logging in a separately frozen source/attempt: retain the first failure and always write a bounded failure summary; account for catalog storage before exhausting the stream budget; preserve every required contact ID without silently dropping late rows or changing geometry. Review and publish that source before execution. This historical attempt remains failed even if a later recorder succeeds.

`PARTIAL_AUDIT.json` is reproducible with Python's standard library only:

```sh
python -B -I research/detour-height-follow-failed-result-20261030/audit_partial.py /path/to/detour-height-follow-attempt-001
```

The guard receipt, height summary and stderr files are byte-identical copies. No native code, geometry query or archive upload was performed for this audit.

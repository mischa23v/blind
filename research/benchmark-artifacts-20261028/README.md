# Preserved benchmark outputs

Derived outputs only; no raw photographs, raw depth, mapper databases, original FARO mesh, runtime dependencies or credentials. These research artifacts do not establish navigation safety.

`ARCHIVE_RESTORE_INDEX.json` preserves the original archive byte counts, SHA-256 hashes and per-member hashes. Larger archives may be stored as `.part001`, `.part002`, etc. These are consecutive raw byte slices, **not** independent gzip archives. No recompression, repacking or geometry transformation occurred.

## Restore

From a repository checkout, use Python 3's standard library:

```sh
python research/benchmark-artifacts-20261028/restore_benchmarks.py --repo-root . --output /tmp/blind-restored --archive ARCHIVE_NAME.tar.gz
```

Omit `--archive` to reconstruct all complete archives. The helper verifies every object, ordered concatenation, the original SHA-256 and Git blob SHA. It refuses missing/incomplete inputs and existing output files. It performs no downloads and does not extract tar files. Extract each verified archive into a **separate** temporary directory and verify members against the index before selectively restoring paths. Never mix root-level provenance metadata between archives.

Preserve MuSHRoom Koivu attribution and applicable dataset terms. Private storage does not grant permission to redistribute source scans. Engine/source versions and licenses remain in the recorded protocols. RTAB/OctoMap/Open3D outputs are separate experiments, not interchangeable app-ready navigation maps.

The range-5m reports archive is a dated snapshot; its independent-review paragraph predates the final review. Do not replace `research/geometry-range-audit-20261028-1836/` with that older snapshot.

## This checkpoint

Confirmed binary objects: 30. Complete original binary files: 23/23 (22 archives plus one image).


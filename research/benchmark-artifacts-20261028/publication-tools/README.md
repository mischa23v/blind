# Publication integrity tools

Standard-library Python tools used to prepare the benchmark archive publication. They do not call GitHub, install dependencies, extract archives, run geometry pipelines, or mutate Git refs.

## Reproduce the tests

```sh
cd research/benchmark-artifacts-20261028/publication-tools
python -B -m unittest -v test_assembler.py
```

The 25 synthetic cases cover complete and partial uploads; explicit returned-SHA confirmation versus merely computed hashes; conflicting SHA fields; original/part/concatenation corruption; ordered parts; missing receipts; safe restore paths; temporary-file cleanup; and refusal to overwrite existing outputs. These are transport/evidence tests, not Apple-native, geometry-accuracy or navigation-safety validation.

## Restore the actual published archives

Use `../restore_benchmarks.py` and `../ARCHIVE_RESTORE_INDEX.json` from the same publication checkpoint. The index keeps original compressed-byte and member hashes. Part files are raw consecutive slices, not standalone compressed archives. The helper reconstructs and verifies without extraction.

## Reproduce publication preparation

```sh
python -B assemble_binary_publication.py --input-dir /path/to/local-publication-inputs --output /path/to/new-snapshot --require-complete
```

Inputs are a hash-pinned `PUBLICATION_MANIFEST.json` with file records (`repoPath`, consumer-local `localPath`, `bytes`, `sha256`, `gitBlobSha`, `mode`, `encoding`), its original `ARCHIVE_RESTORE_INDEX.json` member inventory, and the batch receipts and optional split manifests. The original manifest row pins the source index's bytes, SHA-256 and Git blob SHA. Rebind local paths to actual files in the consuming workspace; local transport scratch paths are intentionally not published.

Receipt inputs are `BINARY_BATCH_{1,2,3}_RECEIPTS.json`, optional `BINARY_BATCH_*_ROOT_RECEIPTS.json` and `BINARY_BATCH_*_REASSIGNED_RECEIPTS.json`. A receipt is an array or `{repo, receipts:[...]}` of pinned identity records plus explicit successful returned GitHub SHA and status. Pending/uncertain receipts never authorize a tree SHA. `ROOT_CONFIRMED_BLOBS.json` retains the one separately confirmed probability-tree receipt used by this run; it is historical evidence, not an instruction to upload.

Split inputs are `BINARY_BATCH_{1,2,3}_PARTS.json`: `{repo, originals:[originalIdentity + {parts:[ordered local part identities]}]}`. Parts must use contiguous `.part001`, `.part002`, etc., each at most 8 MiB. Every part and concatenation is independently hashed before accepting upload receipts. The original SHA-256, Git blob SHA and member inventory are never replaced by part hashes.

Successful output contains binary tree entries only for explicitly confirmed remote blob SHAs, separate inline-content metadata entries, a preserved/extended restore index, README and restore helper, plus local input/output-hash receipts. Partial snapshots are explicit. `--require-complete` exits 2 when any original remains incomplete; validation errors exit 1. Existing snapshot directories are never overwritten.

Blob upload success does not prove branch publication: independently verify the resulting commit and full recursive tree after publication. Choose the latest intended base tree and check path conflicts outside this tool. No raw data, credentials, base64 transport files or dependency/runtime bundles are part of this source package.

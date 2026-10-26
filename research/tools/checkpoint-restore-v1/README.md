# Offline checkpoint verifier and missing-file restorer

Small standard-library Python tool for our seven published research checkpoint ZIPs. **Dry-run is the default. No network requests, execution of restored code, broad repository extraction, or app installation.** `INDEX.json` pins GitHub commit/path and archive SHA256 from existing verified publication receipts. These are prior verified publication records, not a fresh network check.

## Use

Acquire the exact ZIP yourself using its commit-pinned link in INDEX.json, then select an existing workspace directory:

```
python checkpoint.py roundtrip /path/to/verified-assisted-roundtrip.zip --workspace /path/to/research-workspace
# After reviewing the report, explicitly restore validated missing files:
python checkpoint.py roundtrip /path/to/verified-assisted-roundtrip.zip --workspace /path/to/research-workspace --restore
```

Checkpoint IDs: `stage43`, `loop-support`, `entry`, `roundtrip`, `loop-code-and-results`, `loop-memberships-0-2`, `loop-memberships-3-4`. Run all three loop parts against the same workspace; the shared manifest is filtered by its explicit group. The archive-root `MANIFEST.json` is metadata only and is **never restored**, avoiding clobbering it across parts. Nested experiment manifests are ordinary checksum-verified files.

All archive and member hashes, sizes, destinations and membership are checked before writing. Absolute/traversal/backslash paths, duplicate ZIP or manifest names, symlinks, nonregular members, encrypted members, unlisted or missing members, and mismatched hashes are rejected. Existing identical files are left untouched; a divergent file aborts the operation before writes. Restore uses exclusive creation and no-follow directory handles; it never overwrites an existing file. Run against a private quiescent workspace, not a directory concurrently moved by another process.

Restoring is not a transaction across every file: I/O interruption can leave already restored validated files and/or an incomplete new file. A subsequent dry-run detects divergence rather than replacing it. Resolve that file explicitly yourself. Archive permissions are not applied: new files use private mode0600. No executable is run.

Limits:128MiB per member,512MiB total expanded archive. Reading/checksumming uses streaming for the archive and existing files; individual ZIP members are read within the member cap. Ensure adequate free disk before explicit restore. This tool does not copy large pinned raw dependencies or solve their acquisition.

## Reproduction dependencies

The report inspects dictionary-style `files` SHA256 pins in included `FROZEN.json` records, reporting absent, mismatched and conflicting historical dependencies separately. It does **not** claim to discover every script's imports, every alternative manifest format or runtime dependency. These compact packets are not standalone: prior source Polycam/FARO assets, native libraries, earlier checkpoints and Python dependencies may still be required. Conflicting historical pins can legitimately refer to earlier versions and are not silently resolved. Restore does not require dependency availability, so evidence can be recovered even when execution cannot yet be reproduced.

## Verification performed

`PYTHONDONTWRITEBYTECODE=1 python test_checkpoint.py`:12 lightweight synthetic fixture groups pass, covering default no writes, explicit restore/idempotence, hashes, traversal, duplicate/unlisted/missing entries, symlinks, divergence-before-any-write, multipart manifests and missing dependency reporting. No real archive was extracted or copied for these tests. The archive list is based on local publication receipts; the tool intentionally does not download ZIPs.

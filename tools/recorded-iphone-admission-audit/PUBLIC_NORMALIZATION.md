# Public-normalized evidence copy

This is a separately identified presentation/source cut. The frozen original packet and private runtime evidence remain unchanged. `ORIGINAL_PUBLICATION_MANIFEST.json` preserves the original payload inventory. `PUBLIC_NORMALIZATION.json` maps every original payload path and SHA-256 to this public copy and identifies changed files. The enclosing `PUBLICATION_MANIFEST.json` hashes the complete current public payload, including these added notes/checks.

## Path and hash semantics

Absolute execution-workspace prefixes in copied prose, logs and JSON receipts are replaced by `$WORKSPACE` (the directory holding the audit/dependency workspaces) and `$SHARED` (the directory holding shared compiler/core prerequisites). These are literal presentation placeholders in JSON/logs, not newly observed runtime paths. Standard public upstream example paths and system library locations are not private workspace prefixes and remain unchanged.

All historical source, data, module, binary and receipt hash values are preserved. A historical field such as `sourceDataPinsSHA256`, `protocolSHA256`, a source-file pin or build-log hash identifies the ORIGINAL bytes used in that historical execution, not a normalized display copy. Use `PUBLIC_NORMALIZATION.json` for the public counterpart's hash. Normalizing a receipt does not create a new run or change the original provenance chain. The original receipts are not silently re-signed with replacement hashes.

Internal coordination prose is changed to maintainer/protocol-review wording. Technical `.parent` operations and upstream license/source files are unchanged. Original historical limitations and later discoveries remain separate; no stage is retroactively presented as knowing a later result.

## Verification boundary

The public-copy checks verify the frozen originals, source syntax, all preserved historical hash strings, absence of raw/binary assets and executor-specific paths, and byte-identical license/vendor/production source cuts. No download, decoder build, Swift compilation, production invocation, geometry evaluation, detector call or navigation run occurs during publication normalization. No extra frames or independent journeys are counted.

## Configurable public wrapper cut

Only `run_audit.py` and `check_intrinsics.py` change executable configuration: explicit absolute `WORKSPACE` (audit/data/dependency directories) and `SHARED` (shared prerequisites for the driver) environment variables replace the old machine-specific location assumptions. The driver shell-quotes the configured toolchain environment path. Both scripts refuse to overwrite an existing historical result. For a separately authorized future full rerun, copy only the required scripts, `AdmissionAudit.swift` and `PROTOCOL.md` into a clean work directory first. Prerequisites must already be installed/built and match the recorded hashes; this packet does not install them.

The new read-only checker can run directly against this packet:

```sh
# Set WORKSPACE and SHARED to your own existing absolute prerequisite roots.
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 python verify_public_inputs.py
```

It verifies the existing native source/module/binary and original decoded inputs, then independently recounts exactly frames 0–7 against the historical production output. It never invokes the compiler or any native library. The new source cut received syntax/configuration/preflight/recount checks; its full compile/launch path was NOT rerun. Therefore no claim of an independently reproduced native execution is made for the modified wrappers. `PUBLIC_PORTABILITY_CHECK.json` records the actual bounded checks.

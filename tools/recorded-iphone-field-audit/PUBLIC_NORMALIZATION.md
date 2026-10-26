# Public-normalized evidence copy

This is a separately identified presentation/source cut. The frozen original packet and private runtime evidence remain unchanged. `ORIGINAL_PUBLICATION_MANIFEST.json` preserves the original payload inventory. `PUBLIC_NORMALIZATION.json` maps every original payload path and SHA-256 to this public copy and identifies changed files. The enclosing `PUBLICATION_MANIFEST.json` hashes the complete current public payload, including these added notes/checks.

## Path and hash semantics

Absolute execution-workspace prefixes in copied prose, logs and JSON receipts are replaced by `$WORKSPACE` (the directory holding the audit/dependency workspaces) and `$SHARED` (the directory holding shared compiler/core prerequisites). These are literal presentation placeholders in JSON/logs, not newly observed runtime paths. Standard public upstream example paths and system library locations are not private workspace prefixes and remain unchanged.

All historical source, data, module, binary and receipt hash values are preserved. A historical field such as `sourceDataPinsSHA256`, `protocolSHA256`, a source-file pin or build-log hash identifies the ORIGINAL bytes used in that historical execution, not a normalized display copy. Use `PUBLIC_NORMALIZATION.json` for the public counterpart's hash. Normalizing a receipt does not create a new run or change the original provenance chain. The original receipts are not silently re-signed with replacement hashes.

Internal coordination prose is changed to maintainer/protocol-review wording. Technical `.parent` operations and upstream license/source files are unchanged. Original historical limitations and later discoveries remain separate; no stage is retroactively presented as knowing a later result.

## Verification boundary

The public-copy checks verify the frozen originals, source syntax, all preserved historical hash strings, absence of raw/binary assets and executor-specific paths, and byte-identical license/vendor/production source cuts. No download, decoder build, Swift compilation, production invocation, geometry evaluation, detector call or navigation run occurs during publication normalization. No extra frames or independent journeys are counted.

All executable Python and official decoder source files in this stage are byte-identical to the original packet. They derive file locations from their own script directory and contain no executor-specific workspace root. No rebuild or decode rerun was needed or performed for prose/receipt/log-only normalization. `PUBLIC_PORTABILITY_CHECK.json` records syntax/content checks only.

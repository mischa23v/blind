# Optional worker CPU metadata: bounded CI integration

Extends only the existing synthetic marker extraction in native-apple.sh. The exact new CPU fields, closed lanes/Booleans, nonnegative integer or -1 sentinel and records0–64 are whitelisted; output is capped64lines/2000characters perline. This is syntax-bounded diagnostic evidence, not independent CPU correctness verification. Missing/truncated/unsupported samples remain unknown. They do not change test status, expected tests, timeouts or success criteria.

Old marker stage lists gain exactly workerFinished and requestRetired, retaining the previous caps. Six actual-shell mutation/bounds tests pass both normally and with Python optimization, plus the previous five marker tests. All extraction paths use the original command exit status; no late-message flush, sleep or callback wait is added.

The new reversible stage85 helper patch restores the exact ceaaa helper before existing historical layers. Explicit CURRENT dependency manifests are refreshed to the four reviewed source hashes; historical manifests remain untouched. This checkpoint is not a native compile or runtime pass. UI diagnostics, geometry defaults and policy activation are outside this packet.

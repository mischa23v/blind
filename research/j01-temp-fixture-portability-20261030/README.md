# J01 preflight fixture portability — model not run

[84eb run 41102779317](https://github.com/mischa23v/blind/actions/runs/41102779317/job/124223554874)
failed in `integrated/check.py` before native build or model execution. The failed
portable command was `test_build_attestation.py`. The checker captured but did not
emit its inner stderr, so the exact CI inner exception is unavailable. The final
J01 receipt says `unavailable` / `no_terminal_runner_receipt`.

## Reproduced defect and limits

Exact baseline bytes pass all 22 attestation tests using canonical temporary paths.
With the same source and a deliberately symlinked `TMPDIR`, all 22 fail during
fixture construction with `ValueError: symlink component refused`. This supports
a temporary-path alias incompatibility as a likely macOS preflight cause; it does
not prove that was the hidden CI exception. The adjacent runner suite has the same
fixture-path defect. No model assets, runtime downloads or alternate provider are
used in this investigation.

## Narrow repair

Only test-owned temporary roots are canonicalized after creation. Production
`build_attestation.py`, `j01-actual-model.py`, file/path refusal, deadlines, source
attestation and model-observation criteria remain byte-identical. Added positive
alias-temp tests also explicitly prove that an aliased runtime input remains
refused. Existing bundle-file and directory-symlink negative controls remain.

The integrated checker now emits closed diagnostic metadata before preserving
the original failing assertion: failing test identifier, exception class, and the
single recognized symlink-refusal reason. It reads at most the final 16 KiB / 96
stderr lines and emits at most 24 records. Arbitrary messages, paths, environment,
stdout and model text are not emitted. The formatter has executable privacy and
bound checks and is included in the existing portable-contract loop.

## Verification

Candidate portable suites pass **23 attestation + 39 runner + 10 metadata + 4
formatter tests**, separately with canonical and deliberately aliased temp roots.
These are synthetic/source tests, not native builds or model observations.
Preserve the failed84eb run. The next exact-source native preflight remains required;
no model, whole-journey or device success is inferred from this repair.

Ordered provenance must be added as a new layer; historical fixture pins and
reversal evidence must not be silently replaced.

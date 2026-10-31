# Isolated Apple execution plan — 2026-10-27 21:36 UTC

**Prepared only; no workflow installed, published or launched by this increment.**
The parent task requested this plan under the project's already-authorized testing
scope after independent source review. The parent owns final workflow review,
publication and execution. This is not permission to adopt stage86 in the app,
start live copying, install/launch a simulator/app, or change native-owner gates.

## Reviewed input and preserved history

The pre-workflow source review passed 188 portable static contracts, 47 proposal/
dependency/app-observation pins, 16 synthetic diagnostic-parser controls, the
unchanged 42-check stage83 checker and all 55 stage75 native pins. Both review
findings (initializer-diagnostic wording and runner-budget wording) were resolved.
These are **not Swift execution results**. The immutable original receipt and pin
manifest are retained in `history/pre-apple-workflow-20261027/`; that old manifest
describes the source-review cut, not today's changed workflow/checker/documents.
Its manifest SHA256 is `39a6a8788d8ed42cac850dd07660bc900211ecf01e8280ec2afe6ddd44a725d3`.
The current `SOURCE_PINS.json`/`STATIC_RESULT.json` identify this later plan cut.
Swift sources, tests and the Apple runner are unchanged by this workflow increment.

## Proposed lane

`apple/workflow-proposal.yml` is outside `.github/workflows`. After review, the
parent may install its exact bytes as
`.github/workflows/origin-bound-ingress-proposal-86.yml`. The checker accepts either
an absent installed file or that exact reviewed copy; other stage86 workflow
references are rejected. No action is installed automatically by a checker or script.

- Repository must be public `mischa23v/blind`, on
  `codex/recovery-hazard-order-20261027`; push paths are restricted to the candidate
  sources/dependencies and this workflow. Manual dispatch has the same job guard.
- Checkout/upload actions retain the established full-SHA pins. Checkout keeps no
  credentials and fetches one revision, without LFS/submodules. Token is contents-
  read-only; no write/PR/deploy permissions or third-party action is introduced.
- Existing `xcode-27`/Xcode27.0 runner selection; 25-minute enclosing job and
  23-minute execution step. Command explicitly passes `--execute-authorized-apple`.
  Per-command CPU/file/scratch/native-worker limits remain exactly as documented
  in `APPLE_HANDOFF.md`; no retry, timeout extension or cap relaxation.
- Reuse actual stage83/75 native SwiftPM compatibility products once per target.
  Run separate stage83 and stage86 host fixtures, four relevant negative compiler
  checks after positive signatures, and stage75 public/lifecycle/discard regressions.
  Compile/link actual ARKit simulator source without launching the simulator.
- Upload only `*-receipt.json` at the bounded scratch root, original stage83
  `RESULT.json`, `STAGE86_RESULT.json`, and explicit stage75
  `stage86-stage75/RESULT.json` plus `RUNTIME_RESULT.json`. Receipts already retain
  bounded diagnostic tails. No `*.log`, recursive tree, input fixture, geometry,
  binary, cache or `ROUTE_DIAGNOSTIC.json` upload. Artifact retention: three days.

## Outcome and stopping conditions

Preserve failures/timeouts and stop at the first failed required stage. Missing
`STAGE86_RESULT.json` is not success; earlier stage83 success does not stand in for
stage86 completion. Record the observed fixture result, relevant negative diagnostic
witnesses, actual simulator compile outcome and exact source revision separately.
Do not transfer historical counts into an unrun stage or rerun after increasing caps.

At authoring: workflow uninstalled/unlaunched; Swift/Apple fixtures unrun; native
origin unproven; app remains diagnostic-flag fenced, default-off and no-copy. The
historical audit still intentionally fails its old NavigationModel hash pin; this
workflow does not repin it. Even a later complete pass establishes synthetic API/
native-package compilation behavior only. README N1–N6 native owner/device gates
and N7 physical-guidance authority remain independently open.

# Coordinated native source membership — 2026-10-28

Root authorized adoption after an independent read-only review of the three N00 hosted test methods. This stage changes only generator/project membership and the exact reversible historical-proof layer. Test implementation and preview implementation have separate owners/manifests.

## Changes

- App sources: 61 → **62**, adding only `RecordedRoomRoutePreview.swift`.
- Hosted test sources: add `KoivuSourceAnchorBenchFixture.swift` and `ConnectedNavigationBenchIntegrationTests.swift`, byte-identical to independently reviewed research candidates.
- No source removed; no package/framework dependency, build setting, flag or workflow changed.
- `connected-bench-preview-membership.patch` is reversed **before** `project-canonicalization.patch`, restoring exact pre-membership project SHA `e80ced174477574a28b45c594e2a10029d14da9c6ef588845a93f9eab3321cd1`, then prior 5aa44 and original stage85 proof. Historical patches remain untouched.
- Current PBX SHA: `cee0cbac7dc54bba1ba5845b6d901f00b32afaa44e1647c0fca73490c59142a1`.

## N00 independent source review

No blocking API mismatch found in the reviewed candidate. SavedWorldFrame fixtures use valid UUID identifiers. Main-actor async tests yield while actual import/runtime callbacks finish; the isolated actor IO follows the existing protocol pattern. Missing-support rejection checks the exact enum after successfully obtaining an issuer candidate, avoiding a false pass from an earlier owner failure. The Koivu case explicitly lacks registration, edges and floor support and expects a refusal, not movement. The authored validator/explicit acceptance call exist only in tests. Fake speech/beacon output is not the full live NavigationModel permission chain; the candidate README discloses that limitation.

This is a **source review**, not Swift compilation. Native concurrency, fixture runtime success and device behavior remain unverified until existing CI runs. No toolchain/build/download was requested or executed.

## Reproduction/results

From repository root:

```sh
node research/localization-contract-review-20261028/native-membership-stage/check-membership.mjs
python3 research/native-candidate-app-integration-85/integrated/check.py
node --test tools/test/mesh-package-project.test.mjs tools/test/room-reference-photo-trash.test.mjs tools/test/selected-photo-reference.test.mjs
```

- Membership source checker: exact generated equality; only three approved new paths, no removals, preserved package/settings, actual hosted files equal candidates.
- Integrated checker: **42/42 source checks pass**, including all exact historical reversals.
- Bounded generator/photo source regression suite: **28/28 pass**.

`project-before.txt`/`generator-before.mjs` preserve the exact pre-adoption sources. The earlier `pbx-diagnostic/` records remain historical receipts for the 61-source state; its old fixed-count checker is superseded for the current source tree by this stage's checker, not relabeled as a current result. Source checks must never be counted as native XCTest passes.

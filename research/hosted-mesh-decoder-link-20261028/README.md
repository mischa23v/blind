# Hosted decoder81 link repair — 2026-10-28

Parent: `4eb0d10f1724bce3ef2f6e6a8ff8ae35a06b85e6`. Native run [40721822359](https://github.com/mischa23v/blind/actions/runs/40721822359) failed while linking `ClassificationIngressTests.o`; hosted unit/UI summaries contain zero cases. The exact evidence remains in `../native-path-recovery-20261028/run40721822359/`. No same-export public geometry was captured, and no classification behavior was tested by that run.

## Cause and narrow correction

The earlier classification integration's assumption that no direct81 product was needed was wrong for this hosted test bundle.82's public decoded payload exposes81 `ValidatedRevision` and `ClassificationDiagnostic` metadata; its preflight default argument emits a call to81 `Limits.init`. The fixture references these even without writing `import MeshBufferDecoder81`. Source/module visibility through82 is not sufficient linker reachability.

`tools/generate-xcode-project.mjs` now declares the existing local81 package, its `MeshBufferDecoder81` hosted product, and corresponding hosted framework-build entry. The existing82/83 links remain. The committed project is regenerated from a freshly connector-verified65-file app inventory at the exact parent, in controlled scratch—not from the five-file partial app checkout and not from placeholder files. Canonical BEFORE and AFTER equality are checked. App sources/linkage, hosted test sources and all build configurations are unchanged.

All nine classification fixtures and83 source are byte-identical to the parent. No test is removed, skipped, rewritten or suppressed. The new project-only `integrated/hosted-decoder-link-membership.patch` reverses first, before the existing classification inverse; all previous checker text/metadata, timing-helper layers, current workflow `d5d9d483…` and native helper `c6c51f72…` remain unchanged. Existing integrated pins are updated only for the narrow changed inputs and new regression.

## Verification and remaining requirement

`python3 research/hosted-mesh-decoder-link-20261028/check.py`:

-18 source/byte/inverse checks passed.
-3 bounded Node graph/symbol-reachability regression tests passed, including missing/wrong decoder-product mutations.
-70 cumulative85 source checks passed. Its app-wide declaration scan still sees only5/65 local app sources; remote65-name canonical equality is separately verified, not mislabeled as full source checkout.

These are **not Swift compilation or linker execution**. `appleLinkVerified=false`, and hosted tests have not executed after this fix. A fresh exact-source Apple run must prove the test bundle now links, executes the unchanged cases, and produces any eligible public same-export artifact before the user's geometry comparison can proceed. No workflow action, build, push, route tuning, camera activation or physical-guidance change was performed by this agent.

The frozen earlier proposal/integration records are historical evidence; their “no direct81 needed” statement is superseded by this observed native failure and correction, not retroactively rewritten into a passing claim.

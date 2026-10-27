# Apple verification handoff — NOT executed or scheduled

Do not install dependencies, change the app, publish a workflow or start builds
from this handoff alone. Obtain the authorized Apple execution scope/resource
policy first. The existing stage83 runner's budgets are historical configuration,
not evidence of compliance with a stricter experimental resource policy.

## Inputs and build shape

1. Verify `SOURCE_PINS.json`, the unchanged stage83 manifest and the nested
   stage75 `APPLE_SOURCE_PINS.json`. Record the exact revision and toolchain.
2. Reuse the established stage83 Apple harness's **actual** stage75 package
   products, native SwiftPM compatibility build system, serial native worker,
   MeshBufferDecoder81 and MeshSnapshot82. Do not substitute stub native types,
   extract the ingress into a fake container or install another Recast/planner.
3. In a separate scratch output directory/module, compile
   `Sources/OriginBoundMeshIngress.swift` as `OriginBoundMeshIngress86` linked to
   those same products. The macOS host fixture needs MeshSnapshot82 built with
   `-enable-testing` only for the synthetic Owned initializer. No `@testable`
   access to OriginBoundMeshIngress86 or BlindRoomMesh is needed.
4. Compile/run `tests/main.swift` against that module and those real products.
   Preserve full output and failures. Record the **observed** `RESULT:` count;
   do not infer a pass/count from authored `check` statements.
5. Typecheck `tests/public-client.swift` successfully first, then independently
   typecheck each of the four `tests/*-must-not-compile.swift`. Success is a
   failure of this negative test. Require the actual diagnostic to identify the
   inaccessible lease initializer, missing `lease:` argument or nonexistent
   `currentLease` member respectively;
   an unrelated missing-import/link/toolchain failure is not a passing rejection.
6. Compile/link the actual iOS Simulator `Sources/ARKitIngress.swift` together
   with the owner and actual stage82 `ARKitMeshAdapter.swift`. Do not merely
   compile the host's `#if`-excluded file and call it ARKit evidence. No simulator
   launch or device execution is implied by compilation.
7. Preserve and run the unchanged stage83 fixture separately (83 expected in its
   current harness) and stage75 relevant lifecycle/discard regressions. Neither
   previous pass counts nor a stage86 pass substitute for exact-source reruns.

## Inert runner prepared; later workflow plan not installed or launched

`apple/ci.py` requires `--execute-authorized-apple` before it does anything beyond
argument parsing. Only after separate review and Apple authorization, the command
would be:

```sh
python3 -B research/origin-bound-ingress-proposal-86/apple/ci.py --execute-authorized-apple
```

The original source review supplied no workflow. The later dated
[execution plan](APPLE_EXECUTION_PLAN_20261027.md) prepares an isolated
`apple/workflow-proposal.yml` under the project's authorized testing scope for
parent review/publication; this increment does not install or launch it.
The selected executor must provide the
same verified repository/ref/HEAD environment and pinned Xcode27/iOS Simulator27
SDK as stage83, plus an **outer execution deadline no greater than the existing
23-minute run-step budget** (25-minute enclosing job). This handoff does not
authorize larger budgets or automatic retries if those limits prove insufficient.

The runner invokes unchanged stage83 once, retaining its separate 83-check result
and actual host/simulator compilation, then links stage86 to those exact products.
Stage75 public-client and full fixture regressions reuse the same host module and
dylib: no second package build, stubs, replacement planner or native runtime.
It keeps all added artifacts under `$RUNNER_TEMP/blind-mesh-candidate-ingress-83`,
preserving a single shared 512 MiB stage-end scratch account, 20,000-entry accounting
limit and 128 MiB per-file cap. Inherited package commands retain one compiler job,
300 CPU seconds/300 wall seconds. Stage83/stage86 direct compiler/fixture commands
using the inherited stage81 runner retain 180 CPU seconds/240 wall seconds.
The additional stage75 regression link commands use the stage75 runner's existing
300 CPU seconds/300 wall seconds; its public/fixture executions retain 300 CPU
seconds with the existing 60/120-second wall limits. These are the established harness's limits,
not a live disk quota, RAM cap, measured copy latency or compliance with a different
experimental resource policy. No cap is relaxed here.

Retain `STAGE86_RESULT.json`, original stage83 `RESULT.json`, every receipt/log,
and `stage86-stage75/{RESULT,RUNTIME_RESULT,ROUTE_DIAGNOSTIC}.json` within the bounded
scratch tree. The proposed artifact upload is deliberately narrower: receipt JSONs
(with bounded log tails), the two root results, and stage75 RESULT/RUNTIME_RESULT
only; no arbitrary logs, input geometry or route-diagnostic upload. The stage86
result is written only after all expected stages pass and pins reverify. It records
the observed stage86 `RESULT:` line, all four relevant compiler-rejection witnesses,
unchanged stage83 evidence and stage75 counts separately. A failed stage must retain
its receipts; do not infer later stages succeeded. The runner checks actual source
modules against real SwiftPM products, not the full stage86 SwiftPM dependency graph.

## Required evidence classification

Record authored → typechecked → host fixture executed → ARKit SDK compiled →
actual native-owner/device measured as distinct states. The four negative compiler
fixtures and the deliberate mutable-global misuse control are different tests:
the former must reject source, the latter must demonstrate the native-origin gap.

A host pass cannot validate native callback association, Metal lifetime, RoomPlan
handoff, batch-copy latency, hazard priority, RSS/privacy purge or sensor safety.
Do not wire this package into the existing no-copy bridge after a host pass.
Complete the README's N1–N6 native-owner gates first; N7 remains separate.

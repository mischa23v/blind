# Stage86 exact-source reuse and compatibility record

Prepared 2026-10-27 in the existing dirty checkout; no commit, push, install,
workflow launch, app integration or live sensor operation by this proposal.
`SOURCE_PINS.json` is the byte-level provenance record, not a claim that the dirty
checkout's HEAD identifies all working-tree files. The review diff is generated
from the current pinned stage83 owner, ARKit overload and package manifest.

## Reused sources, not replacement algorithms

| Input | Exact selection / license / evidence |
| --- | --- |
| Stage83 owner and ARKit seam | Local `research/mesh-candidate-ingress-83`, identified by its unchanged `SOURCE_PINS.json` and this proposal's hashes. Only lease admission/lifecycle/API shape and module identity differ; complete diff is included. Existing 83-check Apple harness is reused and required to rerun independently. Earlier stage83 results are not stage86 results. Project adapter code; no newly assigned third-party license. |
| Stage82 snapshot/copy adapter | Actual `MeshSnapshot82` and `ARKitMeshAdapter82` sources and package manifest; pinned unchanged. Apple ARKit/Metal platform APIs, not copied platform implementation. No claim that descriptor checking proves Metal lifetime or native origin. |
| Stage81 decoder | Actual `MeshBufferDecoder81` source and package manifest, unchanged and pinned. No new parsing algorithm or substitute decoder. |
| Stage75 runtime/native package | Current `BlindRoomMesh`, including the existing late-error fence and terminal discard, through the exact nested `APPLE_SOURCE_PINS.json` (all native sources/license included). Do not substitute historical `FROZEN.json` or `MANIFEST.json` for that current Apple selection. |
| Recast/Detour | Existing stage75 vendored selection from [RecastNavigation revision 9f4ce64458dfae86e1239c525ddc219c4e9e06f1](https://github.com/recastnavigation/recastnavigation/tree/9f4ce64458dfae86e1239c525ddc219c4e9e06f1), Zlib notice retained at `BlindRoomMesh/LICENSE-Recast.txt`; [stage71 attribution](../apple-candidate-ci-71/ATTRIBUTION.md) records the prior source/fixture selection. No native algorithm changed or re-downloaded. |
| Native fixture | Existing public source-only `research/apple-candidate-ci-71/fixture/room.json.gz`; packed and decompressed hashes checked before the stage75 regressions. Existing data attribution/limits remain in stage71; this proposal adds only tiny synthetic owned floor arrays, no camera/private data. |
| Apple build harness | Stage83 invokes actual stage75 native SwiftPM compatibility build (`--build-system native`, one job), not the default SwiftBuild backend. Stage86 reuses those exact resulting host/simulator products and inherited bounded run functions, with no additional native build lane. The later isolated workflow proposal remains uninstalled pending parent review. |

These are reused foundations and **new, uncompiled admission glue**, not a newly
battle-tested integration. Swift, ARKit SDK compilation and fixture execution are
pending. Portable syntax/source/hash checks are the only new executed evidence.
Apple's documented APIs and the earlier ownership audit remain evidence leads;
no new guarantee of callback drainage, frame freshness or buffer synchronization
has been established by this increment.

## Exact impact

- Current adopted stage83 and app/project bytes are unchanged by stage86. The app
  still imports stage83, is DEBUG/diagnostic-flag fenced, defaults off and never
  calls ingest. Observed app paths are pinned only to make that scope auditable.
- Proposed module/class is separately named `OriginBoundMeshIngress86`; not linked
  into the app. Constructor starts closed; `reset() throws -> ProducerLease` is
  the sole issuer. The final empty capability class has a `fileprivate` initializer,
  no public fields, getter, renewal/serialization or caller-provided epoch.
- Generic ingest, actual ARKit ingest and removal require `lease:`. This is a source
  break, including the current unleased stage85 removal call. No legacy/default-
  current bridge is supplied. Ignoring a reset return cannot give callbacks a lease.
- Wrong-lease admission returns false before token/receipt/revision/runtime/copy
  changes. Current-lease malformed deliveries retain original conservative gap
  behavior. Bool does not promise successful installation or a usable route.
- Stop/reset/terminal discard revoke old leases. Exact pre-decode/install/use-time
  fences, copy ceilings, aggregate reservations across reset and native drain
  handshake remain inherited. Lifecycle callbacks still need external immutable
  owner guards because reset/stop themselves intentionally take no producer lease.
- A callback that reads a new mutable global lease still passes the API. The
  positive misuse witness is mandatory; this API is not native ARSession-origin
  certification and does not justify moving the existing app beyond no-copy.

## Historical audit remains historical

The callback ownership audit has 14 source pins. Its old NavigationModel pin is
`6193f6c5ee09e5ac572532fff7fc4f6ea6ae31aeec1b24957eb380ed6fe07d9a`; the integrated
working source is `ef35a58edbebd33f5d30ef4921169227ec1dfe2e9fb06664ba5a520687684c14`.
The other 13 pins match. `AUDIT_RECHECK.json` intentionally says the historical
checker did not pass. The new static checker verifies this mismatch explicitly;
that is not a fresh all-app audit pass or a reason to rewrite historical evidence.

## Approval boundary

Independent source review subsequently cleared this proposal; the dated
`APPLE_EXECUTION_PLAN_20261027.md` and inert workflow proposal now prepare bounded
Apple validation for parent review/publication under the authorized testing scope.
No workflow is installed or execution scheduled by this increment. The original
authored/unrun source-review receipt remains in `history/pre-apple-workflow-20261027/`.
Even an eventual all-green synthetic/native
build result leaves README N1–N6 native-owner/device gates and N7 physical-guidance
gates open. No new SLAM, localization, physical-direction or safety authority.

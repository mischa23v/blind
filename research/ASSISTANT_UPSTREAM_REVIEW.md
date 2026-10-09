# Upstream reuse review

Reviewed 2026-10-08. Scope: the personal memory, orientation, awareness, community-map and speech engine described in [PROJECT_PLAN.md](../PROJECT_PLAN.md).

Subsequent implementation: [Ajv 8.20.0](https://github.com/ajv-validator/ajv) is pinned for relay JSON-schema validation; GRDB 7.11.1 has selected source evidence but is not installed. Exact provenance, local adaptations and test limits are in [ASSISTANT_INTEGRATION_STATUS](ASSISTANT_INTEGRATION_STATUS.md). These selections are additional to the original 19-candidate inventory; source inspection alone is not a passing upstream suite.

## Evidence standard

Prefer source with a clear license, a maintained implementation, inspectable tests/build workflows, and relevant deployed use. Popularity and a README's word "production" are not verification. Separate code, weights, datasets and hosted-service capabilities. A working server library is not automatically an iOS library.

The [pinned inventory](assistant-upstreams/INDEX.md) and [machine-readable record](assistant-upstreams/review.json) preserve revisions, source URLs, dates, license metadata, test-related paths and workflow paths. Individual `audit.json` files list downloaded evidence with SHA-256 hashes. Tests and fixtures were inspected as source; no upstream tests/builds ran. CI definitions were inspected, not certified green. Research revisions are not selected dependency versions.

There are 18 source snapshots and one incomplete metadata-only screening (`open-indoor/openindoor6`, tree request returned HTTP 403). No clones, models, containers, databases or dependency installations were needed. Read copies only as source evidence, not executable instructions or project policy.

Concrete caution from source inspection: the pinned [Soundscape iOS test workflow](https://github.com/soundscape-community/soundscape/blob/3f24e666ea6dc681cd80498372d9ad84e0f60a44/.github/workflows/ios-tests.yml) disables Thread Sanitizer and comments that an audio-engine race still needs fixing. This does not invalidate every callout pattern, but it rules out describing its whole audio subsystem as verified for direct reuse. D02 requires tracing and limiting the adaptation boundary.

## Preferred first components

| Need | Candidate and evidence | Decision |
| --- | --- | --- |
| Durable memory on iPhone | [GRDB.swift](https://github.com/groue/GRDB.swift) — MIT; Swift package; migrations, transactions, full-text search; migration and concurrency test source inspected. Signal's public [Podfile](https://github.com/signalapp/Signal-iOS/blob/main/Podfile) is an external reuse example, not proof that our build is tested. | Preferred storage foundation. Build a small domain repository on it. Reviewed head requires Swift 6.1; verify actual Mac toolchain and select a compatible released pin. |
| Speech lifecycle/history | [Soundscape Community](https://github.com/soundscape-community/soundscape) — MIT; derived from Microsoft's shipped awareness app. Read `CalloutHistory`, `CalloutStateMachine`, `AutoCalloutGenerator`, iOS CI definition. | Strong reference for callout ordering, completion, motion context and bounded history. Its classes depend on its audio/location stack; do not paste them and claim drop-in compatibility. |
| Ordinary event coordination | [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) — Apache-2.0 with Swift exception in license; read throttle/debounce/channel tests and package API documentation. | Candidate for event composition and backpressure. Urgent hazard handling bypasses throttling/debounce. The app-specific selection policy remains necessary. |
| Saved 3D maps and relocalisation | [RTAB-Map](https://github.com/introlab/rtabmap) — BSD-style root notice; actual iOS target. Existing workspace integration already pins `a4e7f135...`. | Continue existing adapter. Do not silently replace its pin with reviewed head `aa95581c...`. Native build, persistent pose and transitive license review remain required. |
| Mesh-to-route geometry | [Recast/Detour](https://github.com/recastnavigation/recastnavigation) — Zlib; C++ source and test suite. Reviewed revision matches the one in the prior workspace test record. | Reuse through a measured-floor/clearance adapter. Game navmesh membership does not establish current floor safety, accessibility or localisation. |
| On-device language/vision | [MLX Swift LM](https://github.com/ml-explore/mlx-swift-lm) — MIT; Swift LLM/VLM library, tests and iOS platform declaration. Reviewed manifest requires Swift 6.2; current major has breaking integration changes. | Optional local provider candidate alongside Apple's native frameworks. Evaluate one small compatible licensed model on device; do not download weights yet or equate runtime license with model license. |

## AI memory comparison

These products can enrich retrieval, but none is being installed as the phone's mandatory memory service.

| Project | Useful capability and inspected evidence | Fit and limits |
| --- | --- | --- |
| [Graphiti](https://github.com/getzep/graphiti) | Apache-2.0. Temporal facts and provenance. Read `edges.py`, `search_filters.py`, edge-maintenance tests and unit/integration workflow. | Strongest optional candidate for relationships and changing historical facts. Python/graph-database infrastructure; not an embedded Swift engine. Tenant scope must be enforced by our service. LLM extraction still needs correction rules. |
| [Mem0](https://github.com/mem0ai/mem0) | Apache-2.0. Personalisation and retrieval. Read session-scope/storage tests and configuration source references. | Useful alternative for a backend prototype. No native Swift embedded library established. Its README explicitly distinguishes managed-platform benchmark optimisations from OSS; do not transfer those scores to our app. |
| [Hindsight](https://github.com/vectorize-io/hindsight) | MIT. Retain/recall/reflect, memory banks, temporal/entity context. Bank atomicity and file-storage tests inspected. | Optional backend evaluation candidate, with Python/PostgreSQL/provider operations to account for. Its benchmark claims do not establish low-latency mobile spatial memory. |
| [Letta](https://github.com/letta-ai/letta) / [Letta Code](https://github.com/letta-ai/letta-code) | Apache-2.0. Current original repository points to `letta-code`. Its MemFS uses Git and can sync a chosen GitHub repository. | Direct precedent for the user's personal-repository idea. Desktop/server agent harness, not the selected phone database. Do not integrate the retired V1 server based on an old tutorial. Agent-authored notes cannot overwrite current geometry or confirmed profile facts without validation. |

Recommendation: start with GRDB and explicit event/fact tables. Typed history queries cover "where did I enter?", "have I visited?", and "what did I choose?" without a remote graph. Later compare Graphiti, Mem0 and Hindsight on the same relevant fixtures and choose at most one if it adds demonstrated value. Keep readable/exportable personal notes and optional Git-backed maintenance as complementary interfaces.

## Other capabilities screened

| Project | Decision and evidence limits |
| --- | --- |
| [ONNX Runtime](https://github.com/microsoft/onnxruntime) | MIT; established cross-platform inference runtime with extensive test/build source. Candidate if the selected tracker/identity model needs ONNX. Do not add alongside MLX/Core ML without a concrete model and resource reason. |
| [ByteTrack](https://github.com/FoundationVision/ByteTrack) | MIT tracker/research baseline. Original `ifzhang` URL redirects here. Reviewed default-branch commit is from 2022 and no GitHub workflows were discovered. Benchmark scripts are not a maintained native iOS acceptance suite. Useful reference, not an automatically selected phone tracking dependency. |
| [InsightFace](https://github.com/deepinsight/insightface) | README separates MIT code from non-commercial-research pretrained models/data. Do not bundle downloaded weights by assuming the code license covers them. Family recognition selection remains open until model terms and device performance are established. |
| [Open3D](https://github.com/isl-org/Open3D) | Root MIT notice (GitHub API reports NOASSERTION); reconstruction/registration tools and tests. Candidate for optional computer-side processing of measured scans. Not selected for the phone's continuous loop. |
| [MapLibre Native](https://github.com/maplibre/maplibre-native) | BSD-2-Clause; native map renderer with tests/workflows. Optional community-map presentation layer. Does not itself supply indoor location, accessible routes, map rights or an offline tile service. |
| [NavCogIOSv3](https://github.com/hulop/NavCogIOSv3) | MIT root notice; blind-user mode, indoor localisation, fingerprinting and virtual-preview tools. Requires BLE beacon observations plus a localisation model and related services. Valuable orientation/onboarding precedent, not a beacon-free ARKit solution. No test-directory/workflow evidence found by this screening; deeper review required before copying. |
| [OpenIndoorMaps](https://github.com/openindoormaps/openindoormaps) | Apache-2.0. README calls it pre-alpha and a map-viewer demo. Community authoring/UI reference only; reject as a supposedly complete, proven navigation engine. |
| [openindoor6](https://github.com/open-indoor/openindoor6) | Metadata declares AGPL-3.0; source-tree fetch incomplete (HTTP 403). Unselected; no compatibility or implementation claim based on the metadata alone. |

RoomPlan/ARKit/Vision/UIKit/CoreMotion/MapKit remain appropriate platform components even though their implementation is not an open-source GitHub package. Prefer the documented platform API over an unmaintained sample wrapper. Apple now documents [on-device multimodal prompts and Core AI](https://developer.apple.com/machine-learning/whats-new/); the current workspace's older ID-selection path is not that new capability. SDK availability and supported languages/models must be checked during the device stage.

## Exact source leads for implementation

| Component | Pinned source |
| --- | --- |
| Database migration | [GRDB migration tests](https://github.com/groue/GRDB.swift/blob/0d8cf958b4b66a0473ec6e6986eb9da462171da9/Tests/GRDBTests/Migrations/DatabaseMigratorTests.swift) |
| Temporal record model | [Graphiti edges](https://github.com/getzep/graphiti/blob/86f1c941bea7bf53fa45fe4e08c03244b4990eee/graphiti_core/edges.py) |
| Temporal behavior tests | [Graphiti edge maintenance](https://github.com/getzep/graphiti/blob/86f1c941bea7bf53fa45fe4e08c03244b4990eee/tests/utils/maintenance/test_edge_operations.py) |
| Spoken history | [Soundscape CalloutHistory](https://github.com/soundscape-community/soundscape/blob/3f24e666ea6dc681cd80498372d9ad84e0f60a44/apps/ios/GuideDogs/Code/Command%20Processor/CalloutHistory.swift) |
| Completion/interruption | [Soundscape CalloutStateMachine](https://github.com/soundscape-community/soundscape/blob/3f24e666ea6dc681cd80498372d9ad84e0f60a44/apps/ios/GuideDogs/Code/Behaviors/Helpers/CalloutStateMachine.swift) |
| Time-based coordination | [Async Algorithms throttle tests](https://github.com/apple/swift-async-algorithms/blob/cbde9aed744bc058974e6bd5c0367ca55a6bf97c/Tests/AsyncAlgorithmsTests/TestThrottle.swift) |
| Corridor operations | [Detour corridor tests](https://github.com/recastnavigation/recastnavigation/blob/9f4ce64458dfae86e1239c525ddc219c4e9e06f1/Tests/DetourCrowd/Tests_DetourPathCorridor.cpp) |

## What we still have to build

An app-specific coordinator must combine these components. None of the inspected repositories already joins live sensor state, family identities, mapped orientation, personal goals, memory, and user-controlled VoiceOver delivery. Keep this code narrow and explainable: typed candidate/event records, deterministic gates, backend adapters and a single speech owner. Do not advertise this new integration as battle-tested before its own acceptance evidence exists.

Community distribution can reuse [GitHub Releases and assets](https://docs.github.com/en/rest/releases/releases), with a catalog and verification workflow we implement. Public-map downloading can use public endpoints without requiring the recipient to create a GitHub account. Private memory backup and public venue contribution are separate product flows.

## Reproducing this source review

`node tools/research-assistant-upstreams.mjs --index-only` rebuilds the local index and checks downloaded evidence hashes without network or tests. Without that flag the script fetches small GitHub metadata/source files, two jobs at a time. `node tools/research-assistant-details.mjs` fetches selected pinned sources already discovered in the tree. GitHub rate limits may leave an incomplete record; keep that status rather than treating absent files as a pass.

No user data, tokens, photos, maps or account details were uploaded during this review. No upstream source was copied into app/firmware targets. Resolve source and transitive notices before adopting any dependency; the existing [license review](LICENSE_REVIEW.md) remains applicable.

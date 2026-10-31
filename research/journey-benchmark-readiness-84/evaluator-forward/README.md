# Frozen evaluator-forward adapter — supplied-pose static-room benchmark

This directory packages the existing published physics/controller primitives behind explicit local imports. **It does not change the20 frozen source paths, synthesize eligible cells, or grant physical authority.** Current execution status belongs to the durable ledgers and run receipts; this document does not declare any unrun cache/episode successful.

- Evaluator manifest: `3d17b1b816abd553fde50ea9702e35b4bcd380d10b18375f5535be2a5101b525`.
- Predeclared matrix: `27fb3411a7ebd6e5f5001d3849244b3ff989edae4ce58d0c93ae8d3a04f4ec74`.
- Exactly100 scheduled pair/condition outcomes, ordered pair-major, same stage72 five conditions and seed72000+pairIndex. **Scheduled outcomes are not guaranteed movement episodes.**
- No original iPhone confidence, live pose estimation, human response or warning latency is supplied or inferred. Poses are synthetic actor-state observations with preserved timestamps, delays/jitter, capture withholding and queue semantics.

## Reuse and adapter scope

`prepare_adapter.py` records archive/loose-source provenance in `ADAPTATION_RECEIPT.json`. Existing components: stage76 controller/episode/observation batch/pose transport, stage61 local measured support, stage59 floor classifier/setup, historical actor/sensor FIFOs, point-follower, and the v17 tiled → v6 OBB → v5 vector → v4 ground-skip → v2 grounded → oriented → reference-band-box evaluator chain. VTK9.3.1 owns exact original triangle geometry queries; its version gate remains. No new physics or navigation algorithm was written.

Explicit `physics_primitives.py` replaces missing historical `run_north` import glue with original functions. The unused base controller constructor refuses invocation; its published transport methods remain, and the stage76 subclass binds the actual pair plan. The pair map merely consumes the frozen source path with the same1cm cursor rule. It does not replan from reference geometry. Historical occupancy diagnostics are unavailable (`-1`), never manufactured clear/eligible.

Each pair has a distinct supplied start/goal, source-tangent yaw, plan hash and episode session identity. There are no in-episode resets or multi-leg handoffs. The new matrix allows2500ticks/900CPU seconds/1200wall seconds per episode versus the old short pilot's450/180/240; this is an explicit predeclared longer-route resource allowance, not an unchanged-pilot resource claim or a guarantee of completion. Original physical/controller gates stay:45×30×160cm zero-margin body,25mm per-tick/3D cap,1degree actuator-turn cap,1cm waypoint criterion,0.5s pose freshness and35cm original full3D arrival region with current post-motion observation and drained actuator FIFO.

## Floor caches and reference boundary

Only the original full FARO mesh and original `icp_iphone.json` are used for evaluation. Mesh topology/IDs are not filtered, cleaned, downsampled or replaced. Source leveling R/t is copied from the published source-only metadata, unchanged.

A cache is independently prepared for each predeclared pair, before movement scoring. Nine first-hit probes are taken at the exact source start and source-derived yaw; there is no search for a supported replacement. The source-derived envelope is routeXZ±0.8m withY[-0.25,0.25]. The existing stage59 classifier fits its broad and20cm local patches from those original seeds and that fixed envelope. **These evaluator classification fits can differ per pair.** They are not identical historical plane fits, not known true floor, and cannot be tuned after movement outcomes.

The historical fixed scene-plane coefficients are retained separately as provenance when reconstructing `GroundSupport`, not substituted with a per-pair diagnostic broad fit. Actual movement height follows unchanged local maximum-of-nine observed accepted support hits with continuity and half-sweep/underbody checks. Floor contacts remain unmeasured; sub2mm ambiguity and finite-probe limitations remain.

`CACHE_MANIFEST.json` is created only after all20cache outcomes exist, pinning both ready and unavailable/error records. Cache/mesh results are never inputs to the source controller. This is audited logical dataflow separation, not a filesystem security sandbox: the evaluator subprocess necessarily reads the reference and the controller subprocess receives only source plan and delivered simulated observations.

## Honest outcomes and bounded execution

- `invalidInitialSupport`: original nine-probe numeric support fails; no movement started.
- `membershipUnavailable`: published evaluator classifier cannot establish its floor model; unknown classification, not automatically a physically invalid start.
- `cacheError` or compute budget/infrastructure failure: evaluator failure, not geometry evidence.
- Initial body/underbody rejection, predicted body/underbody/support veto, no usable pose/deadlock/timeout, and drained original-goal arrival remain distinct episode outcomes.
- A killed worker without terminal result has **unknown/null** movement and distance, with durable partial progress/CSV paths retained. It never becomes zero-motion success. Torn partial JSON is captured as parse-error metadata and cannot prevent lock cleanup. Arrival is never inferred from process exit or partial trace.

`run_bounded.py` admits one process group at a time via an exclusive stage lock. It checks4.3GiB available RAM before launch, samples aggregate groupCPU/RSS plus wrapper resources, kills the process group on failure and at terminal cleanup, imposes child address-space/CPU/file limits, and checks output,768MiB disk reserve and4GiB total stage storage during and after execution. Limits are sampled and not cgroup reservations. Every attempted run retains stdout/stderr/heartbeat/receipt. The cache/episode ledgers preserve every scheduled entry and are atomically updated.

Native parse and each cache:180CPU/240wall seconds,3.5GiB aggregate RSS/address-space limits,20MiB output. Each episode:900CPU/1200wall seconds,3.5GiB,10MiB output. Full100 worst-case ceiling:25CPU hours/33h20wall plus cache/setup time, not a completion forecast. The full reference acquisition occupies additional stage storage but is already covered by the total4GiB stage check.

## Verification before native evaluation

- `SAVED_CONTROLLER_REPLAY.json`: all201 saved stage76 jitter ticks reproduced commands, stop reasons, source cursor progress, newest-observation decisions and candidate points with zero mismatches. This deliberately injects the original historical first-leg plan into the fixture loader; the new pair0 source query is NOT falsely claimed identical.
- Exact AST parity for support_check, contact_status, transform, load_surface, connected_support and every local_support numerical function.
- `ADAPTER_CONTRACT_RESULT.json`:20plan identities/handoff refusals,100unique scheduled conditions, unavailable diagnostic semantics, unknown interrupted motion and truncated-progress handling.
- All Python files parsed before freeze. None of these cheap checks loads the mesh or proves movement safety.

## Execution commands — phase gates remain explicit

From this directory, after independent review and authorization for the respective phase:

```sh
export PYTHONDONTWRITEBYTECODE=1
FROZEN=3d17b1b816abd553fde50ea9702e35b4bcd380d10b18375f5535be2a5101b525
python run_bounded.py "$FROZEN" parse 0
# Only after native-parse resource receipt is reviewed:
python run_bounded.py "$FROZEN" cache 0
# Independently prepare all remaining predeclared cache indices1..19 serially;
# preserve errors instead of replacing starts, changing rules or retrying in place.
python freeze_caches.py "$FROZEN"
# Only after cache manifests and movement launch are independently reviewed:
python run_bounded.py "$FROZEN" episode 0
```

Each name is exclusive, so an attempted phase cannot overwrite previous evidence. A new code/geometry/resource protocol requires a new version and retained old records, not a silently replaced frozen manifest. Do not execute the entire100batch merely because this adapter exists.

# Offline Apple route-result viewer (prepared 2026-10-28)

**Preparation only. No actual native result has been rendered or inferred.**
The tests and inspected check image use synthetic renderer fixtures, prominently
watermarked `SYNTHETIC RENDERER CHECK - NOT A NATIVE RESULT`. They are not path,
guidance, collision, localization, get-up or arrival evidence and are not user
deliverables. Root owns real evidence retrieval/publication and user delivery.

## Scope and source reuse

`render_results.py` is an offline, non-app diagnostic viewer. It consumes only
already-collected `routeDiagnosticEvidence` from the existing bounded CI evidence
artifact. It never queries Recast, physics, Apple SDKs, sensors, the app, network,
photos or private files. It never changes app, CI, protocol, source room geometry,
profile, route, test result or contacts. No dependency installation is needed:
Python standard library and the environment's existing Matplotlib (Agg) render
SVG/PNG; Pillow is used only to inspect a synthetic test PNG.

It reuses `tools/ci/native-route-diagnostic-evidence.py` for exact public-fixture,
frozen-protocol, full schedule denominator, typed report and closed text/UUID
validation. Its `sources()` hashes pin unchanged licensed Apple JSON, protocols
and relevant producer source. Renderer checks are additional, not a replacement
for producer/native tests. This is small display/validation glue, not a new
mapping, navigation, collision or support algorithm.

The source fixture directory is `ios/BlindAssistTests/Fixtures/RoomPlanApple`.
Its README, manifest and unchanged `APPLE-LICENSE.txt` retain the Apple sample
provenance/license. The renderer references source geometry; it does not copy
opaque `coreModel`, photos, room pictures or private device data into outputs.
Do not redistribute the original JSON without its license.

## Run only after an actual native report arrives

Use the exact existing CI evidence JSON, a separately verified SHA-256, and a
new output directory. No auto-discovery, directory scanning or xcresult export is
performed. A missing report stays missing. If all reports are unavailable, the
viewer refuses to invent an output.

```sh
python3 research/roomplan-route-result-views-20261028/render_results.py \
  --evidence PATH/TO/native-hosted-case-statuses.json \
  --expected-evidence-sha256 VERIFIED_64_HEX_DIGEST \
  --output NEW/RESULT/DIRECTORY
```

Expected: up to 34 case/stage views, one SVG and PNG plus a JSON receipt for each
reported row. `RENDER_RECEIPT.json` retains source commit, exact input hash,
producer and local validation source hashes, collection/test status, output
hashes, outcome counts, reported errors, report hash provenance and limitations.
The unchanged Apple license is hash-checked and copied alongside derivatives. An unexecuted row has a geometry
context view but **no inferred start, goal or path**. A failed native test stays
`Failed` in provenance even if one candidate row has zero reported contacts.

Original attachment SHA-256 is retained from CI. Because that artifact embeds
parsed JSON rather than original raw attachment bytes, the viewer cannot
independently rehash the raw attachment. It separately hashes input artifact
bytes and canonical parsed report. This distinction is explicit in the receipt.
A hash is integrity evidence, not proof that an input came from actual execution;
root must match the artifact to the exact native run/commit before presentation.

Output directories must not exist. A source-verified, complete CI case envelope is required. All input/schema/geometry checks happen
before output creation. Rendering errors write an `incomplete_render_error`
receipt, not success. The CLI emits no arbitrary input/error text. It makes no
permission escalations and has no fallback downloads/installations.

## Drawing contract

- Full column-major 4x4 source transform, translation and every local coordinate
  are used exactly once. World X is right and world Z is up; Y is omitted only
  from the display, retained in all exact report points and geometry receipts.
  The two original room frames are **never joined or fitted/aligned**.
- Uniform **110 PNG pixels per metre** in X and Z, checked from the actual plot
  transform. SVG preserves the same proportions. Each room's domain contains
  its original geometry and all reported endpoints, with 0.5 m display padding;
  canvas size changes instead of fitting/scaling geometry. Extents over 25 m
  are refused rather than compressed/clipped. No floor/source inflation.
- Original ordered floor corners preserve concavity. Furniture is the silhouette
  of all **eight transformed original box corners**, not a yaw-only rectangle
  or a floor hull. Exact 3D corners and vertical Y ranges remain in receipts.
- Walls/windows/doors are original **parametric surface projections**, not a
  reconstructed RoomPlan mesh. Separate historical door overlays retain state;
  dashed green denotes historically open, solid wine denotes historically
  closed. Neither is a current-state observation. This top-down depiction does
  not reproduce full-height apertures or prove exported triangle-shell collision.
- Only the exact `segments[].from/to` lines are drawn, never an invented
  requested-to-goal or seated-to-standing line. Detour points are shown as dots;
  connectors are dashed; reported contacting segments red. The drawing core
  preserves missing expected connections as **undrawn gaps** in its synthetic
  tests; the CURRENT CLI uses strict collector validation and therefore rejects
  incomplete chains before rendering. There is no legacy fallback or repair.
  Segment endpoint/kind/order disagreement is also rejected.
- Requested A/B and native projected PA/PB are distinct coordinates, including
  supplied post-rise S0 and invalid-start X. Coincident markers are not nudged;
  only annotation text moves. Displacement numbers are checked with a small
  Float32-distance tolerance; no points are altered or snapped.
- A successful native query is not automatically a complete route, zero contacts
  is not positive support, and a complete route reaches a **projected** goal.
  Contact output contains feature IDs and whole-segment flags, **not impact
  coordinates**. No contact points, collision timing or full-body silhouettes
  are fabricated. Raw-body/margin, floor, bounds and obstacle results remain
  distinct. Profile dimensions and all heights are explicit supplied inputs.
- Replay positions advance only when the report says the modeled full candidate
  completed without contact. Withheld/failed stages do not advance. Reported
  cross-stage start disagreement is rejected. Each stage gets its own image;
  no synthetic cross-stage animation or person motion is made.
- Output visibly states supplied poses, modeled geometry, no live localization,
  no get-up kinematics, unknown current coverage, and 2D-not-3D/safety limits.
  It is not walking instructions, a physical guide or child/device acceptance.

## Bounded validation

```sh
python3 research/roomplan-route-result-views-20261028/test_render_results.py
python3 research/roomplan-route-result-views-20261028/independent_review_tests.py
```

Latest result: **29 synthetic renderer tests + 4 independent review tests pass**. These test positive
coordinate orientation, full tilted transforms/height, exact concave floor,
historical door states, uniform scale, missing gaps/no bridging, inconsistent
input/source/report hashes, typed private-field rejection, missing reports,
query/contact/replay disagreement, and no path for unexecuted rows. Rendered
synthetic check was visually inspected; source-only output is committed/staged
only at root's discretion. Native results remain pending.

## Frozen strict-input status

The initial native batch uses the strict reviewed collector contract. An optional
offline legacy-gap display API was discussed but is **not implemented or enabled**.
The upcoming source revision reports exact continuous baseline connector chains
and explicit unverified full-footprint support. Original protocol/profile bytes
and all 18 baseline schedules remain unchanged. Native execution, not these
renderer checks, determines actual path/guidance/collision outcomes.

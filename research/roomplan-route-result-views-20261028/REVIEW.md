# Independent source review and bounded checks

Reviewer: `/root/review_recorded_route_preview`, separate from the renderer author.
Reviewed renderer SHA-256:
`3bbda40dd56d3fa1fc83c5fb3403c22345963fb4b8d381126fa99c8b58293814`.

Independently reran **29 renderer tests + 4 independent tests**, all passing.
The independent tests include four active-failure drawing subcases and validate
their synthetic full reports through the actual strict collector validator before
rendering. These are NOT native route/physics tests.

Checks and addressed findings:

- Full column-major affine transform and explicit independently calculated
  positive-coordinate witness; original ordered concave floor retained.
- Furniture silhouette uses all eight transformed box corners, including tilt
  and height, not a fitted yaw-only footprint.
- Exact segment kind/order/endpoints, profile inputs, projection displacement,
  contact aggregation and journey replay are checked. No inferred get-up line or
  phantom connector is drawn. Partial/invalid/no-path/unexecuted stay distinct.
- Producer source keys are exact allowlisted keys, and uncollected statuses are
  sanitized; private injected strings are not copied into receipts.
- Verified CI case envelope and source/license hashes are required. Differing
  producer-vs-current code hashes are explicit; fixture/protocol mismatch fails.
- New baseline continuity metadata is checked without turning contact absence
  into floor-support evidence. Support remains visibly UNVERIFIED.
- Uniform 110 px/m geometry is asserted from Matplotlib's actual transform.
  Detail/footer text bounds prevent clipping. The author visually inspected
  final synthetic Bedroom3 and Hallway2 PNGs; watermark says NOT A NATIVE RESULT.
- Original Apple license is copied alongside derivative outputs when real
  rendering is invoked, not discarded.

No remaining identified source blocker at this freeze. Native report collection,
exact CI-run attribution, real result rendering/visual QA, and all physical
localization/get-up/device/safety claims remain outside these checks.

**Strict current input only:** the CLI uses the existing collector's strict
validator. An older baseline report missing a projection/Detour edge is rejected,
not silently repaired or passed to a legacy mode. Direct drawing-helper gap tests
show it cannot invent bridges; they do not imply CLI acceptance of old gaps.

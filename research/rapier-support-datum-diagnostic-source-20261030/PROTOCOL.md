# Six-pose support-datum diagnostic (source only, not executed)

Purpose: separate a wrong authored foot datum/near-foot contact response from
higher obstacle overlaps. This is not a new mapper or a navigation acceptance
policy. No engine query, candidate geometry computation, or movement trial has
been run by preparing this packet.

## Evidence before choosing a candidate

Neither scene has confirmed semantic floor or continuous support observations.
Coffee contains 4,827 geometric component triangle IDs from signed Recast 15°
marking plus exact adjacency. Its receipt explicitly denies semantic floor,
coverage and continuous support. Conference's original ground-exemption set is
empty, and its receipt also denies semantic floor and coverage. Thus every new
support datum below is **estimated**, never confirmed. Coffee's component is a
geometric provenance restriction, not permission to suppress a hazard.

Use the exact existing Float32 vertices, original Uint32 triangle order and
fixed saved probes. No plane replaces any mesh triangle. Both source meshes,
original VTK contacts, registration and all higher obstacles remain unchanged.

## Frozen six poses

1. Conference `table_92_to_120:960`: VTK nominal clear, KCC near-foot contact.
2. Conference `table_120_to_200:2051`: static low-overlap endpoint.
3. Conference `table_20_to_92:1057`: near-foot horizontal limiting.
4. Conference `varpu_160_to_130:966`: margin contact including a high witness.
5. Coffee `0_to_8:630`: VTK high margin overlap, unchanged KCC movement.
6. Coffee `0_to_8:1643`: zero-input large margin depenetration proposal.

These poses were selected after inspecting the preceding results: diagnostic
selection, not held-out validation or population coverage. Do not replace an
unresolved selected pose with an easier one.

## One candidate, not a parameter search

`prepare_datum.py` is an inspection/materialization adapter, not a clearance
classifier. It uses no numerical/native library. For each pose:

- Enumerate triangle intersections with the vertical line through the original
  foot. Retain all hits with signed upward normal within the existing 15° slope
  limit and within 0.10 m of the authored foot. The 0.10 m interval is a frozen
  diagnostic search window, not measured sensor error or an obstacle threshold.
- Coffee restricts these candidates to the existing geometric component;
  Conference has no such component and is explicitly marked estimated-only.
- Choose exactly one center hit with smallest absolute height difference;
  break equal differences by original triangle ID. Preserve **all** alternative
  eligible hit heights/IDs in the output, not only the selected one.
  `allSampleLayers` means only signed-upward/window/component-eligible layers,
  not an inventory of all raw hazards; the full raw mesh is retained separately. If there is no hit,
  the candidate is unresolved; do not retry with another window or fit.
- Use this single original triangle's local tangent plane. Evaluate that plane
  over the four corners of the unchanged nominal 0.45 x 0.30 m footprint at
  authored yaw. Candidate foot Y is the maximum plane height at those corners
  plus an explicit 0.002 m query-foot placement offset. The KCC itself retains
  its separate unchanged 0.002 m controller offset; this is not assumed to be an
  exact numerical cancellation. Store the unoffset plane maximum and query
  placement separately. The padding is vertical Y, so its normal component is
  0.002 times normalY, not a guaranteed 2 mm normal separation on a slope.
  Use the nominal footprint for placement in both body
  and margin tests; do not separately lift the larger margin. X/Z/yaw unchanged.
- Report nine vertical probes across the footprint and their candidate layers;
  they are a coverage diagnostic only, not proof of whole-footprint support.
  No residual-based pruning, interpolation over missing observations, fitted
  replacement surface or semantic labeling occurs.
- Preserve the selected triangle vertices and area, and label each nominal
  footprint corner as inside or extrapolated from that triangle.
- The candidate may land on an object or extrapolate a tiny triangle. Record
  this limitation. Keep original low-object/drop evidence. Even if candidate
  movement looks easier, it is not eligible for navigation.

This is a deliberately falsifiable local-tangent diagnostic. It can explain a
contact response, not demonstrate a robust floor estimator. No thresholds are
adjusted after seeing its result.

## Bounded native comparison to prepare after materialization review

Each of six poses has original and candidate-datum arms. At each arm query zero
input and the original desired XYZ translation (stationary inputs remain zero;
retain the duplicate condition rather than substituting a new direction).
Use both unchanged body and horizontal-margin envelopes. Only raw mesh flags:
previous 164 called flag pairs were identical. Maximum **48 controller calls**,
with unresolved candidates retained as uncalled rows. No turns, no propagation,
no applied depenetration, no alternative pose search. Keep one CPU and existing
120 CPU-second / 180 wall-second / 1 GiB observed-RSS / 16 MiB output bounds.
The prior managed-sandbox guard must be adapted, reviewed, pinned and published
before any native run; this packet does not grant execution by itself.

Run the independent full-height VTK query at the same original/candidate poses
and original translations, with **no ground-face exemptions**. Retain its lower-2mm-band distinction explicitly;
report an additional untrimmed full cuboid contact audit so a tiny pose shift
cannot silently hide low objects. Preserve raw triangle IDs and contact heights,
including high furniture. Neither VTK nor KCC alone is physical ground truth.
Keep the unchanged low-object, down-step and unsupported-gap analytic controls
visible; the two existing down-step failures remain failures. Any new control
execution requires its own pinned call budget, not hidden extra calls here.

Compare original versus estimated-datum contacts/proposals, all witness heights
and normals, source face IDs where exposed, nine-ray gaps and higher overlaps.
A useful result is a cause isolated, including a failure. It is not an arrival,
safe route, measured detection accuracy or permission to guide a child.

## Prepared versus pending

Prepared: immutable source-input manifest, exact six-pose selection, stdlib
candidate materializer and synthetic tests of the inspection arithmetic.
Pending: materializer execution/review, pinned native/VTK runner adaptation,
independent runner review, publication, then bounded execution by root.
No app, scene geometry, safety margin, prior result or existing runtime guard
has been modified by this packet.

# Joint native/manual ranking candidate — source and authored controls only

**No actual Coffee rerun for this candidate. No physical guidance or exact
table/chair midpoint claim.** This follows the completed manual-window repair,
not a replacement or retelling of that result. Root owns publication/admission.

The saved repaired-centered Coffee path is 7.238872 m (7.276987 m including
requested connectors), but has only 0.00384774 m residual beyond the declared
body circle plus .15 m margin against the manual windows. Its smallest residual
is on interior segments 107–108 of 133, not the immutable requested connectors.
Those are saved-result facts, not fresh geometry queries. Existing native-wall
ranking ignored manual windows except as a hard veto.

## Fixed general adapter, not one-route tuning

`joint_cost.py` calls the same `manual_filter.prune`,
`manual_filter.select_with_frozen_cap` and **unchanged** `selector.select`.
GEOS supplies geometry distances; SciPy supplies graph search. There is no new
search, potential field, polygon reconstruction, smoothing or mesh modification.
The function has no Coffee endpoint IDs, window coordinates or route-specific
constants. Existing 2.5 cm tiers, 1.5 m tier ceiling and .30/.05 exposure constants
are unchanged.

At each node, retain two separate channels:

1. `native`: the existing distance to an **already-eroded navmesh boundary**.
   It remains a diagnostic proxy. Do not add .225 m to reconstruct a supposed
   object surface, or subtract body radius/margin a second time.
2. `manual`: GEOS center-to-window distance minus
   `hypot(.45,.30)/2 + .15 = .4204163456597992 m`. This is residual relative to
   the manually specified window and radial body model only. The unchanged
   hard filter additionally rejects whole segments at `radius + 1e-8 m`.

The selector receives `max(0, min(native, manual))` as a **ranking preference**.
Its existing half-edge-length lower estimate and tier/exposure search then
prefer routes that do not hug either represented channel. For manual distance,
the half-edge reduction is a conservative bound on distance along that edge;
for native wall distance it is still only a proxy. Numerical guard remains a
hard-veto tolerance, not a newly fitted accuracy claim.

These channels have different boundary definitions and inflation offsets.
Their minimum is **not a common physical-clearance measurement** and does not
imply equal distances from real objects. This deliberately does not invent
native surface distances or calibrate unmatched geometry. Equal physical
table/chair clearance requires measured obstacle boundaries and a common body
model; missing source surfaces remain a blocker. Joint selector output fields
are renamed from legacy `...Wall...` names to `...JointRanking...`; both original
channels are reported separately. This is a bounded comparator, not exact
resource-constrained optimization or an exact midpoint algorithm.

Hard whole-segment pruning and requested connector checks are unchanged and
never exempted by the cost. Endpoint-incident graph edges retain only the
existing *ranking-tier* exemption. All such edges remain in the manual hard
filter and connector-inclusive final diagnostic. Full 3D body/margin, support,
height/overhangs, yaw, unknown objects, observation coverage and fresh pose are
still unknown. Manual windows are **not measured table boundaries**. Every
result retains `physicalAuthority: false`.

## Authored tests and reproducibility

`fixtures.py`: 35 small controls, including four reflected/rotated/translated
versions of a corridor in which wall-only ranking hugs an obstacle but joint
ranking chooses the middle lane; an unequal-width gap; native-only influence;
offset applied only to the manual channel; immutable inputs/endpoints; cap,
crossing-edge and requested-connector vetoes; numerical-guard rejection; missing,
nonfinite and degenerate-input refusals, and a simulated timeout preserving its
failed receipt. The four transformations are invariance controls, not independent
rooms. These are authored graph fixtures,
not actual room, sensor, table-boundary or full-body acceptance.

Run the bounded wrapper from the repository root, with a fresh output path:

```sh
python research/clearance-first-joint-cost-source-20261029/run_controls.py \
  /tmp/joint-cost-controls-fresh.json
```

Limits: 10 child CPU seconds, 20 wall seconds, 512 MiB address space, one BLAS
thread. `CONTROL_RESULT.json` records the final execution and before/after
source hashes. Initial development check had one failed exact floating-point
guard-boundary fixture: `1 + radius + guard` rounded outside the nominal bound.
It was corrected to half the numerical guard, unambiguously inside the veto;
the production filter was **not** relaxed. An initial shell command could not
find `/usr/bin/time` and did not run tests; the standard-library wrapper supplies
resource measurements instead. No dependencies were installed.

## Prepared Coffee attempt003 — not executed

`prepare_coffee.py` is the previous single-pair worker with a small extension:

- Same Coffee mesh, existing native binary, .225 m Recast proposal radius,
  1.75 m proposal height, exact requested/projected endpoints, and declared
  actual .45 × .30 × 1.60 m body plus separate .15 m horizontal margin.
- Reproduce both original unfiltered arms exactly, then both previous repaired
  arms' nodes, geometry, lengths and cap exactly before comparing the new cost.
  Retain the complete saved first arms and previous repaired arms unchanged.
- Same original unfiltered **native-grid length cap**: 10.432711967719545 m.
  As before, requested-to-projected connectors are checked and reported in full
  chains but their lengths are not charged to this grid-length cap.
  No budget widening, endpoint
  movement, post-selection funneling, or route shortening after validation.
- Recompute the unchanged manual hard filter, then joint node ranking. Final
  complete connector-inclusive chains pass through the existing GEOS manual
  diagnostic; any contact is a veto, not a candidate success. Independently
  resampled native wall distances remain diagnostic only. These GEOS passes
  are separate from search but share the same manual geometry/library: they
  are not independent physical evidence.

`run_aggregate.py` preserves the previous aggregate supervisor: one CPU,
120 CPU seconds / 180 wall seconds / 1 GiB observed aggregate RSS / 16 MiB output,
fresh owned attempt directory, before/after pinned inputs, committed-source
admission and complete process-group retirement. Its workload now includes the
additional comparison/ranking queries within those same limits; resource success
has **not** been measured for attempt003. No native build/install command exists.

`freeze.py` checks every earlier pin, then adds this source and the recoverable
saved previous proposal gzip. `SOURCE_PINS.json` binds exact code, unchanged
selector/filter/validator, baseline records, binary, mesh, Python and GEOS plus
NumPy/SciPy distribution metadata. It is not a complete dynamic-library closure.
After independent review and exact-source publication, **root alone** may admit:

```sh
python research/clearance-first-joint-cost-source-20261029/run_aggregate.py \
  --admitted-source-commit <exact-published-HEAD>
```

Fresh output is `coffee-clearance-comparison-attempt-003`. Failure, disconnect,
over-budget or no meaningful improvement remain valid outcomes. Do not retune
to the result. Conference and other-room comparisons are subsequent frozen
tests, not claimed performed by these authored controls.

## Reused upstreams and source manifest

- GEOS installed 3.13.1 / C API 1.19.2, LGPL-2.1, through the existing pinned
  validator adapter. [Official C API](https://libgeos.org/doxygen/geos__c_8h.html).
- SciPy installed 1.17.0, BSD-3-Clause, unchanged directed sparse Dijkstra.
  [Official versioned API](https://docs.scipy.org/doc/scipy-1.17.0/reference/generated/scipy.sparse.csgraph.dijkstra.html).
- Recast/Detour remains the prior pinned `9f4ce64458dfae86e1239c525ddc219c4e9e06f1`
  / zlib native source; no rebuild or modified solver. Upstream/local provenance
  and limitations remain in the first Coffee source README and prior pins.

No upstream suites were run here; library reputation is not validation of this
adapter. Dataset/source/model licenses and physical coverage remain separate.

Publish only this sibling's `joint_cost.py`, `fixtures.py`, `run_controls.py`,
`prepare_coffee.py`, `run_aggregate.py`, `freeze.py`, `README.md`,
`SOURCE_PINS.json`, `CONTROL_RESULT.json` and any separately reviewed review
record. No caches, private images, model weights, staging or push by this task.

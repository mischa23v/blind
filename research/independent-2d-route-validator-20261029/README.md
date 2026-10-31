# Independent 2D route rejection demonstration — 2026-10-29

**Actual result: 22 authored unittest methods passed, 0.096 seconds, exit 0.** This is not a real Coffee/conference-room validation, real table geometry recovery, or on-device pass. Exact console output is `TEST_OUTPUT.txt`; pre-run source/fixture hashes are `SOURCE_FREEZE.sha256`; admission and numerical review are `SELF_REVIEW.md`.

## Scope and result

`validator.py` is a small offline Python adapter over installed GEOS C predicates, not a custom planner, SLAM system, mesh reconstructor, or collision algorithm. A crossing is identified by zero-based segment index and obstacle ID. It rejects the same segment when the centerline misses an obstacle but the body or separate safety margin intersects it. Endpoint and boundary contacts reject. An explicitly authored longer detour passes only under `clear_in_authored_fixture_only`. No result permits live guidance.

The .45 m × .30 m footprint is enclosed by an orientation-independent circle of radius `hypot(.45,.30)/2 = .2704163457... m`; the separate .15 m margin gives .4204163457... m. Height remains 1.60 m in the profile. GEOS computes distance directly between segment/point and polygon, without an inscribed buffer approximation. Contact at distance <= radius + 1e-8 m rejects. Coverage contains the segment and its distance from coverage boundary must exceed that same radius plus guard. This is conservative for an oriented rectangular body, not an exact rectangular sweep; horizontal projection alone cannot certify vertical clearance, support, slopes or changing objects.

`test_validator.py` contains the labelled authored floor/body/head projection fixture. A manual diagnostic rectangle mode is tested only as non-measured diagnostic evidence; it can reject a path relative to that supplied rectangle but can never prove a physical obstacle exists or yield clear. The two red Coffee image rectangles have NOT been substituted for table outlines.

## Call contract

```python
validate(route, scene, now)
```

- `route`: `points` are `[x,z]` metric pairs, plus exact `frame` and `revision`.
- `scene`: `frame`, `revision`, `units='metres'`, replay `captured_at`, positive `max_age_seconds`, `source_kind`, a simple `coverage` polygon, `projection`, and `obstacles`.
- `projection`: separate `floor`, `body`, `head` records, each with nonempty `source`, `coverage='complete'`, matching `frame` and `revision`. The authored fixture records height intervals. Those intervals are documentation, not an implemented vertical-proof validator.
- `obstacles`: explicit `id`, `layer` (`floor`/`body`/`head`), `source_kind`, and simple polygon.
- `now`: time in the same replay clock as capture. Never silently replace historical capture with current time.
- Status is `rejected` for a supplied-geometry body/margin contact, `unknown` for incomplete or unsupported evidence, or narrowly `clear_in_authored_fixture_only`. Blockers remain visible even when contacts are found. All outputs contain `live_guidance_allowed=False`.

Only `authored_fixture` input can pass this demo. Measured input integration needs a separately reviewed projection adapter retaining source geometry hashes, frame transforms, floor/head/body height ranges, coverage holes and confidence/currentness, plus the real 3D engine. This implementation deliberately does not claim those requirements are solved. Simple polygon input cannot represent support holes directly: split coverage conservatively or keep it unknown; never fill holes as free space. This trusted-fixture adapter is not a hardened untrusted-input parser or a resource-bounded production service.

Detours are proposed by the existing maintained planner in `compare_clearance_first_routing`, not searched for here. Supply proposed XYZ paths projected as XZ without changing the frame or profile; recheck here and in 3D. Raw Detour wall distance is only a proposal-ranking proxy, not independent obstacle clearance.

## Real source inventory, not real validation

Original published Coffee input: `../coffee-room-journey-recovery-20261029/baseline/attempt002-result/QUERY_CORE_RESULT.json`.

SHA-256: `166c7caec2b55e5ca09fcc8aca924c0f72690a0b463852aa8a4f3da81464af87`.

A lightweight JSON inventory confirmed 20 accepted native proposals among 72 directed queries. No physical table polygons, complete floor/body/head projection or currentness contract was inferred from those paths. Those 20 real paths have NOT been run through a claimed complete physical 2D collision oracle; physical clearance remains unknown. No actual measured path fix or 3D detour-validation result is reported here.

## Maintained upstream provenance

- GEOS 3.13.1 is already installed at `/usr/lib/x86_64-linux-gnu/libgeos.so.3.13.1`; C API soname `/usr/lib/x86_64-linux-gnu/libgeos_c.so.1` (file `libgeos_c.so.1.19.2`). Python Shapely is absent. No package was installed.
- Official C API: https://libgeos.org/usage/c_api/ — reviewed for stable ABI, reentrant contexts and explicit geometry ownership. Source: https://github.com/libgeos/geos/tree/3.13.1 . Upstream tests: https://github.com/libgeos/geos/tree/3.13.1/tests . These are source/test references, NOT a locally executed upstream suite or a verified CI result.
- Installed `/usr/share/doc/libgeos-c1t64/copyright` identifies GEOS library as LGPL-2.1-or-later; bundled subcomponent licenses are listed separately there. No model/data license applies to the newly authored fixture; real room source retains its original provenance and restrictions.
- Local adaptation: Python ctypes declarations, context/geometry cleanup, validation/provenance gates, fixed body envelope, result formatting, authored fixtures. No new C++ build or replacement geometric predicates.

## Reproduction

```sh
cd research/independent-2d-route-validator-20261029
sha256sum -c SOURCE_FREEZE.sha256
(ulimit -t 10; ulimit -v 524288; timeout 20s python -B -m unittest -v test_validator)
```

Actual invocation used one process/worker with those limits. No API cost, networking during tests, Docker, install, model download or live guidance.

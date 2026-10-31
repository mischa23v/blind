# Coffee attempt 002 — independent result review

**Baseline query reproduction passed:** all saved endpoint/query/mesh-count/exclusion-span results match the frozen historical baseline exactly. Of 72 directed authored queries, **20 meet native completion plus endpoint-association acceptance**, **10 are native-complete but rejected by endpoint association**, and **42 are not native-complete**. This is not a physical route or movement pass.

Exact executed commit: `dce21dc937dfd0423f7721a23597bd4e33085b2b`. Root executed the one admitted attempt; this reviewer did not rerun guard, compiler or queries. Compact public aggregate: `PUBLIC_RESULT.json`; raw command paths, binary, source OBJ and full guard receipt are not copied into this result packet. Exact derived public-dataset endpoints and all 72 query dictionaries are preserved in QUERY_CORE_RESULT.json, with CC BY 4.0 attribution, frozen protocol/configuration and source/expected/current hashes in QUERY_SOURCE.json.

## Independent reconciliation

- Committed run-manifest bytes and digest equal the executed receipt. All **70 input pins** agree before/after/current. All **93 final payload inventory entries** match current files/directories and recorded file sizes/hashes. Workroot contains exactly the recorded payload plus mutable guard receipt: **68 files, 12,271,132 bytes**. Newly compiled shared-library digest matches before/after/current. Both commands exit 0 and both process groups are recorded retired.
- Frozen requested endpoints and configuration equal historical values. Full saved endpoints, queries, meshCounts and nativeMarkedExclusionSpans equal expected results. Timing and regenerated provenance fields are deliberately not historical equality targets.
- Query pairs exactly cover all 9*8 directed non-self authored endpoint pairs. Every saved polyline length was independently recomputed from consecutive saved points with Python standard-library distance/summation, matching within 1e-12 tolerance. Acceptance flags were independently recomputed from each native completion flag and both endpoint-association flags.
- **5/9 authored endpoints** meet association acceptance. The 20 accepted results are the directed pairs among those five endpoints. Endpoint 3 obtains a native projection but shifts approximately 0.141878 m horizontally, exceeding the frozen 0.1 m association gate; its ten native-complete pairings with the five accepted endpoints are rejected. Endpoints 2, 4 and 5 lack the required association; all 42 noncomplete rows report `no start or goal polygon within explicit association bounds`.
- Longest accepted saved polyline is **6.1895263828785545 source-assumed metres**, authored pairs 0→8 and 8→0. Mesh has 51,965 vertices and 87,370 triangles; zero exclusion spans were applied; zero actor/movement episodes occurred.

The 42 failures concern association in this representation and parameterization; they do **not** establish scene impassability. Conversely the 20 accepted proposals do **not** establish collision freedom, physical clearance, current support or safe traversal. Collision was not checked by this experiment. The original XYZ/candidate Y-up frame, metric scale and camera alignment remain unvalidated; endpoint indices are authored coordinates, not verified room semantics.

## Resources and warnings

Guard reports 5.433866 aggregate CPU seconds, 5.454665073 elapsed seconds, 65,990,656 bytes peak observed aggregate RSS and 55,160,832 bytes fast-exit child RSS, below admitted limits. These are sampled resource observations, not a hard peak/hostile-process guarantee.

Compilation preserves **eight upstream DetourNavMesh.cpp -Wmaybe-uninitialized warnings**. Query stderr is empty. Warnings were neither suppressed nor patched after the run. No warning-free, sanitizer, native Apple/app API, full-body/current-hazard or device safety claim follows. Historical runtime equality is not established even though the specified output fields reproduced exactly.

Retained full guard receipt SHA-256: `003d3c944578e11d8904d70aec4667a747f2eb93fb88b92cdcddb6f4d440a6be`. Attempt 001 remains a separate preserved compile failure; attempt 002 restores its exact missing published header in a fresh root and does not overwrite that history.

Review used source, JSON, hash, exact git-blob and saved-coordinate arithmetic only. No native/guard/query rerun, install, app edit, publication or permission escalation was performed; no permission denial occurred. Owned attempt evidence was left unchanged. Root owns publication of this public-safe checkpoint.

## Durable query preservation

At root request, preserved all four current core fields without rounding or dropping any query. Independently read the exact previously published coffee-evidence.zip Git blob at c79fbd33171f78608f9eb2a1484fbc9266e3a695 and compared its result member against current and saved expected records. All core values and ordered lists are equal; canonical core SHA-256 is `80ed81e3498ab130e2f03e19db783c82d8ce1c58c9793f08405a9bbe7274db82`. QUERY_CORE_RESULT.json file SHA-256 is `166c7caec2b55e5ca09fcc8aca924c0f72690a0b463852aa8a4f3da81464af87` (61,618 bytes). The public source geometry is attributed to Xuqian Ren et al., MuSHRoom iPhone Basic Data, CC BY 4.0. Derived query coordinates are not personal captures; no photos, binary or runtime environment dump is included. This preservation does not alter the result interpretation or add collision/physical validation.

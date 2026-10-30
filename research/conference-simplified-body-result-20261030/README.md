# Conference simplified routes: complete-ID result audit

Actual body comparison completed at source `b8318f7a57fa2389a18ff9a306e25bc6bceec75a`. All six aggregate commands exited zero and retired. No routes were removed. This is an offline conservative-box diagnostic, not a physical navigation pass.

## Result

The simplified paths reduce authored event count from 13,704 to 7,470. Native aggregate time was 36.668327 CPU seconds / 36.709591 wall seconds; peak observed RSS 174,063,616 bytes. Prior complete-ID run took 67.017946 CPU / 67.131563 wall seconds. Timing is descriptive, not a controlled benchmark.

Complete original triangle IDs were independently recounted from both saved runs using only Python stdlib. Reconstructed Float32 mesh bytes, exact authored schedules, terminal payload hashes, candidate-count stream, per-query returned counts and saved old/new face sets agree. The recount did not rerun VTK or independently establish intersection truth.

| Route | Nominal contact events, old → new | Margin contact events, old → new |
|---|---:|---:|
| table 92→120 | 0 → 0 | 855 → 361 |
| table 120→200 | 2 → 2 | 652 → 331 |
| table 200→220 | 2 → 2 | 101 → 68 |
| table 220→20 | 0 → 0 | 119 → 61 |
| table 20→92 | 265 → 241 | 1590 → 1046 |
| VARPU 130→160 | 374 → 253 | 979 → 499 |
| VARPU 160→130 | 376 → 253 | 988 → 499 |

Nominal overlaps therefore remain on five of seven requested routes; all seven retain margin overlaps. Neither count is an arrival or movement success rate.

- Nominal repeated hit occurrences: 8,221 → 5,159. Unique faces: 62 → 59, no newly encountered faces globally; removed IDs 3360, 6583, 6584.
- Margin repeated occurrences: 100,361 → 61,973. Unique faces: 1,015 → 890, no newly encountered faces globally; 125 removed.
- Complete nominal whole-triangle bounds remain low: new minimum −37.86 mm and maximum +39.78 mm across start/end authored foot references. No nominal face was wholly at least 0.5 m above either reference.
- Margin geometry still extends to 1.9123 m above the authored foot plane. There are 349 distinct margin faces wholly at least 0.5 m above start foot somewhere in the new schedule (404 before). 1,377 new-schedule margin-contact events include such a face.

Fewer turns change the number and orientation of conservative swept boxes. Thus fewer events, occurrences or faces do **not** prove greater safety or a repaired floor. Near-foot triangles may be floor representation, true low geometry or other defects; no floor label, obstacle deletion or exemption was applied. The 0.45×0.30×1.60 m nominal body, 15 cm axis margin and 2 mm lower query trim were retained. The 2D clearance circle and 3D axis-inflated box are different shapes.

## Reproduction

Run `python -I -B research/conference-simplified-body-result-20261030/audit_saved_ids.py --pins-sha256 fd9a5c15ea1ebdc82da1bacec344b872a8859c538064d5cf920899e732ecc9bb --out <fresh-workspace-directory>` from the repository or workspace. The audit expects the original local saved contact archives and frozen source inputs. It refuses replacement output and uses one CPU, 30 CPU seconds, a checked 60-second wall budget and 256 MiB observed RSS ceiling. Output is complete `AUDIT.json`; published per-route files are lossless splits of that data, with shared global data in SUMMARY.json. Timing fields can differ on rerun.

The original source helper is hash-bound before import and reconstructs exact registered Float32 vertex/Int32 face buffers. The audit itself performs no NumPy/VTK/SciPy imports. Source, pins and split text results are published; original geometry, compressed contact archives, caches and native binaries are excluded.

## Remaining work

A ground-contact representation comparison is still needed. Current registration remains a historical estimated comparator, not independently verified camera/body alignment. Continuous support, missing-geometry coverage, localization, live sensing, real user heading and physical avoidance remain unestablished. No favorable 90% accuracy or safe route claim follows from these results.

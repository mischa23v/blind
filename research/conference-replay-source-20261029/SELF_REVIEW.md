# Static self-review — source preparation only

No executable tests/native loads/extraction were run. Python files were parsed with`ast.parse`; that is not runtime verification. Root owns independent review and admission.

## Extraction review

- Exact size and full SHA are checked before decompression/member writes. Original archive opened read-only, no symlink following, regular-file requirement; same descriptor SHA checked again afterward with stable inode/size/mtime/ctime.
- Only two named members can be written, to fixed plain filenames in an exclusively created output directory. No extract-all; paths, absolute/parent/backslash/NUL names, duplicates and special/link entries rejected. Source archive's known exact bytes plus tar/decompression/process caps constrain parser input.
- Expected per-member size/hash enforced. Failed and complete receipts distinct, prior output refused, partial files retained. Gzip drained for CRC. Source original archive is never modified.
- Intended input is the completed root-verified archive; a partial/still-writing file fails exact checks. Root has reported completion but this child has not opened/read it.
-60CPU/180wall/384MiB process limits and4MiB per-file limits are not an aggregate process-tree supervisor. Forced SIGKILL/CPU hard-limit death cannot promise a final child-written failure receipt; root supervisor must preserve terminal status. No retries or cleanup are automatic.

## Comparator review

- Every requested coordinate comes from the retained seven-objective inventory; no source-result selection or convenient substitute. Native failed/partial results remain, never completed by drawing a final segment. Complete connector chains require native completeness and both associations.
- Mesh parser preserves vertices and triangle indices; metadata/tiny constants do not insert a floor. Registration is scale1/proper rigid and compared against historical transformed byte hashes **before native engine creation**. The historical transform is not official camera↔Polycam calibration and is labelled in machine output. No corrected occupancy, new fit, FARO, manual support or exclusion enters the worker.
- Existing already-built Coffee002 native class is called with`exclusion=False`; exact eight native config fields and zero marked spans are asserted. Actual rectangular body/margin remain separate unvalidated declarations.
- Graph build and SciPy selector are reused unchanged. Native baseline projected points must exactly match graph endpoint projections. All grid paths retain requested connectors, but no native-wall metric becomes physical clearance. Body/support/2D repaired-arm unavailable state is explicit.
- If any required anchor/graph cannot be built, all seven baselines survive and no difficult endpoint disappears. Per-pair disconnections also remain. No parameter/budget retry, smoothing, scene-specific ranking or path drawing.
- Native handle closed in`finally`; source manifest verified before and after. Early source/cardinality/byte-digest failure before native construction can leave the freshly created output directory without PROPOSALS; root's aggregate supervisor must retain that failure. No scientific import result or binary compatibility is claimed.
- The worker has no standalone execution admission. The added aggregate guard retains the Coffee supervisor and adapts final checks to all seven named pairs, separate body/margin fields, zero exclusion and false physical authority. Root must independently review and bind its manifest/source commit before execution. Seven non-main supervisor helper function bodies were checked byte-for-byte unchanged; this static check is not a runtime test.

## Known limits retained

Historical transform derives from phone TSDF expressed with old floorfix R/t, not an official alignment. Same-capture reserved landmarks are not independent physical validation. Native endpoint queries and archived geometry do not establish support, floor semantics, live body pose, unknown-obstacle coverage or currentness. Current comparison cannot report a successful lap/entry/return without the separate fullbody/movement stages. No extra scenes are claimed.

# Coffee tabletop retention: prepared implementation source

**Source checkpoint only. Nothing in this directory has been executed, imported as native code, built or wired into the app.** Root owns publication and later execution admission. This narrows the user's actual table-corner fix to a measurable missing-geometry step, rather than adjusting a route through an unchanged incomplete mesh.

## Implemented source

`retention.py` Stage A reads hash-pinned original processed depth rasters and original per-frame intrinsics. It projects **every positive pixel strictly below the frozen 4 m range**, without image resizing, flipping, semantic crop or floor-band clearing. Whole original raster bytes remain untouched. Range-excluded and zero returns are counted as unknown. Frozen RGB-selected patch annotations enter only evaluator reporting after full-frame projection. The previous three signed floor-relative tabletop medians must reproduce within a numerical 1e-9 m tolerance (not a claimed sensor tolerance).

Stage B uses the **unchanged published OctoMap ctypes wrapper and C++ measured-ray adapter** copied here, pinned by `SOURCE_PINS.json`. Each frame starts an independent camera-local tree; no pose guess or cross-view fusion. All projected in-range points enter one native scan from the calibrated optical origin, before tabletop membership is evaluated. Native actual keys, occupied-wins semantics, one scan vote per key and table-key retention are checked. No fitted floor is passed to OctoMap. Querying an untouched volume must remain unknown. Float64→Float32 differences and actual native key hashes are retained. Native call/table-key failure is a failed receipt, not permission to erase a table.

The retained 4 m gate is inherited from the frozen processed-depth diagnostic, NOT native sensor confidence filtering. This is camera-local simulation/reconstruction evidence with supplied calibration, **not autolocation**. RGB annotations are evaluator-only, not mapper input or obstacle-generation geometry. All three frames were already used for issue discovery: they are regression cases, not statistically held-out accuracy data. `test_retention.py` supplies separate synthetic negative/held-out policy controls; none has run. Future held-out real sequences remain required.

## Existing code selected

Repository source at baseline `dce21dc937dfd0423f7721a23597bd4e33085b2b`:
`research/koivu-octomap-v2/workspaces/blind-octomap-reuse-08/{octomap_adapter.cpp,octomap_engine.py,ADAPTER_PROTOCOL.md}`.
Upstream OctoMap v1.10.0, `007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f`, New BSD/3-clause; [upstream license](https://github.com/OctoMap/octomap/blob/007a0b5b6e4d3bb6c54f2c65a12234e03adcd72f/octomap/LICENSE.txt). The C++ adapter retains an actual measured representative for each native key; it does not use synthetic voxel-center rays or new occupancy/search code. Keep upstream attribution for any later binary distribution.

Historical build-04 library SHA256 `3c0a88593d07540d93dbbc3e404ee44b3f5167ff7bda74f16fc8075aab83b1db` is required by this source. It has not been located or loaded here. No native sources/dependencies were newly downloaded. Reading already published tracked adapter text in the sparse repository is not executing its setup instructions. Rebuilding from existing source/compiler would need a separately reviewed build receipt and deliberate new binary pin; do not substitute a hash silently.

## Proposed bounded execution, NOT executed/authorized by this file

1. Review source and pins. Existing Python/NumPy/Pillow only. Stage A: 30 CPU s, 512 MiB address space, 60 s outer wall deadline; serial three frames. Do not install anything. Original source raster/transformations are not in this sparse packet; root must provide already retained exact bytes. Missing bytes are a blocker, not a download instruction.
2. Prepared source controls: `python -m unittest discover -s research/coffee-table-retention-source-20261029 -p test_retention.py`. This checkpoint has not run it.
3. Stage A command:
   `python retention.py --stage A --depth-dir EXISTING_DEPTH --transformations EXISTING_TRANSFORMATIONS --diagnostic-dir ../coffee-table-depth-diagnostic-20261029 --output NEW_STAGE_A.json`
4. Stage B only after source/Stage A review and an explicitly permitted native call: same command with `--stage B --native-library EXISTING_HASH_VERIFIED_LIB`. 120 CPU s, 512 MiB, 180 s outer wall deadline, serial, no retry or bound increase; parent runner must enforce wall/output limits. A resource stop is inconclusive, not successful retention. No build command or network fallback is included.
5. Output is a new receipt (refuses overwrite); preserve failed/incomplete receipts and original data, never publish raw captures through this source checkpoint. Hard process kills may precede final receipt flush, so retain parent exit/resource evidence. Failure does not authorize another run.

**Stage C is intentionally absent:** original camera/depth→Polycam mesh registration and measured tabletop corner extent are still unverified. Inset patches cannot define the corner. This cannot validate the longest historical route or claim 90% accuracy. User's visually rejected corner-clipping route stays rejected. Native confidence, synchronization and processing details remain unavailable; no synthetic confidence 2, tracking state, zero uncertainty, floor fill, mesh repair or route acceptance is emitted.

`FRESH_DEPTH_VETO_INTERFACE.md` proposes the minimal additive route-veto seam without active wiring. Occupied evidence can reject a candidate; it can never grant physical clearance.

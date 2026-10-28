# Established geometry import / scale / scene-graph references

**Current actual result (16:50 UTC):** both exact native exported USDZs were read with official OpenUSD and independently rechecked. Authored meter/Y-up units and all 24 source feature transforms are preserved; the first native rejection is planar source bounds versus exporter-provided thickness and in-plane extensions. [Actual results and limits](run40726507227/RESULTS.md), [machine-readable comparison](run40726507227/COMPARISON.json). No production geometry gate or routing change was made.

Research snapshot: 2026-10-28. No app edits, importer replacement, mesh simplification, route tuning or new CI workflow. The user subsequently authorized the single official OpenUSD reader dependency; it is installed only in this research workspace. This is a focused catalog, not every repository and not a claim that any implementation is universally correct. License labels summarize inspected files, not legal advice or permission for unchecked dependency/data reuse.

## 15:29 UTC installation update

The user approved the official reader, relayed by the owner at 15:27:31 UTC. The exact 26.5 wheel was downloaded, its byte count and SHA256 checked, then installed with `--no-deps --no-index --only-binary=:all: --no-compile --target runtime/site-packages`. Import smoke succeeded: `Usd.GetVersion() == (0,26,5)`, approximately 0.14 seconds, 93,164 KiB peak RSS, one requested USD worker. Installed RECORD hashes and license bytes were checked; see `OPENUSD_INSTALL_RECEIPT.json`. `OPENUSD_WHEEL_METADATA.json` and `CAPABILITIES.json` retain the earlier pre-install research observations, not the new installation state. The runtime and wheel are gitignored and must not be published with the research report.

At the 15:29 checkpoint, `inspect_public_usdz.py` was the prepared read-only comparator wrapper; Python syntax parsing and `--help` passed, but actual retained native bytes were still pending. The file uses upstream import, transform and bounds functions; its new admission/reporting glue is not represented as proven upstream code. Later actual results are linked above. The native owner retained exact diagnostic export #2, not the deleted production export #1.

Invocation once the native owner supplies exact export files and hashes:

```sh
PYTHONPATH=runtime/site-packages PXR_WORK_THREAD_LIMIT=1 OMP_NUM_THREADS=1 \
  timeout 60s python inspect_public_usdz.py \
  --fixture Hallway2 --source ../../ios/BlindAssistTests/Fixtures/RoomPlanApple/Hallway2.capturedRoom.json \
  --usdz /path/to/APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT.usdz \
  --metadata /path/to/APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT_METADATA.bin \
  --manifest /path/to/APPLE_ROOM_ROUTE_SAME_EXPORT_MANIFEST.json \
  --inventory /path/to/APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json \
  --manifest-sha256 HASH_FROM_VERIFIED_NATIVE_ARTIFACT_COLLECTION \
  --output hallway-openusd-reference.json
```

Run from this directory. Preserve the exact native manifest/attachment and output hashes; use its hashes rather than self-declaring changed bytes acceptable. The wrapper's output sets `geometryAgreementEstablished:false` because import success alone does not establish agreement with the app.

## Decision and measured blockers

**Use the exact same exported public-fixture USDZ as the comparison input.** The current test exports twice: production adapter export, then diagnostic export. Those are separate files. The immediate comparator can compare Model I/O and SceneKit/OpenUSD against the *same diagnostic export*; it must not claim those bytes were the previously deleted production export. Bind the comparison to SHA256 of the actual shared bytes. Prefer retaining a single export and feeding all importers that file in the test harness.

At the initial capability check, the local executor had no usable USD reader: Blender 4.3.2 is present but `bpy.app.build_options.usd` is false; there is no `wm.usd_import` operator and no default-Python `pxr` module. Assimp 5.4.3 is present as a shared library, but `aiIsExtensionSupported` returns false for USD/USDA/USDC/USDZ. No USD files existed in the local partial project or three downloaded artifact ZIPs inspected. These were capability checks only, not successful scene imports. The later isolated OpenUSD installation above supersedes the runtime blocker.

Official `usd-core==26.5` was the smallest identified reference-runtime option for this Linux/Python 3.12 executor. Its pinned wheel is 28,743,527 bytes (27.41 MiB), 212,436,929 bytes unpacked (202.60 MiB), 215 entries, with no Python dependency list. Download plus unpacked payload is about 230 MiB. Before authorization, size was measured from only the last 65,536 bytes of its ZIP directory; no package was installed then. Exact metadata/hash is in `OPENUSD_WHEEL_METADATA.json`; the subsequent approved installation is recorded above. Version 25.5.1 was rejected because its PyPI metadata reports a use-after-free fixed in 25.11; 26.5 metadata reports no known vulnerability, which is not a security guarantee.

## Reference catalog

### Permissive / permissive-style licensed sources

1. **OpenUSD v26.05 (Pixar / AOUSD reference implementation).** [License](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.05/LICENSE.txt): Tomorrow Open Source Technology License 1.0, derived from Apache 2.0 with a different trademark section; included third-party notices also matter. [XformCache](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.05/pxr/usd/usdGeom/xformCache.cpp) implements `GetLocalToWorldTransform`, `GetParentToWorldTransform`, and ancestor composition honoring `resetXformStack`. [Metrics](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.05/pxr/usd/usdGeom/metrics.cpp) provides authored/fallback `metersPerUnit` and `upAxis`; un-authored length units default to centimeters, not meters. [`BBoxCache`](https://openusd.org/release/api/class_usd_geom_b_box_cache.html) provides world bounds. Upstream [transform tests](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.05/pxr/usd/usdGeom/testenv/testUsdGeomXformCache.cpp) and [bounds tests](https://github.com/PixarAnimationStudios/OpenUSD/blob/v26.05/pxr/usd/usdGeom/testenv/testUsdGeomBBoxCache.py) were source-inspected, not run here. Best first comparator: it bypasses our custom MDL packing and transform glue. Apple may internally use USD code too, so this is not a promise of unrelated backend ancestry. It neither measures the physical room nor establishes clearance.

2. **Unity USD SDK `Release-3.0.0-exp.5`.** Actual [root license](https://github.com/Unity-Technologies/usd-unity-sdk/blob/Release-3.0.0-exp.5/LICENSE.md) and [package license](https://github.com/Unity-Technologies/usd-unity-sdk/blob/Release-3.0.0-exp.5/package/com.unity.formats.usd/LICENSE.md): Apache 2.0. [`XformImporter.cs`](https://github.com/Unity-Technologies/usd-unity-sdk/blob/Release-3.0.0-exp.5/package/com.unity.formats.usd/Runtime/Scripts/IO/Geometry/XformImporter.cs): `BuildXform` writes local position/rotation/scale; basis conversion and `BuildSceneRoot` handle handedness/up-axis/global scale separately. This is useful released integration code to learn from, but its package is [deprecated](https://github.com/Unity-Technologies/usd-unity-sdk/blob/dev/README.md) since November 2024. [Current Unity importer documentation](https://docs.unity3d.com/Packages/com.unity.importer.usd@1.0/manual/index.html) identifies replacement packages; do not assume the replacement has the old code's license. Unity uses OpenUSD and is not an independent USD parser family. No Unity runtime was available or executed.

3. **Assimp v6.0.2 + its pinned tinyusdz parser.** Actual Assimp [LICENSE](https://github.com/assimp/assimp/blob/v6.0.2/LICENSE): BSD-3-Clause-style terms with additional included notices. [`USDLoader.cpp`](https://github.com/assimp/assimp/blob/v6.0.2/code/AssetLib/USD/USDLoader.cpp) and [`USDLoaderImplTinyusdz.cpp`](https://github.com/assimp/assimp/blob/v6.0.2/code/AssetLib/USD/USDLoaderImplTinyusdz.cpp) use tinyusdz to read USDZ and construct per-node `mTransformation` from the parser's local matrix. USD support is opt-in at build time. [CMake pin](https://github.com/assimp/assimp/blob/v6.0.2/code/CMakeLists.txt) is tinyusdz commit `6050eef932f7d2788656d63297aa488fb0961ed1`. The repository now redirects to LightUSD; its exact-commit [LICENSE](https://github.com/lighttransport/LightUSD/blob/6050eef932f7d2788656d63297aa488fb0961ed1/LICENSE) is Apache 2.0. [`BuildXformNodeFromStageRec`](https://github.com/lighttransport/LightUSD/blob/6050eef932f7d2788656d63297aa488fb0961ed1/src/tydra/scene-access.cc) separately records local, parent-world and world matrices, honoring reset stacks. This offers a different parser family, but explicit unit normalization was not established in the inspected Assimp adapter; do not treat raw numeric agreement or disagreement as meter agreement without metadata. Dependency notices remain separately reviewable; no install/build/run occurred.

4. **Godot 4.5-stable.** [LICENSE.txt](https://github.com/godotengine/godot/blob/4.5-stable/LICENSE.txt): MIT. [`Node3D`](https://github.com/godotengine/godot/blob/4.5-stable/scene/3d/node_3d.cpp) implements `get_global_transform`, `to_global`, `to_local`, and `set_global_transform`, demonstrating parent-times-local composition and inverse conversion in a released game engine. Useful for avoiding parent-transform/double-transform bugs; not a native same-USDZ comparator, not a reconstruction system, not executed here.

### Copyleft sources: learn / compare; do not paste into the app unchecked

5. **Blender v4.4.0 USD importer.** Relevant files explicitly carry GPL-2.0-or-later. [`usd_capi_import.cc`](https://github.com/blender/blender/blob/v4.4.0/source/blender/io/usd/intern/usd_capi_import.cc) multiplies user import scale by stage `metersPerUnit` when requested. [`usd_reader_stage.cc`](https://github.com/blender/blender/blob/v4.4.0/source/blender/io/usd/intern/usd_reader_stage.cc) configures Y-up to Blender Z-up conversion and scene scale. [`USDXformReader::read_matrix`](https://github.com/blender/blender/blob/v4.4.0/source/blender/io/usd/intern/usd_reader_xform.cc) applies global scale/axis conversion at root objects only, allowing parenting to propagate it. This is exactly the reference needed to avoid scaling each ancestor and child twice. [`bl_usd_import_test.py`](https://github.com/blender/blender/blob/v4.4.0/tests/python/bl_usd_import_test.py) contains upstream integration tests; inspected, not run. Blender uses OpenUSD. It is a valuable independent application comparator, but not an unrelated USD parser. The local 4.3.2 build has no USD support.

### Proprietary platform APIs / source not supplied

6. **Apple RoomPlan + SceneKit (existing Apple SDK).** [`CapturedRoom.export`](https://developer.apple.com/documentation/roomplan/capturedroom/export(to:metadataurl:modelprovider:exportoptions:)) produces the USD asset with optional metadata and model provider. [`SCNNode.simdConvertPosition(_:to:)`](https://developer.apple.com/documentation/scenekit/scnnode/simdconvertposition(_:to:)) converts a local point to scene-world coordinates when the destination is nil. [`convertUnitsToMeters`](https://developer.apple.com/documentation/scenekit/scnscenesource/loadingoption/convertunitstometers) takes a numeric meters-per-source-unit factor (not a Boolean); omission means no requested unit conversion. SceneKit is a second SDK API path available to existing native CI, not evidence of an independent underlying importer. Proprietary SDK terms apply; undocumented importer source was not available, and this is not 'unlicensed code'.

### Missing / unknown licenses

No unlicensed example is represented as safe to copy in this catalog. Public visibility is not a license. Missing or unclear permission would make an example read-only research until clarified; the same separately applies to model/data licenses. We did not pad the list with unverified snippets.

## Concrete same-byte comparison plan (not executed)

1. In the existing public-fixture test, retain the exact diagnostic `room.usdz` and exact metadata bytes before deferred temp-directory deletion. Do not regenerate a different USDZ for the other reader. Admission remains the hardcoded original Hallway2 or Bedroom3 source SHA **before** decoding/export, `modelProvider:nil`, `.mesh`, no private source path. Cap file sizes before reading; use the current 32 MiB export / 1 MiB metadata maxima or stricter documented caps. Preserve SHA256, byte counts, fixture ID/source SHA, OS/Xcode, export options and attachment names in a manifest. Verify ZIP members contain only expected geometry/metadata assets; do not silently strip or change bytes. KeepAlways XCTest attachments can use the existing artifact pipeline, not a new workflow.
2. Feed the same meshURL to Model I/O and `SCNScene(url:options:)` while it exists. Use `.flattenScene:false`; record requested axis/unit options explicitly and initially request no normalization (`.convertToYUp:false`, omit `.convertUnitsToMeters`). Traverse all geometry nodes independently by metadata identity/ancestor mapping; record local/world matrices, pivots, local geometry bounds, transformed eight-corner enclosure, vertex/primitive counts, and parent paths. A transformed local AABB is only an enclosure; it is not always the tight world vertex bound. This path bypasses custom MDL vertex packing and matrix application, but Apple's internal backend independence is unknown.
3. Once an owner-authorized OpenUSD runtime exists, read that retained SHA-matched file with `Usd.Stage.Open`. Use `UsdGeom.GetStageMetersPerUnit`, `StageHasAuthoredMetersPerUnit`, `GetStageUpAxis`, `XformCache.GetLocalTransformation`, `GetParentToWorldTransform`, `GetLocalToWorldTransform`, and `BBoxCache.ComputeWorldBound(...).ComputeAlignedRange()`. For tight vertex bounds, use `UsdGeom.Mesh.GetPointsAttr().Get(time)` and **OpenUSD's** `GfMatrix4d.Transform` to world space, then `Gf.Range3d.UnionWith` (not a home-grown matrix implementation). Report authored extent/cache bound and tight world-vertex bound separately; authored extent may itself be wrong. Account for instance proxies, time samples, visibility and purpose explicitly; reject unsupported structures rather than silently drop them.
4. Preserve every floor/wall/furniture feature separately. Emit raw stage-world units and separately labeled world meters; apply the stage meters-per-unit factor once to final world-space coordinates, never independently to every local translation and mesh again. Do not assume Y-up, auto-center, auto-fit, normalize to a unit cube, flatten parent transforms twice, or infer feature identity from nearest geometry. Compare per-feature centers, orientations, dimensions, floor heights and pairwise spacing before merging anything.
5. Only after source fixture, exported reference scene and app import agree should mesh reduction be considered. No path tuning belongs in this stage. Bounding-box equality alone cannot prove wall openings, topology, surfaces, clearance or physical accuracy. A route result cannot validate the geometry that generated it.

## Small reference API invocation

This is proposed wrapper glue around upstream APIs, not a new importer and not claimed executed:

```python
from pxr import Usd, UsdGeom
stage = Usd.Stage.Open(exact_sha_checked_usdz)
time = Usd.TimeCode.Default()
xforms = UsdGeom.XformCache(time)
bounds = UsdGeom.BBoxCache(time, [UsdGeom.Tokens.default_, UsdGeom.Tokens.render], False)
meters_per_unit = UsdGeom.GetStageMetersPerUnit(stage)
up_axis = UsdGeom.GetStageUpAxis(stage)
for prim in stage.Traverse():
    if prim.IsA(UsdGeom.Mesh):
        matrix = xforms.GetLocalToWorldTransform(prim)
        aligned_stage_world = bounds.ComputeWorldBound(prim).ComputeAlignedRange()
        # Record matrix + raw bound + metadata; use Gf matrix.Transform for exact points.
```

This original illustrative snippet does not implement manifest admission, complete instance traversal or budgets. The subsequently reviewed wrapper and actual 16:50 comparison linked above supersede this preparation-only checkpoint.

#!/usr/bin/env python3
"""Read-only evidence wrapper around official OpenUSD; not a geometry importer.

Requires unchanged admitted Apple public source and separately supplied exact
native-export hashes. It never changes scale, origin, up-axis, topology or mesh
vertices. Bounds are upstream OpenUSD/Gf results. No routing or mesh repair.
"""
import argparse
from collections import Counter
import hashlib
import io
import json
import math
import os
from pathlib import Path
import plistlib
import resource
import tempfile
import time
import uuid
import zipfile

PUBLIC = {
    "Hallway2": "f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d",
    "Bedroom3": "44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e",
}
MAX_NODES, MAX_VERTICES, MAX_FACES = 4096, 200_000, 100_000


def admitted_bytes(path, expected_sha, limit):
    if not path.is_file() or not 0 < path.stat().st_size <= limit:
        raise ValueError("file byte budget")
    data = path.read_bytes()
    if len(data) > limit or hashlib.sha256(data).hexdigest() != expected_sha:
        raise ValueError("input SHA256 mismatch")
    return data


def vector(value):
    out = [float(v) for v in value]
    if not all(math.isfinite(v) and abs(v) <= 10_000 for v in out):
        raise ValueError("nonfinite or out-of-budget coordinate")
    return out


def matrix(value):
    # Explicit row-major Gf representation, not Apple's column-major array.
    return [vector(value[row]) for row in range(4)]


def bounds(value):
    if value.IsEmpty():
        return None
    return {"minimum": vector(value.GetMin()), "maximum": vector(value.GetMax())}


def inspect(args, private_root):
    start = time.monotonic()
    manifest_bytes = admitted_bytes(args.manifest, args.manifest_sha256, 16_384)
    manifest = json.loads(manifest_bytes)
    fixed_manifest_values = {
        "schema": "blind.saved-room-route-same-export.v1", "physicalAuthority": False,
        "exportRole": "diagnostic-export", "productionAdapterExport": "separate-unretained",
        "testIdentifier": "SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison",
        "inventoryAttachmentName": "APPLE_ROOM_ROUTE_MESH_METADATA_INVENTORY.json",
    }
    if any(manifest.get(key) != value for key, value in fixed_manifest_values.items()):
        raise ValueError("native same-export manifest identity mismatch")
    records = manifest.get("fixtures", [])
    if len(records) != 2 or {record.get("fixtureID") for record in records} != set(PUBLIC):
        raise ValueError("native manifest must bind exactly both original public fixtures")
    for record in records:
        fixture = record["fixtureID"]
        if (record["sourceSHA256"] != PUBLIC[fixture]
                or record["assetAttachmentName"] != f"APPLE_ROOM_ROUTE_{fixture}_SAME_EXPORT.usdz"
                or record["metadataAttachmentName"] != f"APPLE_ROOM_ROUTE_{fixture}_SAME_EXPORT_METADATA.bin"):
            raise ValueError("native manifest source/attachment binding mismatch")
        if not 0 < record["assetByteCount"] <= 4 * 1024 * 1024 or not 0 < record["metadataByteCount"] <= 64 * 1024:
            raise ValueError("native export byte budget")
    record = next(record for record in records if record["fixtureID"] == args.fixture)
    inventory_bytes = admitted_bytes(args.inventory, manifest["inventorySHA256"], 131_072)
    inventory = json.loads(inventory_bytes)
    if (inventory.get("schema") != "blind.saved-room-route-mesh-metadata-inventory.v1"
            or inventory.get("physicalAuthority") is not False):
        raise ValueError("native inventory schema mismatch")
    native_rows = inventory.get("fixtures", [])
    if len(native_rows) != 2 or {row.get("fixtureID") for row in native_rows} != set(PUBLIC):
        raise ValueError("native inventory public fixture membership mismatch")
    for row in native_rows:
        if row["sourceSHA256"] != PUBLIC[row["fixtureID"]]:
            raise ValueError("native inventory source binding mismatch")
    native_inventory = next(row for row in native_rows if row["fixtureID"] == args.fixture)
    args.usdz_sha256, args.metadata_sha256 = record["assetSHA256"], record["metadataSHA256"]
    source = admitted_bytes(args.source, PUBLIC[args.fixture], 8 * 1024 * 1024)
    usdz = admitted_bytes(args.usdz, args.usdz_sha256, 4 * 1024 * 1024)
    metadata = admitted_bytes(args.metadata, args.metadata_sha256, 64 * 1024)
    if len(usdz) != record["assetByteCount"] or len(metadata) != record["metadataByteCount"]:
        raise ValueError("native manifest byte count mismatch")
    source_json = json.loads(source)
    source_features = {}
    for group in ("floors", "walls", "doors", "windows", "openings", "objects"):
        for feature in source_json.get(group, []):
            identity = str(uuid.UUID(feature["identifier"]))
            if identity in source_features:
                raise ValueError("duplicate original feature identity")
            source_features[identity] = {
                "kind": group, "dimensions": feature["dimensions"],
                "transformColumnMajor": feature["transform"],
                "polygonCorners": feature.get("polygonCorners", []),
                "category": feature.get("category"),
            }
    metadata_format = "binaryPlist" if metadata.startswith(b"bplist00") else "json"
    if metadata_format != record["metadataFormat"] or metadata_format != native_inventory["metadataFormat"]:
        raise ValueError("native metadata format binding mismatch")
    raw_metadata = plistlib.loads(metadata) if metadata_format == "binaryPlist" else json.loads(metadata)
    if not isinstance(raw_metadata, dict) or not 0 < len(raw_metadata) <= MAX_NODES:
        raise ValueError("metadata dictionary budget")
    identities = {}
    for name, identity in raw_metadata.items():
        if not isinstance(name, str) or not 0 < len(name.encode()) <= 512:
            raise ValueError("metadata name budget")
        identity = str(uuid.UUID(identity))
        if identity not in source_features:
            raise ValueError("metadata names a non-public feature")
        identities[name] = identity
    with zipfile.ZipFile(io.BytesIO(usdz)) as archive:
        members = archive.infolist()
        if not 0 < len(members) <= 512 or sum(m.file_size for m in members) > 64 * 1024 * 1024:
            raise ValueError("archive budget")
        for member in members:
            name = Path(member.filename)
            if name.is_absolute() or ".." in name.parts or name.suffix.lower() not in (".usd", ".usdc", ".usda"):
                raise ValueError("not a geometry-only public USD archive")
            if member.flag_bits & 1 or (member.external_attr >> 16) & 0o170000 == 0o120000:
                raise ValueError("encrypted or symlink archive member")
    # Import only after source, exact exported bytes and archive admission.
    os.environ.setdefault("PXR_WORK_THREAD_LIMIT", "1")
    from pxr import Usd, UsdGeom, Gf
    # Stage.Open resolves a filename. Never reopen the mutable supplied path:
    # import a 0700-directory copy of the already SHA-admitted exact bytes.
    admitted_usdz = private_root / "admitted-public-export.usdz"
    admitted_usdz.write_bytes(usdz)
    stage = Usd.Stage.Open(str(admitted_usdz))
    if not stage:
        raise ValueError("OpenUSD could not open stage")
    sample_time = Usd.TimeCode.Default()
    xforms = UsdGeom.XformCache(sample_time)
    purposes = [UsdGeom.Tokens.default_, UsdGeom.Tokens.render, UsdGeom.Tokens.proxy, UsdGeom.Tokens.guide]
    bbox_cache = UsdGeom.BBoxCache(sample_time, purposes, False, True)
    meters_per_unit = float(UsdGeom.GetStageMetersPerUnit(stage))
    if not math.isfinite(meters_per_unit) or not 0 < meters_per_unit <= 1000:
        raise ValueError("stage units out of budget")
    # PrimRange with instance proxies asks upstream to enumerate instance content.
    prims = []
    for prim in Usd.PrimRange(stage.GetPseudoRoot(), Usd.TraverseInstanceProxies()):
        if len(prims) >= MAX_NODES:
            raise ValueError("stage node budget")
        prims.append(prim)
    inherited = {}
    nodes, meshes, per_feature = [], [], {}
    vertex_total = face_total = 0
    scene_points = Gf.Range3d()
    scene_meters = Gf.Range3d()
    for prim in prims:
        if prim.IsPseudoRoot():
            continue
        # Even one numeric sample may differ from Default while the cheaper
        # ValueMightBeTimeVarying query returns false. A static-room comparison
        # therefore rejects all sampled/spline attributes, never guesses time.
        for attribute in prim.GetAttributes():
            if attribute.GetNumTimeSamples() > 0 or attribute.HasSpline():
                raise ValueError("sampled or spline attribute unsupported by static-room comparator")
        path, parent = str(prim.GetPath()), str(prim.GetParent().GetPath())
        direct = identities.get(str(prim.GetName()))
        identity = direct or inherited.get(parent)
        inherited[path] = identity
        local, resets = xforms.GetLocalTransformation(prim)
        world = xforms.GetLocalToWorldTransform(prim)
        imageable = UsdGeom.Imageable(prim)
        node = {
            "path": path, "parent": parent, "type": str(prim.GetTypeName()),
            "name": str(prim.GetName()), "directFeatureID": direct,
            "resolvedFeatureID": identity, "instanceProxy": prim.IsInstanceProxy(),
            "resetsXformStack": resets, "localMatrixRows": matrix(local),
            "parentWorldMatrixRows": matrix(xforms.GetParentToWorldTransform(prim)),
            "worldMatrixRows": matrix(world),
            "purpose": str(imageable.ComputePurpose()) if imageable else None,
            "visibility": str(imageable.ComputeVisibility(sample_time)) if imageable else None,
        }
        if UsdGeom.Xformable(prim) and UsdGeom.Xformable(prim).TransformMightBeTimeVarying():
            raise ValueError("animated transforms unsupported by static-room comparator")
        nodes.append(node)
        if not prim.IsA(UsdGeom.Mesh):
            if prim.IsA(UsdGeom.PointInstancer):
                raise ValueError("point-instanced room geometry needs separate upstream expansion")
            if prim.IsA(UsdGeom.Boundable):
                raise ValueError("non-mesh boundable: do not silently omit geometry")
            continue
        mesh = UsdGeom.Mesh(prim)
        if mesh.GetPointsAttr().ValueMightBeTimeVarying():
            raise ValueError("animated vertices unsupported by static-room comparator")
        points = mesh.GetPointsAttr().Get(sample_time)
        counts = mesh.GetFaceVertexCountsAttr().Get(sample_time)
        indices = mesh.GetFaceVertexIndicesAttr().Get(sample_time)
        if points is None or counts is None or indices is None:
            raise ValueError("mesh geometry absent")
        vertex_total += len(points)
        face_total += len(counts)
        if vertex_total > MAX_VERTICES or face_total > MAX_FACES or len(indices) > 4 * MAX_FACES:
            raise ValueError("geometry budget")
        if sum(counts) != len(indices) or any(n < 3 for n in counts) or any(i < 0 or i >= len(points) for i in indices):
            raise ValueError("invalid face topology")
        local_points, world_points, meter_points = Gf.Range3d(), Gf.Range3d(), Gf.Range3d()
        for p in points:
            local_point = Gf.Vec3d(*vector(p))
            world_point = world.Transform(local_point)
            vector(world_point)
            meter_point = world_point * meters_per_unit
            vector(meter_point)
            local_points.UnionWith(local_point)
            world_points.UnionWith(world_point)
            meter_points.UnionWith(meter_point)
            scene_points.UnionWith(world_point)
            scene_meters.UnionWith(meter_point)
            if identity:
                per_feature.setdefault(identity, Gf.Range3d()).UnionWith(meter_point)
        cached = bbox_cache.ComputeWorldBound(prim).ComputeAlignedRange()
        meshes.append({
            "path": path, "featureID": identity, "vertexCount": len(points), "faceCount": len(counts),
            "faceVertexCountHistogram": {str(n): count for n, count in sorted(Counter(counts).items())},
            "orientation": str(mesh.GetOrientationAttr().Get()),
            "subdivisionScheme": str(mesh.GetSubdivisionSchemeAttr().Get()),
            "authoredExtent": [vector(v) for v in (mesh.GetExtentAttr().Get(sample_time) or [])],
            "localVertexBounds": bounds(local_points), "worldVertexBoundsStageUnits": bounds(world_points),
            "worldVertexBoundsMeters": bounds(meter_points), "cachedWorldBoundStageUnits": bounds(cached),
            "localPositions": [vector(p) for p in points],
            "worldPositions": [vector(world.Transform(Gf.Vec3d(*p))) for p in points],
            "faceVertexCounts": list(counts), "faceVertexIndices": list(indices),
            "holeIndices": list(mesh.GetHoleIndicesAttr().Get(sample_time) or []),
            "firstVertexLocal": vector(points[0]) if points else None,
            "firstVertexWorldStageUnits": vector(world.Transform(Gf.Vec3d(*points[0]))) if points else None,
        })
    if not meshes:
        raise ValueError("no mesh geometry imported")
    if hashlib.sha256(admitted_usdz.read_bytes()).hexdigest() != args.usdz_sha256:
        raise ValueError("admitted import bytes changed")
    used_layers = stage.GetUsedLayers()
    for layer in used_layers:
        if layer == stage.GetSessionLayer():
            continue
        identifier = layer.identifier
        if identifier != str(admitted_usdz) and not identifier.startswith(str(admitted_usdz) + "["):
            raise ValueError("composed USD layer outside admitted same-export package")
    return {
        "schema": "public-openusd-geometry-reference-v1", "fixtureID": args.fixture,
        "nativeManifestSHA256": hashlib.sha256(manifest_bytes).hexdigest(),
        "nativeInventorySHA256": hashlib.sha256(inventory_bytes).hexdigest(),
        "nativeTestIdentifier": manifest["testIdentifier"], "exportRole": manifest["exportRole"],
        "productionAdapterExport": manifest["productionAdapterExport"],
        "nativeAdapterFailure": native_inventory.get("adapterFailure"),
        "nativeMDLGeometryProbe": native_inventory.get("geometryProbe"),
        "sourceSHA256": PUBLIC[args.fixture], "usdzSHA256": hashlib.sha256(usdz).hexdigest(),
        "metadataSHA256": hashlib.sha256(metadata).hexdigest(), "usdzByteCount": len(usdz),
        "metadataByteCount": len(metadata), "openUSDVersion": Usd.GetVersion(),
        "stageMetersPerUnit": meters_per_unit, "metersPerUnitAuthored": UsdGeom.StageHasAuthoredMetersPerUnit(stage),
        "stageUpAxis": str(UsdGeom.GetStageUpAxis(stage)), "upAxisAuthored": stage.HasAuthoredMetadata("upAxis"),
        "meterConversionBasis": "authored stage metadata" if UsdGeom.StageHasAuthoredMetersPerUnit(stage)
                                else "OpenUSD fallback units, not independently measured room scale",
        "meterConversionIsMeasurement": False,
        "coordinatePolicy": "No axis/scale/origin edits; raw world and labeled one-time meter conversion reported separately",
        "matrixEncoding": "row-major Gf matrices; Gf uses row-vector transform convention",
        "boundsPolicy": "all mesh points; all purposes and visibility included; cached extents and tight vertex bounds separate",
        "archiveMembers": [{"name": m.filename, "bytes": m.file_size} for m in members],
        "externalLayerPolicy": "reject non-session composed layers outside admitted same-export package",
        "usedLayers": [layer.identifier.replace(str(private_root), "<admitted-public-export-directory>")
                       for layer in used_layers],
        "nodes": nodes, "meshes": meshes, "nodeCount": len(nodes), "meshCount": len(meshes),
        "vertexCount": vertex_total, "faceCount": face_total,
        "unmatchedMeshCount": sum(m["featureID"] is None for m in meshes),
        "overallWorldVertexBoundsStageUnits": bounds(scene_points), "overallWorldVertexBoundsMeters": bounds(scene_meters),
        "perFeatureWorldVertexBoundsMeters": {key: bounds(value) for key, value in sorted(per_feature.items())},
        "originalFeaturesWithoutImportedMesh": sorted(set(source_features) - set(per_feature)),
        "originalPublicFeatures": source_features, "originalEncoding": "raw source JSON numbers, not native decoded Float32",
        "elapsedSeconds": time.monotonic() - start, "peakRSSKiB": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        "geometryAgreementEstablished": False, "physicalAuthority": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", choices=PUBLIC, required=True)
    for name in ("source", "usdz", "metadata", "manifest", "inventory", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--manifest-sha256", required=True,
                        help="Expected manifest hash from verified native artifact collection")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="blind-openusd-public-") as directory:
        report = inspect(args, Path(directory))
    payload = json.dumps(report, indent=2, allow_nan=False).encode() + b"\n"
    if len(payload) > 2 * 1024 * 1024:
        raise ValueError("report byte budget")
    args.output.write_bytes(payload)
    print(json.dumps({"status": "reference_scene_read", "output": str(args.output),
                      "meshCount": report["meshCount"], "unmatchedMeshCount": report["unmatchedMeshCount"],
                      "geometryAgreementEstablished": False}))


if __name__ == "__main__":
    main()

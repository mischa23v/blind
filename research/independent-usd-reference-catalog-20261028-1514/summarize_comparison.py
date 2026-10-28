#!/usr/bin/env python3
"""Summarize observed reference evidence; no geometry is rebuilt or altered."""
from collections import Counter
import hashlib
import itertools
import json
import math
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "run40726507227"


def f32(value):
    return struct.unpack("<f", struct.pack("<f", value))[0]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def summarize(fixture):
    path = OUT / f"{fixture}-openusd-reference.json"
    reference = json.loads(path.read_text())
    rows, source_anchors, imported_anchors = [], [], []
    for mesh in reference["meshes"]:
        identity = mesh["featureID"]
        source = reference["originalPublicFeatures"][identity]
        node = next(n for n in reference["nodes"] if n["path"] == mesh["path"])
        source_transform = [f32(x) for x in source["transformColumnMajor"]]
        # Apple column-major/column-vector flat array is numerically the same
        # flattening as the transposed Gf row-major/row-vector matrix. We compare
        # components only; no homemade matrix multiplication is performed.
        world = sum(node["worldMatrixRows"], [])
        source_anchors.append(source_transform[12:15])
        imported_anchors.append(world[12:15])
        dimensions = [f32(x) for x in source["dimensions"]]
        polygon = [[f32(x) for x in corner] for corner in source["polygonCorners"]]
        source_min = [min(c[axis] for c in polygon) for axis in range(3)] if polygon else [-v / 2 for v in dimensions]
        source_max = [max(c[axis] for c in polygon) for axis in range(3)] if polygon else [v / 2 for v in dimensions]
        actual_min = mesh["localVertexBounds"]["minimum"]
        actual_max = mesh["localVertexBounds"]["maximum"]
        rows.append({
            "featureID": identity, "kind": source["kind"], "meshPath": mesh["path"],
            "sourceDimensionsFloat32": dimensions,
            "sourceLocalBoundsFloat32": {"minimum": source_min, "maximum": source_max},
            "exportedLocalBounds": mesh["localVertexBounds"],
            "exportedLocalSpans": [hi - lo for lo, hi in zip(actual_min, actual_max)],
            "localBoundsOverflowBelow": [max(0, a - b) for a, b in zip(source_min, actual_min)],
            "localBoundsOverflowAbove": [max(0, a - b) for a, b in zip(actual_max, source_max)],
            "sourceToExportedWorldMatrixMaxAbsoluteDelta": max(abs(a - b) for a, b in zip(source_transform, world)),
            "sourceAnchorMetersFloat32": source_transform[12:15],
            "exportedAnchorMeters": world[12:15],
            "exportedWorldBoundsMeters": mesh["worldVertexBoundsMeters"],
        })
    native = reference["nativeMDLGeometryProbe"]
    candidates = [m for m in reference["meshes"] if m["featureID"] == native["featureID"].lower()]
    if len(candidates) != 1:
        raise ValueError("first native failed feature is not a unique mesh; do not guess correspondence")
    mesh = candidates[0]
    node = next(n for n in reference["nodes"] if n["path"] == mesh["path"])
    matrix_delta = max(abs(a - b) for a, b in zip(sum(node["worldMatrixRows"], []), native["meshGlobalTransform"]))
    bbox_delta = max(abs(a - b) for key, nk in (("minimum", "exportedWorldMinimum"), ("maximum", "exportedWorldMaximum"))
                     for a, b in zip(mesh["worldVertexBoundsMeters"][key], native[nk]))
    anchor_pair_deltas = [abs(math.dist(source_anchors[a], source_anchors[b]) - math.dist(imported_anchors[a], imported_anchors[b]))
                          for a, b in itertools.combinations(range(len(rows)), 2)]
    return {
        "fixtureID": fixture, "referenceReportSHA256": digest(path),
        "sourceSHA256": reference["sourceSHA256"], "usdzSHA256": reference["usdzSHA256"],
        "metadataSHA256": reference["metadataSHA256"], "nativeManifestSHA256": reference["nativeManifestSHA256"],
        "nativeInventorySHA256": reference["nativeInventorySHA256"],
        "stageMetersPerUnit": reference["stageMetersPerUnit"], "metersPerUnitAuthored": reference["metersPerUnitAuthored"],
        "stageUpAxis": reference["stageUpAxis"], "upAxisAuthored": reference["upAxisAuthored"],
        "meshCount": reference["meshCount"], "vertexCount": reference["vertexCount"], "faceCount": reference["faceCount"],
        "featureKinds": dict(Counter(row["kind"] for row in rows)),
        "unmatchedMeshCount": reference["unmatchedMeshCount"],
        "originalFeaturesWithoutImportedMesh": reference["originalFeaturesWithoutImportedMesh"],
        "exactSourceFloat32WorldTransformMatches": sum(row["sourceToExportedWorldMatrixMaxAbsoluteDelta"] == 0 for row in rows),
        "sourceAnchorPairCount": len(anchor_pair_deltas), "maxSourceAnchorDistanceDeltaMeters": max(anchor_pair_deltas, default=0),
        "overallExportedWorldBoundsMeters": reference["overallWorldVertexBoundsMeters"],
        "firstNativeFailureComparison": {
            "featureID": native["featureID"], "meshPath": mesh["path"],
            "nativeFailure": reference["nativeAdapterFailure"], "axis": native["axis"],
            "sourceDimensionOnFailedAxis": native["sourceDimensions"][native["axis"]],
            "exportedLocalBounds": mesh["localVertexBounds"],
            "nativeWorldMatrixMaxAbsoluteDelta": matrix_delta,
            "nativeWorldBoundsMaxAbsoluteDeltaMeters": bbox_delta,
            "nativePredicateResidualMeters": native["residual"], "nativePredicateEpsilonMeters": native["epsilon"],
            "vertexIndicesCompared": False,
        },
        "features": rows,
    }


def main():
    report = {
        "schema": "same-public-export-independent-observations-v1",
        "nativeCommit": "c4ffa28c07d0a17b513d123de3bec2fd8be93eec", "nativeRunID": 40726507227,
        "nativeArtifactID": 12834885760, "referenceReader": "official OpenUSD 26.5",
        "sourceEncodingComparison": "Original JSON scalars rounded to IEEE754 Float32, matching native CapturedRoom witness encoding",
        "fixtures": [summarize("Hallway2"), summarize("Bedroom3")],
        "finding": "Exact input reference shows authored meter/Y-up units and preserved source feature transforms; source-plane containment rejects exporter-provided solid thickness/extensions",
        "limits": [
            "Only retained diagnostic export and its same-test Model I/O inventory are paired; production adapter export is separate/unretained",
            "Native numerical bounds/transform witness covers the first failed wall in each fixture, not every native-imported mesh",
            "OpenUSD-to-source per-feature transforms/anchors checked for all 24 features; this is not physical survey accuracy",
            "Exporter solid thickness/outline extensions do not establish measured wall thickness, current clearance or navigation safety",
            "No fitting, rescaling, recentering, source mutation, production gate change, topology repair or route tuning performed",
        ],
        "physicalAuthority": False,
    }
    output = OUT / "COMPARISON.json"
    output.write_text(json.dumps(report, indent=2, allow_nan=False) + "\n")
    print(output)


if __name__ == "__main__":
    main()

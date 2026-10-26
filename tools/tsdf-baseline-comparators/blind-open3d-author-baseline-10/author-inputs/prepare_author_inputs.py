#!/usr/bin/env python3
"""Acquire pinned source and propose input selection; never extracts RGB or runs fusion."""
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import signal
import tarfile
import urllib.request

HERE = Path(__file__).resolve().parent
WORKSPACE = HERE.parent.parent
PIN = "97588b4290128ce7ba6fdbfaac3020b42b17de4c"
PREFIX = "room_datasets/koivu/iphone/long_capture/"
ARCHIVE = WORKSPACE / "blind-mushroom-koivu-acquisition-01/koivu_iphone.tar.gz"
INVENTORY = WORKSPACE / "blind-mushroom-koivu-acquisition-01/ARCHIVE_INVENTORY.json"
POSES = WORKSPACE / "blind-koivu-faro-acquisition-04/selected-reference/transformations_colmap.json"
ORIGINAL_POSES = WORKSPACE / "blind-mushroom-koivu-acquisition-01/selected/room_datasets/koivu/iphone/long_capture/transformations.json"
DEPTH_MANIFEST = WORKSPACE / "blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json"


def digest(b):
    return hashlib.sha256(b).hexdigest()


def emit(name, obj):
    b = (json.dumps(obj, indent=2, sort_keys=True) + "\n").encode()
    with (HERE / name).open("xb") as f:
        f.write(b)
    return digest(b)


class LimitedRead:
    def __init__(self, stream):
        self.stream = stream
        self.n = 0

    def read(self, n=-1):
        if n < 0:
            n = 65536
        if self.n + n > 189 * 1024 * 1024:
            raise RuntimeError("189 MiB decompression cap")
        b = self.stream.read(n)
        self.n += len(b)
        return b


def main():
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("90-second wall cap")))
    signal.alarm(90)
    free = os.statvfs(HERE).f_bavail * os.statvfs(HERE).f_frsize
    if free < 768 * 1024 * 1024 + 2 * 1024 * 1024:
        raise RuntimeError("reserve unavailable")
    source_specs = [
        ("dn_splatter/data/mushroom_utils/pointcloud_utils.py", "pointcloud_utils.py", 10293,
         "2c7de7385bce72f439e8e2a3a8c661e7162eda704738895af1392f42d8a1dfae"),
        ("LICENSE", "LICENSE", 11357,
         "c71d239df91726fc519c6eb72d318ec65820627232b2f796219e87dcf35d0ab4"),
    ]
    sources = []
    total_source = 0
    for upstream, local, size, expected in source_specs:
        url = f"https://raw.githubusercontent.com/maturk/dn-splatter/{PIN}/{upstream}"
        with urllib.request.urlopen(url, timeout=20) as response:
            b = response.read(size + 1)
        if len(b) != size or digest(b) != expected:
            raise RuntimeError("pinned source size/hash mismatch")
        total_source += len(b)
        if total_source > 32768:
            raise RuntimeError("32 KiB upstream source cap")
        with (HERE / local).open("xb") as f:
            f.write(b)
        sources.append({"url": url, "file": local, "bytes": len(b), "sha256": digest(b)})
    source_receipt_sha = emit("SOURCE_ACQUISITION.json", {"commit": PIN, "license": "Apache-2.0",
        "files": sources, "sourceBytes": total_source, "codeUnmodified": True})
    inv_b = INVENTORY.read_bytes()
    inv = json.loads(inv_b)
    members = {x["name"]: x for x in inv["members"]}
    if len(members) != len(inv["members"]):
        raise RuntimeError("duplicate archive inventory names")
    pose_b = POSES.read_bytes()
    poses = json.loads(pose_b)
    original_b = ORIGINAL_POSES.read_bytes()
    original = json.loads(original_b)
    frames = poses["frames"]
    if frames != original["frames"] or len(frames) != 294:
        raise RuntimeError("provided/original frame-list mismatch")
    depth_b = DEPTH_MANIFEST.read_bytes()
    depth_manifest = json.loads(depth_b)
    if depth_manifest["poseSHA256"] != digest(original_b):
        raise RuntimeError("reused depth manifest pose association mismatch")
    if depth_manifest["archiveSHA256"] != inv["archiveSHA256"]:
        raise RuntimeError("reused depth/archive mismatch")
    depth_rows = {x["member"]: x for x in depth_manifest["files"]}
    with gzip.open(ARCHIVE, "rb") as stream:
        limited = LimitedRead(stream)
        with tarfile.open(fileobj=limited, mode="r|") as tf:
            for member in tf:
                if member.name == PREFIX + "test.txt":
                    if not member.isfile() or member.size != 348:
                        raise RuntimeError("unexpected test.txt member")
                    split_b = tf.extractfile(member).read(349)
                    break
            else:
                raise RuntimeError("test.txt absent")
    if len(split_b) != 348 or digest(split_b) != "60833925e50adeade36f127ad6035e86bf17f206e7f1d8b53f1eee96731ba97d":
        raise RuntimeError("test.txt hash mismatch")
    test_ids = split_b.decode().splitlines()
    if len(test_ids) != len(set(test_ids)):
        raise RuntimeError("duplicate split IDs")
    test_set = set(test_ids)
    rows = []
    frame_ids = []
    for i, frame in enumerate(frames):
        rgb_rel = PurePosixPath(frame["file_path"])
        depth_rel = PurePosixPath(frame["depth_file_path"])
        if rgb_rel.is_absolute() or depth_rel.is_absolute() or ".." in rgb_rel.parts or ".." in depth_rel.parts:
            raise RuntimeError("unsafe supplied frame path")
        name = rgb_rel.stem
        frame_ids.append(name)
        rgb_member = PREFIX + str(rgb_rel)
        depth_member = PREFIX + str(depth_rel)
        if rgb_member not in members or depth_member not in members or depth_member not in depth_rows:
            raise RuntimeError("missing RGB/depth inventory association")
        d = depth_rows[depth_member]
        if d["poseIndex"] != i or d["bytes"] != members[depth_member]["bytes"]:
            raise RuntimeError("reused depth manifest frame mismatch")
        if (WORKSPACE / "blind-koivu-game-07/map/depths" / d["file"]).stat().st_size != d["bytes"]:
            raise RuntimeError("reused depth file size mismatch")
        rows.append({"poseIndex": i, "frameID": name,
            "split": "test_excluded" if name in test_set else "train",
            "rgbMember": rgb_member, "rgbBytes": members[rgb_member]["bytes"],
            "rgbSHA256": members[rgb_member].get("sha256"),
            "depthMember": depth_member, "depthBytes": d["bytes"], "depthSHA256": d["sha256"],
            "reusedDepthPath": "blind-koivu-game-07/map/depths/" + d["file"]})
    if len(frame_ids) != len(set(frame_ids)) or set(test_ids) - set(frame_ids):
        raise RuntimeError("duplicate pose ID or unmatched test ID")
    train = [r for r in rows if r["split"] == "train"]
    excluded = [r for r in rows if r["split"] == "test_excluded"]
    if len(train) != 265 or len(excluded) != 29:
        raise RuntimeError("unexpected author split")
    matched = {r["rgbMember"] for r in rows}
    extra_rgb = sorted(n for n, x in members.items() if n.startswith(PREFIX + "images/") and x["kind"] == "file" and n not in matched)
    rgb_bytes = sum(r["rgbBytes"] for r in train)
    plan = {"status": "PROPOSED ONLY; RGB extraction and mapper run not authorized by this receipt",
        "archiveSHA256": inv["archiveSHA256"], "archiveInventorySHA256": digest(inv_b),
        "providedPosePath": "blind-koivu-faro-acquisition-04/selected-reference/transformations_colmap.json",
        "providedPoseSHA256": digest(pose_b), "providedPoseBytes": len(pose_b),
        "originalPoseSHA256": digest(original_b), "parsedFrameListsExactlyEqual": True,
        "reusedDepthManifestPath": "blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json",
        "reusedDepthManifestSHA256": digest(depth_b),
        "depthSHAEvidence": "copied from existing extraction manifest; file sizes rechecked, content not rehashed in this inventory step",
        "rgbSHAEvidence": "archive inventory provides member names/sizes, not per-RGB hashes; null hashes require later authorized extraction verification",
        "authorSourceReceiptSHA256": source_receipt_sha,
        "testMember": PREFIX + "test.txt", "testBytes": len(split_b), "testSHA256": digest(split_b),
        "testReadDecompressedBytes": limited.n, "testIDs": test_ids,
        "providedFrameCount": 294, "trainCount": len(train), "excludedTestCount": len(excluded),
        "trainRGBBytes": rgb_bytes, "testTxtBytes": len(split_b), "proposedNewPayloadBytes": rgb_bytes + len(split_b),
        "trainDepthReusedBytes": sum(r["depthBytes"] for r in train),
        "all294DepthReusedBytes": sum(r["depthBytes"] for r in rows),
        "unposedRGBMembersExcluded": extra_rgb, "unposedRGBCount": len(extra_rgb),
        "rows": rows, "newRGBFilesExtracted": 0, "mapperExecuted": False,
        "paths": "workspace-relative; no absolute private paths"}
    sha = emit("PROPOSED_KOIVU_SELECTION.json", plan)
    signal.alarm(0)
    print(json.dumps({"status": "source verified; selection proposal ready", "sourceBytes": total_source,
        "trainCount": len(train), "testCount": len(excluded), "trainRGBBytes": rgb_bytes,
        "proposedNewPayloadBytes": rgb_bytes + len(split_b), "unposedRGBExcluded": len(extra_rgb),
        "selectionSHA256": sha, "sourceReceiptSHA256": source_receipt_sha}), flush=True)


if __name__ == "__main__":
    main()

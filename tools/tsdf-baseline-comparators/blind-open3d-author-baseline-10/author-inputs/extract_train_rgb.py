#!/usr/bin/env python3
"""Exact approved Koivu RGB extraction and source-constant audit; no fusion."""
import ast
import gzip
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import signal
import tarfile
import time
import urllib.request
from PIL import Image

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
WORKSPACE = STAGE.parent
ARCHIVE = WORKSPACE / "blind-mushroom-koivu-acquisition-01/koivu_iphone.tar.gz"
PREFIX = "room_datasets/koivu/iphone/long_capture/"
EXPECTED_ARCHIVE = "68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518"
EXPECTED_PROPOSAL = "d505c562e7660d52832137ffdbcdb751f1e88654bccfe79e6ea1087cf0845360"
CAMERA_SHA = "370bcfa4b45a0335dbd42c037368a020eae5d2533dc07877e9d7711ae5510f85"
RESERVE = 768 * 1024 * 1024
STAGE_CAP = 900 * 1024 * 1024
EXPANDED_CAP = 200 * 1024 * 1024
PAYLOAD = 47902957
START = time.monotonic()
BASE = 0
WRITTEN = 0


def sha(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(1048576), b""):
            h.update(b)
    return h.hexdigest()


def stage_bytes():
    return sum((Path(root) / name).lstat().st_size
               for root, dirs, files in os.walk(STAGE, followlinks=False)
               for name in dirs + files)


def free_bytes():
    s = os.statvfs(HERE)
    return s.f_bavail * s.f_frsize


def budget(n=0):
    if time.monotonic() - START > 120:
        raise TimeoutError("120-second cap")
    if free_bytes() < RESERVE + n:
        raise RuntimeError("768 MiB reserve")
    if BASE + WRITTEN + n + 2 * 1024 * 1024 > STAGE_CAP:
        raise RuntimeError("900 MiB whole-stage cap")


def json_new(path, obj):
    global WRITTEN
    b = (json.dumps(obj, indent=2, sort_keys=True) + "\n").encode()
    budget(len(b))
    with path.open("xb") as f:
        f.write(b)
    WRITTEN += len(b)
    return hashlib.sha256(b).hexdigest()


class BoundedRead:
    def __init__(self, f):
        self.f = f
        self.n = 0

    def read(self, n=-1):
        if n < 0:
            n = 65536
        if self.n + n > EXPANDED_CAP:
            raise RuntimeError("200 MiB decompression cap")
        b = self.f.read(n)
        self.n += len(b)
        budget()
        return b


def main():
    global BASE, WRITTEN
    signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(TimeoutError("120-second cap")))
    signal.alarm(120)
    BASE = stage_bytes()
    initial_free = free_bytes()
    budget(PAYLOAD + 65536 + 1048576)
    if sha(HERE / "PROPOSED_KOIVU_SELECTION.json") != EXPECTED_PROPOSAL:
        raise RuntimeError("proposal hash mismatch")
    plan = json.loads((HERE / "PROPOSED_KOIVU_SELECTION.json").read_text())
    train = [r for r in plan["rows"] if r["split"] == "train"]
    selected = {r["rgbMember"]: r["rgbBytes"] for r in train}
    selected[plan["testMember"]] = plan["testBytes"]
    if len(train) != 265 or len(selected) != 266 or sum(selected.values()) != PAYLOAD:
        raise RuntimeError("unexpected authorized selection")
    if sha(ARCHIVE) != EXPECTED_ARCHIVE:
        raise RuntimeError("current full archive SHA mismatch")
    url = "https://raw.githubusercontent.com/maturk/dn-splatter/97588b4290128ce7ba6fdbfaac3020b42b17de4c/dn_splatter/utils/camera_utils.py"
    with urllib.request.urlopen(url, timeout=20) as response:
        camera_b = response.read(65537)
    if len(camera_b) > 65536 or hashlib.sha256(camera_b).hexdigest() != CAMERA_SHA:
        raise RuntimeError("camera source cap/hash mismatch")
    source = camera_b.decode()
    matches = [n for n in ast.parse(source).body if isinstance(n, ast.Assign)
               and any(isinstance(t, ast.Name) and t.id == "OPENGL_TO_OPENCV" for t in n.targets)]
    if len(matches) != 1 or not isinstance(matches[0].value, ast.Call):
        raise RuntimeError("unexpected camera constant definition")
    constant = ast.literal_eval(matches[0].value.args[0])
    if constant != [[1, 0, 0, 0], [0, -1, 0, 0], [0, 0, -1, 0], [0, 0, 0, 1]]:
        raise RuntimeError("unexpected author optical basis")
    upstream = HERE / "upstream"
    upstream.mkdir(exist_ok=False)
    budget(len(camera_b))
    with (upstream / "camera_utils.py").open("xb") as f:
        f.write(camera_b)
    WRITTEN += len(camera_b)
    destination = HERE / "selected"
    temp = HERE / "selected.incomplete"
    if destination.exists() or temp.exists():
        raise FileExistsError("refusing existing selected tree")
    temp.mkdir()
    seen = set()
    found = {}
    count = 0
    total = 0
    with gzip.open(ARCHIVE, "rb") as gz:
        reader = BoundedRead(gz)
        with tarfile.open(fileobj=reader, mode="r|") as tf:
            for item in tf:
                count += 1
                if count > 10000:
                    raise RuntimeError("archive member-count cap")
                name = item.name
                parts = name.rstrip("/").split("/")
                if (not name or name.startswith("/") or "\\" in name or ":" in name or "\x00" in name
                        or any(p in ("", ".", "..") for p in parts)):
                    raise RuntimeError("unsafe archive member path")
                if name in seen:
                    raise RuntimeError("duplicate archive member")
                seen.add(name)
                if not (item.isfile() or item.isdir()):
                    raise RuntimeError("archive link/special member rejected")
                if name not in selected:
                    continue
                if not item.isfile() or item.size != selected[name]:
                    raise RuntimeError("selected member type/size mismatch")
                relative = name.removeprefix(PREFIX)
                if relative == name:
                    raise RuntimeError("selected member outside fixed prefix")
                target = temp.joinpath(*PurePosixPath(relative).parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                h = hashlib.sha256()
                n = 0
                with tf.extractfile(item) as inp, target.open("xb") as out:
                    while True:
                        b = inp.read(min(65536, item.size - n + 1))
                        if not b:
                            break
                        n += len(b)
                        total += len(b)
                        if n > item.size or total > PAYLOAD:
                            raise RuntimeError("selected payload exceeded")
                        budget(len(b))
                        out.write(b)
                        WRITTEN += len(b)
                        h.update(b)
                if n != item.size:
                    raise RuntimeError("short selected member")
                row = {"member": name, "bytes": n, "sha256": h.hexdigest(),
                       "selectedRelativePath": relative}
                if relative.startswith("images/"):
                    with Image.open(target) as im:
                        row.update({"width": im.width, "height": im.height, "format": im.format})
                        if im.size != (738, 994) or im.format != "JPEG":
                            raise RuntimeError("RGB header differs from declared 738x994 JPEG")
                elif h.hexdigest() != plan["testSHA256"]:
                    raise RuntimeError("test.txt content hash mismatch")
                found[name] = row
        # Consume any remaining bounded gzip bytes to validate its CRC/trailer.
        while reader.read(65536):
            pass
    if set(found) != set(selected) or total != PAYLOAD:
        raise RuntimeError("selection incomplete")
    if sha(ARCHIVE) != EXPECTED_ARCHIVE:
        raise RuntimeError("archive changed during extraction")
    temp.rename(destination)
    ready = []
    for r in train:
        evidence = found[r["rgbMember"]]
        ready.append({"poseIndex": r["poseIndex"], "frameID": r["frameID"],
                      "rgbPath": "blind-open3d-author-baseline-10/author-inputs/selected/" + evidence["selectedRelativePath"],
                      "rgbBytes": evidence["bytes"], "rgbSHA256": evidence["sha256"],
                      "width": evidence["width"], "height": evidence["height"],
                      "depthPath": r["reusedDepthPath"], "depthBytes": r["depthBytes"],
                      "depthSHA256": r["depthSHA256"]})
    ready_sha = json_new(HERE / "READY_TRAIN_FRAMES.json", {
        "status": "inputs prepared; no fusion executed", "proposalSHA256": EXPECTED_PROPOSAL,
        "providedPosePath": plan["providedPosePath"], "providedPoseSHA256": plan["providedPoseSHA256"],
        "depthManifestSHA256": plan["reusedDepthManifestSHA256"], "depthHashesReusedFromExistingManifest": True,
        "trainCount": len(ready), "excludedTestCount": 29, "paths": "workspace-relative", "frames": ready})
    receipt = {"status": "complete", "archiveSHA256Before": EXPECTED_ARCHIVE,
        "archiveSHA256After": EXPECTED_ARCHIVE, "proposalSHA256": EXPECTED_PROPOSAL,
        "selectedFileCount": len(found), "trainRGBCount": 265, "selectedBytes": total,
        "archiveMembersInspected": count, "decompressedBytes": reader.n,
        "files": [found[n] for n in sorted(found)], "readyFramesSHA256": ready_sha,
        "cameraSource": {"url": url, "bytes": len(camera_b), "sha256": CAMERA_SHA,
                         "constant": constant, "originalSourceStatement": ast.get_source_segment(source, matches[0]),
                         "sourceExecuted": False},
        "scriptSHA256": sha(Path(__file__)), "initialFreeBytes": initial_free,
        "finalFreeBeforeReceiptBytes": free_bytes(), "stageBytesBeforeReceipt": stage_bytes(),
        "elapsedSeconds": time.monotonic() - START,
        "limits": {"decompressedBytes": EXPANDED_CAP, "wallSeconds": 120,
                   "reserveBytes": RESERVE, "wholeStageBytes": STAGE_CAP},
        "pixelsDecodedOrResampled": False, "imageHeaderCheckOnly": True,
        "fusionExecuted": False, "newDepthCopies": 0, "newTestRGBFiles": 0}
    receipt_sha = json_new(HERE / "EXTRACTION_RECEIPT.json", receipt)
    budget()
    if stage_bytes() > STAGE_CAP:
        raise RuntimeError("final whole-stage cap")
    signal.alarm(0)
    print(json.dumps({"status": "complete", "selectedBytes": total, "rgbCount": 265,
        "decompressedBytes": reader.n, "receiptSHA256": receipt_sha, "readyFramesSHA256": ready_sha,
        "cameraConstant": constant, "cameraSourceBytes": len(camera_b),
        "freeBytes": free_bytes(), "stageBytes": stage_bytes(), "elapsedSeconds": time.monotonic() - START}), flush=True)


if __name__ == "__main__":
    main()

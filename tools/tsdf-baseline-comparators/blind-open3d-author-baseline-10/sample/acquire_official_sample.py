#!/usr/bin/env python3
"""Bounded official sample acquisition only; never imports Open3D or runs fusion."""
import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import signal
import stat
import time
import urllib.request
import zipfile

HERE = Path(__file__).resolve().parent
STAGE = HERE.parent
RESERVE = 768 * 1024 * 1024
STAGE_CAP = 900 * 1024 * 1024
EXPANDED_CAP = 64 * 1024 * 1024
ZIP_SIZE = 3772513
ZIP_MD5 = "43971c5f690c9cfc52dda8c96a0140ee"
ZIP_URL = "https://github.com/isl-org/open3d_downloads/releases/download/20220301-data/SampleRedwoodRGBDImages.zip"
PIN = "1e7b17438687a0b0c1e5a7187321ac7044afe275"
NOTEBOOK_SHA = "adb7e518ce3c4323ed674e595b116249af7da96382ae910efd36a51c2b8dcfce"
LICENSE_BLOB = "9134a1223b9732cb1577a698462284ae0d4ff655"
START = time.monotonic()
BASE_BYTES = 0
WRITTEN = 0


def timeout_handler(*_):
    raise TimeoutError("120-second acquisition/extraction wall limit")


def stage_bytes():
    total = 0
    for root, dirs, files in os.walk(STAGE, followlinks=False):
        for name in dirs + files:
            p = Path(root) / name
            s = p.lstat()
            total += s.st_size
    return total


def free_bytes():
    fs = os.statvfs(HERE)
    return fs.f_bavail * fs.f_frsize


def budget(extra=0):
    if time.monotonic() - START >= 120:
        raise TimeoutError("120-second wall limit")
    if free_bytes() < RESERVE + extra:
        raise RuntimeError("768 MiB free-space reserve would be crossed")
    if BASE_BYTES + WRITTEN + extra + 1024 * 1024 > STAGE_CAP:
        raise RuntimeError("900 MiB stage cap would be crossed")


def write_new(path, data):
    global WRITTEN
    budget(len(data))
    with path.open("xb") as out:
        out.write(data)
    WRITTEN += len(data)
    budget()


def json_new(path, data):
    write_new(path, (json.dumps(data, indent=2, sort_keys=True) + "\n").encode())


def sha256_file(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for b in iter(lambda: f.read(65536), b""):
            h.update(b)
    return h.hexdigest()


def download_exact(url, path, exact, cap):
    global WRITTEN
    if exact > cap:
        raise RuntimeError("invalid transfer bound")
    budget(exact)
    partial = path.with_name(path.name + ".partial")
    if path.exists() or partial.exists():
        raise FileExistsError("refusing archive/source overwrite")
    n = 0
    h = hashlib.sha256()
    md5 = hashlib.md5()
    with urllib.request.urlopen(url, timeout=25) as response, partial.open("xb") as out:
        if response.status != 200:
            raise RuntimeError("unexpected HTTP status")
        declared = response.headers.get("Content-Length")
        if declared is not None and int(declared) != exact:
            raise RuntimeError("unexpected Content-Length")
        while True:
            block = response.read(min(65536, exact - n + 1))
            if not block:
                break
            if n + len(block) > exact or n + len(block) > cap:
                raise RuntimeError("transfer exceeds exact declared limit")
            budget(len(block))
            out.write(block)
            n += len(block)
            WRITTEN += len(block)
            h.update(block)
            md5.update(block)
    if n != exact:
        raise RuntimeError("short transfer")
    # Hard-link commit fails rather than overwriting an existing file.
    os.link(partial, path)
    partial.unlink()
    budget()
    return {"url": url, "bytes": n, "sha256": h.hexdigest(), "md5": md5.hexdigest()}


def validate_members(z):
    infos = z.infolist()
    if len(infos) > 1000:
        raise RuntimeError("member-count cap")
    seen = set()
    files = set()
    rows = []
    total = 0
    for item in infos:
        name = item.filename
        p = PurePosixPath(name)
        parts = name.rstrip("/").split("/")
        if (not name or p.is_absolute() or "\\" in name or ":" in name
                or "\x00" in name or any(x in ("", ".", "..") for x in parts)):
            raise RuntimeError("unsafe ZIP member path")
        key = "/".join(parts).casefold()
        if key in seen:
            raise RuntimeError("duplicate/case-colliding ZIP member")
        seen.add(key)
        if any("/".join(parts[:i]).casefold() in files for i in range(1, len(parts))):
            raise RuntimeError("file/directory path collision")
        mode = (item.external_attr >> 16) & 0xFFFF
        kind = stat.S_IFMT(mode)
        expected_kind = stat.S_IFDIR if item.is_dir() else stat.S_IFREG
        if kind not in (0, expected_kind):
            raise RuntimeError("ZIP links/special files rejected")
        if item.flag_bits & 1:
            raise RuntimeError("encrypted ZIP members rejected")
        if not item.is_dir():
            files.add(key)
        elif item.file_size:
            raise RuntimeError("nonempty directory member")
        total += item.file_size
        if total > EXPANDED_CAP or item.file_size > EXPANDED_CAP:
            raise RuntimeError("64 MiB expanded cap")
        rows.append({"name": name, "bytes": item.file_size,
                     "compressedBytes": item.compress_size,
                     "kind": "directory" if item.is_dir() else "file"})
    # Also reject a file listed after its descendant.
    for key in files:
        if any(other.startswith(key + "/") for other in seen):
            raise RuntimeError("file/descendant collision")
    return infos, rows, total


def main():
    global BASE_BYTES, WRITTEN
    signal.signal(signal.SIGALRM, timeout_handler)
    signal.alarm(120)
    BASE_BYTES = stage_bytes()
    initial_free = free_bytes()
    budget(ZIP_SIZE + EXPANDED_CAP + 32768 + 1024 * 1024)
    archive = HERE / "SampleRedwoodRGBDImages.zip"
    receipt = download_exact(ZIP_URL, archive, ZIP_SIZE, 4 * 1024 * 1024)
    if receipt["md5"] != ZIP_MD5:
        raise RuntimeError("published MD5 mismatch; no extraction permitted")
    upstream = HERE / "upstream"
    upstream.mkdir(exist_ok=False)
    raw = f"https://raw.githubusercontent.com/isl-org/Open3D/{PIN}/"
    notebook = upstream / "rgbd_integration.ipynb"
    notebook_r = download_exact(raw + "docs/jupyter/pipelines/rgbd_integration.ipynb", notebook, 6812, 32768)
    if notebook_r["sha256"] != NOTEBOOK_SHA:
        raise RuntimeError("pinned notebook SHA mismatch")
    # The official license is small; use a capped read, pin the Git blob before write.
    license_url = raw + "LICENSE"
    with urllib.request.urlopen(license_url, timeout=25) as response:
        license_bytes = response.read(32768 - 6812 + 1)
    if len(license_bytes) + 6812 > 32768:
        raise RuntimeError("32 KiB upstream code cap")
    blob = hashlib.sha1(b"blob " + str(len(license_bytes)).encode() + b"\0" + license_bytes).hexdigest()
    if blob != LICENSE_BLOB:
        raise RuntimeError("pinned MIT license Git blob mismatch")
    write_new(upstream / "LICENSE", license_bytes)
    with zipfile.ZipFile(archive) as z:
        infos, inventory, total = validate_members(z)
        inventory_r = {"archive": receipt, "memberCount": len(infos),
                       "declaredExpandedBytes": total, "members": inventory,
                       "allMemberPathsValidated": True, "linksRejected": True}
        json_new(HERE / "INVENTORY.json", inventory_r)
        print(json.dumps({"phase": "validated_inventory", "members": len(infos),
                          "expandedBytes": total, "archiveSHA256": receipt["sha256"],
                          "inventory": inventory}), flush=True)
        destination = HERE / "extracted"
        temp = HERE / "extracted.incomplete"
        if destination.exists() or temp.exists():
            raise FileExistsError("refusing extracted-tree overwrite")
        temp.mkdir()
        results = []
        actual_total = 0
        for item in infos:
            budget()
            target = temp.joinpath(*PurePosixPath(item.filename).parts)
            if item.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            h = hashlib.sha256()
            n = 0
            with z.open(item) as source, target.open("xb") as output:
                while True:
                    data = source.read(min(65536, item.file_size - n + 1))
                    if not data:
                        break
                    n += len(data)
                    actual_total += len(data)
                    if n > item.file_size or actual_total > EXPANDED_CAP:
                        raise RuntimeError("actual expanded byte cap exceeded")
                    budget(len(data))
                    output.write(data)
                    WRITTEN += len(data)
                    h.update(data)
            if n != item.file_size:
                raise RuntimeError("member length mismatch")
            results.append({"name": item.filename, "bytes": n, "sha256": h.hexdigest()})
        if actual_total != total:
            raise RuntimeError("expanded total mismatch")
        temp.rename(destination)
    final = {"status": "complete", "purpose": "official engine fixture acquisition only; no import or integration",
             "archive": receipt, "publishedMD5": ZIP_MD5, "expectedArchiveBytes": ZIP_SIZE,
             "files": results, "expandedBytes": actual_total,
             "upstream": {"releaseCommit": PIN, "notebook": notebook_r,
                          "license": {"url": license_url, "bytes": len(license_bytes), "gitBlobSHA1": blob,
                                      "sha256": hashlib.sha256(license_bytes).hexdigest()}},
             "helperSHA256": sha256_file(Path(__file__)),
             "limits": {"downloadBytes": 4 * 1024 * 1024, "expandedBytes": EXPANDED_CAP,
                        "members": 1000, "wallSeconds": 120, "reserveBytes": RESERVE, "stageBytes": STAGE_CAP},
             "initialFreeBytes": initial_free, "finalFreeBytesBeforeReceipt": free_bytes(),
             "stageBytesBeforeReceipt": stage_bytes(), "elapsedSeconds": time.monotonic() - START,
             "recordedAtUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
             "rawSamplePublication": "local only; preserve layered licensing; no raw-data redistribution authorized"}
    json_new(HERE / "ACQUISITION_RECEIPT.json", final)
    budget()
    if stage_bytes() > STAGE_CAP:
        raise RuntimeError("final stage cap violated")
    signal.alarm(0)
    print(json.dumps({"phase": "complete", "files": len(results), "expandedBytes": actual_total,
                      "archiveSHA256": receipt["sha256"], "finalFreeBytes": free_bytes(),
                      "stageBytes": stage_bytes(), "elapsedSeconds": time.monotonic() - START}), flush=True)


if __name__ == "__main__":
    main()

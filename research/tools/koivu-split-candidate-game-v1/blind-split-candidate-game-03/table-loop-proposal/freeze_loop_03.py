"""Create an exclusive source/input manifest only; no numerical imports/data decode."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import stat

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
WS = GAME.parent
RUN = HERE/"run-03"
FROZEN = RUN/"FROZEN.json"
BUDGETS = dict(CPUSeconds=60, wallSeconds=90, RSSBytes=512*1024**2,
               outputBytes=8*1024**2, freeReserveBytes=768*1024**2)
FIXED = {
    "blind-authored-navigation-pilot/native/detour_engine.py": "8ab51b8fe7ac2585cfbe797615dd9ac78956e6cb14277deb092aca19df38787d",
    "blind-authored-navigation-pilot/native/libblind_detour.so": "560567438e5c88aaa8e20d3ac92ce4db6fe8803018f537b82819b47ed7cc05b8",
    "blind-split-candidate-game-03/upstream/scripts/routes_rect.py": "c96f1cb4e87e1f283645f4dbe7e8ee76f51b1d701ddf6a0965be4e1a1bd5c980",
    "blind-split-candidate-game-03/upstream/scripts/routes.py": "20723183941e16968eaacfd227972448385255dc5f3ff86bc39c7de8edb1f2d8",
    "blind-split-candidate-game-03/source/candidate_map.py": "5e0132f4711200bca1b7ae90eb27b5666ce0707b1573e815e40e622caff98c09",
    "blind-split-candidate-game-03/inputs/koivu_5cm_occthres_split0.7.npz": "b294d92cfd9136d00de510239c2b85a9d68d878dcf7dac1a64b144d8880cb076",
    "blind-split-candidate-game-03/inputs/koivu_5cm_v2_pipeline2_out.npz": "a2fc5c13f86bf7033131347fd9b6d61db23ab716d12d668a3d969b9e87dbf48d",
    "blind-koivu-game-07/run_bounded.py": "1f695e6c927fba3cb20ee157e2f04cc74a71c1051937fc061ad2e956b6db7735",
    "blind-split-candidate-game-03/source/run_selector_bounded_02.py": "e4f0524722e98553d0e2ba56b24b55b4765b0f3ad0810122cda67db864f542a2",
    "blind-split-candidate-game-03/table-loop-proposal/PROTOCOL.md": "07555ca479879c3d30ea8561887007038f5383fa5adf0e70508a2b92c69b788a",
}
OWN = ("table_loop.py", "test_table_loop.py", "freeze_loop_03.py", "loop_driver_03.py",
       "run_loop_bounded_03.py", "IMPLEMENTATION_NOTES.md")


def pin(path):
    path = Path(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, "rb") as f:
        a = os.fstat(f.fileno())
        if not stat.S_ISREG(a.st_mode): raise ValueError("regular pin required")
        h = hashlib.sha256()
        for block in iter(lambda: f.read(1 << 20), b""): h.update(block)
        b = os.fstat(f.fileno())
    identity = lambda s: (s.st_dev, s.st_ino, s.st_size, s.st_mtime_ns, s.st_ctime_ns)
    if identity(a) != identity(b) or identity(a) != identity(path.stat(follow_symlinks=False)):
        raise ValueError("pin changed during hash")
    return dict(path=str(path.relative_to(WS)), bytes=a.st_size, sha256=h.hexdigest())


def read_manifest(expected):
    with FROZEN.open("rb") as f: raw = f.read(1024**2+1)
    if (len(raw) > 1024**2 or len(expected) != 64 or any(c not in "0123456789abcdef" for c in expected)
            or hashlib.sha256(raw).hexdigest() != expected):
        raise ValueError("external manifest SHA mismatch before parse")
    doc = json.loads(raw)
    wanted = set(FIXED) | {str((HERE/name).relative_to(WS)) for name in OWN}
    if (doc.get("schemaVersion") != 1 or doc.get("budgets") != BUDGETS
            or len(doc["pins"]) != len(wanted) or {p["path"] for p in doc["pins"]} != wanted):
        raise ValueError("unexpected manifest scope")
    for row in doc["pins"]:
        if row["path"] in FIXED and row["sha256"] != FIXED[row["path"]]:
            raise ValueError("fixed upstream/input pin changed")
    return doc


def verify_manifest(expected, check=lambda: None):
    doc = read_manifest(expected)
    for row in doc["pins"]:
        if pin(WS/row["path"]) != row: raise ValueError("source/input changed: "+row["path"])
        check()
    if read_manifest(expected) != doc: raise ValueError("manifest changed")
    return doc


def main():
    if shutil.disk_usage(HERE).free < BUDGETS["freeReserveBytes"]+BUDGETS["outputBytes"]:
        raise RuntimeError("reserve plus maximum new output unavailable")
    paths = [WS/p for p in FIXED]+[HERE/name for name in OWN]
    rows = [pin(p) for p in paths]
    for row in rows:
        if row["path"] in FIXED and row["sha256"] != FIXED[row["path"]]:
            raise ValueError("fixed upstream/input mismatch")
    doc = dict(schemaVersion=1, scope="one phone-only loop feasibility construction; no actor/reference execution",
               pins=rows, budgets=BUDGETS, dataEvaluationExecuted=False, physicalAuthority=False,
               semanticTarget="unresolvedGeometricProxy", modes=["synthetic-fixtures", "phone-only-feasibility"])
    raw = (json.dumps(doc, indent=2, sort_keys=True, allow_nan=False)+"\n").encode()
    RUN.mkdir(mode=0o700, exist_ok=False)
    with FROZEN.open("xb") as f: f.write(raw)
    print(json.dumps(dict(manifest=str(FROZEN), sha256=hashlib.sha256(raw).hexdigest(), pins=len(rows), dataDecoded=False)))


if __name__ == "__main__": main()

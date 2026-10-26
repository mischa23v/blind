#!/usr/bin/env python3
"""Restore the exact failed-map fixture; never overwrite an existing file."""
from pathlib import Path
import hashlib
import os
import tempfile

TOTAL = 14921426
SHA256 = "1961eef94bc98f5d89d4986c8b62d7352d0e2046e1dbfa3e6baf767a54e7646d"
PARTS = (
    ("MAP.npz.part00", 8388608, "7074cd1c2b2f9f51c4b743016e2fd0c8a876a4b2a50ba4fde79fba33414b2cb7"),
    ("MAP.npz.part01", 6532818, "eaba6c7b40ad881b9ad4033a65ef8fbacc532df405f5692f503121238b96a121"),
)

def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()

def restore(directory):
    directory = Path(directory)
    target = directory / "MAP.npz"
    if target.exists():
        if target.stat().st_size == TOTAL and digest(target) == SHA256:
            return target
        raise ValueError("Existing MAP.npz differs; refusing to overwrite it")
    for name, size, expected in PARTS:
        p = directory / name
        if p.stat().st_size != size or digest(p) != expected:
            raise ValueError("Part size/hash mismatch: " + name)
    fd, temporary = tempfile.mkstemp(prefix=".MAP.npz-", suffix=".partial", dir=directory)
    temporary = Path(temporary)
    try:
        with os.fdopen(fd, "wb") as out:
            for name, _, _ in PARTS:
                with (directory / name).open("rb") as source:
                    for block in iter(lambda: source.read(1024 * 1024), b""):
                        out.write(block)
            out.flush()
            os.fsync(out.fileno())
        if temporary.stat().st_size != TOTAL or digest(temporary) != SHA256:
            raise ValueError("Reassembled map hash mismatch")
        # Atomic no-overwrite publication. A racing existing target causes failure.
        os.link(temporary, target)
        return target
    finally:
        temporary.unlink(missing_ok=True)

if __name__ == "__main__":
    print(restore(Path(__file__).resolve().parent).name + " verified: " + SHA256)

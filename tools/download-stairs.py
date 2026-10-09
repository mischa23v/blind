"""Download a preselected, evenly spaced 12-frame subset of a real RGB-D test set."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import urllib.request

root = Path(__file__).resolve().parents[1] / "artifacts" / "stairs"
root.mkdir(parents=True, exist_ok=True)
api = "https://data.mendeley.com/public-api/datasets/6kffmjt7g2"
def read(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"}), timeout=90).read()
metadata = json.loads(read(api))
assert metadata["version"] == 1
indices = [0, 14, 28, 42, 56, 70, 84, 98, 112, 126, 140, 153]
names = {name for i in indices for name in [f"pointcloud_{i}.ply", f"color_{i}.png", f"Extrinsics_{i}.txt"]}
# Training segmentation masks reuse color_*.png names. Select the test RGB folder.
test_rgb_folder = "0f007c1b-ee14-4624-be06-b2aa2cabc124"
files = [f for f in metadata["files"] if f["filename"] in names and
         (not f["filename"].startswith("color_") or f["folder_id"] == test_rgb_folder)]
assert len(files) == len(names), "Missing/ambiguous dataset files"
manifest = {"source": "https://data.mendeley.com/datasets/6kffmjt7g2/1", "doi": "10.17632/6kffmjt7g2.1",
            "authors": ["Chen Wang", "Zhongcai Pei", "Shuang Qiu", "Yachun Wang", "Zhiyong Tang"],
            "license": metadata["data_licence"], "indices": indices,
            "selection": "Evenly spaced indices fixed before inspecting outcomes; 12 of 154 test frames.", "files": files}
(root / "source.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
def download(f):
    target = root / f["filename"]
    expected = f["content_details"]["sha256_hash"]
    if target.exists() and hashlib.sha256(target.read_bytes()).hexdigest() == expected:
        return
    content = read(f["content_details"]["download_url"])
    assert len(content) == f["size"] and hashlib.sha256(content).hexdigest() == expected, f["filename"]
    target.write_bytes(content)
    print(f["filename"], len(content), flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:
    list(executor.map(download, files))
print("All 36 files verified against publisher SHA-256 hashes.")

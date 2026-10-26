#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
python - <<'PY'
from pathlib import Path
import hashlib,json
p=Path('.');m=json.loads((p/'UPSTREAM_MANIFEST.json').read_text())
assert m['revision']=='9f4ce64458dfae86e1239c525ddc219c4e9e06f1'
assert m['totalAcquisitionBytes']<=20*1024*1024
for e in m['files']:
 b=(p/'upstream'/e['path']).read_bytes()
 assert len(b)==e['bytes'] and hashlib.sha256(b).hexdigest()==e['sha256'],e['path']
assert sum(x.stat().st_size for x in p.rglob('*') if x.is_file())<200*1024*1024
PY
# No -j, CMake, graphics, ROS, runtime downloads, or fast-math.
timeout 180 g++ -std=c++11 -O1 -fPIC -shared -fno-rtti -fno-exceptions \
  -Wall -Wextra -Iupstream/Recast/Include -Iupstream/Detour/Include \
  -Iupstream/DetourCrowd/Include \
  upstream/Recast/Source/*.cpp upstream/Detour/Source/*.cpp \
  upstream/DetourCrowd/Source/*.cpp blind_detour.cpp -o libblind_detour.so.pending
# Atomic replacement preserves any library already mapped by another process.
mv libblind_detour.so.pending libblind_detour.so
python - <<'PY'
from pathlib import Path
import hashlib,json,subprocess
p=Path('.');b=p/'libblind_detour.so';m=json.loads((p/'UPSTREAM_MANIFEST.json').read_text())
m['buildStatus']='built; local adapter tests separate';m['libraryBytes']=b.stat().st_size;m['librarySHA256']=hashlib.sha256(b.read_bytes()).hexdigest();m['compiler']=subprocess.check_output(['g++','--version'],text=True).splitlines()[0]
(p/'UPSTREAM_MANIFEST.json').write_text(json.dumps(m,indent=2)+'\n')
assert sum(x.stat().st_size for x in p.rglob('*') if x.is_file())<200*1024*1024
print(json.dumps({k:m[k] for k in ['buildStatus','libraryBytes','librarySHA256','compiler']},indent=2))
PY

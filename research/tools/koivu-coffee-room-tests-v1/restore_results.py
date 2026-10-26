"""Restore only lossless historical results in a separately prepared reproduction copy.
Does not overwrite mismatching existing files. No geometry/native execution.
"""
from pathlib import Path
import gzip,hashlib,json,shutil
R=Path(__file__).resolve().parent
m=json.loads((R/'COMPRESSED_RESULTS.json').read_text())
assert shutil.disk_usage(R).free>768*1024**2+sum(x['originalBytes']for x in m['assets'])
for row in m['assets']:
 b=gzip.decompress((R/row['storedPath']).read_bytes());assert hashlib.sha256(b).hexdigest()==row['originalSHA256']
 p=R/row['originalPath']
 if p.exists():assert p.read_bytes()==b
 else:
  p.parent.mkdir(parents=True,exist_ok=True)
  with p.open('xb')as f:f.write(b)
print('Historical results restored; original packet manifest does not cover these derived copies.')

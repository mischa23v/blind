"""Hash/serialization helpers, no geometry or controller policy."""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent
def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb')as f:
  while b:=f.read(1024**2):h.update(b)
 return h.hexdigest()
def save(p,x):Path(p).write_text(json.dumps(x,indent=2,allow_nan=False)+'\n')
def verify(expected):
 if sha(H/'FROZEN.json')!=expected:raise ValueError('evaluator manifest identity')
 f=json.loads((H/'FROZEN.json').read_text())
 for k,v in f['files'].items():
  if sha(H/k)!=v:raise ValueError('changed evaluator input: '+k)
 return f

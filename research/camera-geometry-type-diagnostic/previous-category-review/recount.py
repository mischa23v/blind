#!/usr/bin/env python3
"""Recount lifecycle hints from the preserved, already-run category traces."""
from pathlib import Path
from collections import Counter
import hashlib,json
base=Path(__file__).resolve().parents[2]/'camera-effective-type-diagnostic/results/run40564108538/attempt2'
out={"schema":1,"kind":"saved trace recount, not a new Apple test", "scopes":[]}
for f in sorted(base.rglob('*effective-type.json')):
 data=f.read_bytes(); d=json.loads(data); rows=d['rows']
 assert d['status']=='complete' and len(rows)==112 and not d['overflow']
 roles={}
 for role in ['header','button','footer']:
  rr=[r for r in rows if r['role']==role]
  roles[role]={"events":dict(Counter(r['event'] for r in rr)),
               "appearCategories":[r['dynamic'] for r in rr if r['event']=='appear'],
               "dynamicCategories":[r['dynamic'] for r in rr if r['event']=='dynamic-change']}
 out['scopes'].append({"file":str(f.relative_to(base)),"sha256":hashlib.sha256(data).hexdigest(),"launch":d['launch'],"roles":roles})
assert len(out['scopes']) == 2, 'Expected two preserved category traces'
print(json.dumps(out,indent=2))

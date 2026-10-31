from pathlib import Path
import json,hashlib,collections,re
base=Path(__file__).resolve().parent
out={'schema':1,'scope':'saved synthetic native geometry evidence; not accessibility pass','cases':[]}
for path in sorted(base.rglob('*geometry-type.json')):
 raw=path.read_bytes();d=json.loads(raw);rows=d['rows']; roles={}
 for role in ['header','button','footer','container']:
  rr=[r for r in rows if r['role']==role]
  gs=[r for r in rr if r['event']=='geometry']
  roles[role]={'events':dict(collections.Counter(r['event'] for r in rr)),
               'geometry':[{k:r[k] for k in ['seq','dynamic','uptime','frame']} for r in gs],
               'disappearanceCategories':[r['dynamic'] for r in rr if r['event']=='disappear']}
 out['cases'].append({'file':str(path.relative_to(base)),'sha256':hashlib.sha256(raw).hexdigest(),
 'traceStatus':d['status'],'overflow':d['overflow'],'rowCount':d['rowCount'],'inAuditGeometryCount':d['inAuditGeometryCount'],'geometryCoverage':d['geometryCoverage'],'flushAfterAuditEnd':d['flushAfterAuditEnd'],'roles':roles})
assert len(out['cases'])==2
for role in ['header','button','footer','container']:
 a,b=[[(r['dynamic'],r['frame']) for r in c['roles'][role]['geometry']] for c in out['cases']]
 assert a==b
out['geometrySequencesExactlyMatchAcrossScopes']=True
print(json.dumps(out,indent=2))

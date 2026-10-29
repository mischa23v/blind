#!/usr/bin/env python3
"""Prepare explicit reviewed-current pins; historical manifests remain byte-identical."""
import hashlib,json
from pathlib import Path
H=Path(__file__).resolve().parent;R=H.parents[1];P=R/'research/room-mesh-package-75';I=R/'research/mesh-candidate-ingress-83';C=R/'research/live-mesh-classified-bench-20261028'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,j):p.write_text(json.dumps(j,indent=2)+'\n')
def revised(base,old,allowed):
 out={};delta=[]
 for name,before in old.items():
  after=sha(base/name)
  if before!=after:
   if name not in allowed:raise ValueError('unreviewed changed input '+name)
   delta.append({'path':name,'before':before,'after':after})
  out[name]=after
 return out,delta
old75=json.loads((P/'APPLE_SOURCE_PINS.json').read_text());new75,d75=revised(P,old75,{'BlindRoomMesh/Package.swift','apple/ci.py'})
added=[p for p in (P/'BlindRoomMesh/Sources/CEarcut').rglob('*') if p.is_file()]+[P/'BlindRoomMesh/Sources/BlindRoomMesh/HistoricalPolygonTriangulation.swift']
for p in added:new75[str(p.relative_to(P))]=sha(p)
write(P/'APPLE_CURRENT_SOURCE_PINS.json',{'schema':1,'scope':'reviewed current Earcut integration, not historical Apple proof','historical_manifest':'APPLE_SOURCE_PINS.json','historical_manifest_sha256':sha(P/'APPLE_SOURCE_PINS.json'),'reviewed_changes':d75,'new_files':[str(p.relative_to(P)) for p in added],'files':new75})
old83=json.loads((I/'SOURCE_PINS.json').read_text());new83,d83=revised(R,old83,{'research/room-mesh-package-75/apple/ci.py','research/mesh-candidate-ingress-83/apple/ci.py','research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift'})
new83['research/room-mesh-package-75/APPLE_CURRENT_SOURCE_PINS.json']=sha(P/'APPLE_CURRENT_SOURCE_PINS.json');write(I/'CURRENT_SOURCE_PINS.json',{'schema':1,'scope':'reviewed current Earcut dependency CI, not historical stage83 proof','historical_manifest':'SOURCE_PINS.json','historical_manifest_sha256':sha(I/'SOURCE_PINS.json'),'reviewed_changes':d83,'new_files':['research/room-mesh-package-75/APPLE_CURRENT_SOURCE_PINS.json'],'files':new83})
oldC=json.loads((C/'INPUT_PINS.json').read_text());rows=[];dc=[]
for row in oldC['files']:
 path=R/row['path'];h=sha(path)
 if h!=row['sha256']:
  if row['path'] not in {'research/mesh-candidate-ingress-83/apple/ci.py','research/room-mesh-package-75/BlindRoomMesh/Package.swift','research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift','ios/BlindAssistTests/ClassificationIngressTests.swift','ios/BlindAssist/NavigationModel.swift'}:raise ValueError('unreviewed classifier delta '+row['path'])
  dc.append({'path':row['path'],'before':row['sha256'],'after':h})
 rows.append({'path':row['path'],'bytes':path.stat().st_size,'sha256':h})
for p in added:rows.append({'path':str(p.relative_to(R)),'bytes':p.stat().st_size,'sha256':sha(p)})
write(C/'CURRENT_INPUT_PINS.json',{'kind':'reviewed_current_local_inputs_not_historical_native_pass','historical_manifest':'INPUT_PINS.json','historical_manifest_sha256':sha(C/'INPUT_PINS.json'),'files':rows,'changes':dc})
write(H/'CURRENT_PIN_RECEIPT.json',{'status':'prepared; native current-source validation pending','historical_untouched':{str(p.relative_to(R)):sha(p) for p in [P/'APPLE_SOURCE_PINS.json',I/'SOURCE_PINS.json',C/'INPUT_PINS.json']},'stage75_delta':d75,'stage83_delta':d83,'classifier_delta':dc,'new_stage75_paths':[str(p.relative_to(P)) for p in added],'current_files':{str(p.relative_to(R)):sha(p) for p in [P/'APPLE_CURRENT_SOURCE_PINS.json',I/'CURRENT_SOURCE_PINS.json',C/'CURRENT_INPUT_PINS.json']}})
print('Explicit current manifests prepared; historical proofs not rewritten.')

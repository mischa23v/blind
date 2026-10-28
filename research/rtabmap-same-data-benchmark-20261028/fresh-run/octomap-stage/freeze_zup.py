from pathlib import Path
import json,hashlib,datetime
S=Path(__file__).resolve().parent;H=S.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
receipt=json.loads((H/'INPUT_RECEIPT.json').read_text());assert len(receipt['files'])==530
for r in receipt['files']:assert sha(Path(r['path']))==r['sha256'],r['path']
old=json.loads((H/'PRE_RUN_FREEZE.json').read_text());wanted=next(x for x in old['files']if x['path']=='adapter/INPUTS.tsv');assert sha(H/'adapter/INPUTS.tsv')==wanted['sha256']
paths=['ZUP_CORRECTION_PROTOCOL.md','PROTOCOL.md','adapter/mapper_zup.cpp','adapter/main_zup.cpp','adapter/world_fixture.cpp','adapter-build/koivu_mapper_zup','adapter-build/koivu_occupancy_zup','adapter-build/koivu_world_zup_fixture','build/bin/librtabmap_core.so.0.24.2','build/bin/librtabmap_utilite.so.0.24.2','logs/world-zup-fixtures.log','logs/occupancy-zup-fixtures.log','common-surface-proposal/FROZEN.json','STAGE_LIMITS.json','guard.py']
d={'frozenBeforeRecordedDataUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'all530InputImageHashesReverified':True,'inputTSVSHA256':sha(H/'adapter/INPUTS.tsv'),'nativeRevision':'8cd2f81a735722402d1e220147c4e83a1a746eaf','files':[{'path':p,'sha256':sha(S/p),'bytes':(S/p).stat().st_size}for p in paths]}
with(S/'ZUP_PRE_RUN_FREEZE.json').open('x')as f:json.dump(d,f,indent=2);f.write('\n')
print('530 input hashes verified; corrected stage frozen')

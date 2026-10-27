"""Cheap scope/identity/ledger checks: no VTK load or physics/cache evaluation."""
import json,hashlib,math
from pathlib import Path
from loop_map import load_plan,GoalRegionMap
from run_bounded import terminal_motion_fields
H=Path(__file__).resolve().parent;m=json.loads((H/'MATRIX.json').read_text());assert len(m['episodes'])==100 and len({(x['pairIndex'],x['conditionID'])for x in m['episodes']})==100
for i,row in enumerate(m['plans']):
 p=load_plan(H/row['path'],row['sha256']);assert p['pairIndex']==i;g=GoalRegionMap(p);assert g.flag_receipt(p['start'],0)['lowUnresolvedCells']==-1
 try:g.begin_next(1)
 except ValueError:pass
 else:raise AssertionError('single pair must reject handoff')
 try:load_plan(H/row['path'],'0'*64)
 except ValueError:pass
 else:raise AssertionError('wrong identity admitted')
assert terminal_motion_fields({},True,'episode')==(None,None)
assert terminal_motion_fields({},False,'episode')==(False,0.)
assert terminal_motion_fields({},True,'cache')==(False,0.)
assert terminal_motion_fields({'motionExecuted':True,'actualDistanceMetres':1.25},True,'episode')==(True,1.25)
assert m['episodeLimits']['CPUSeconds']==900 and m['episodeLimits']['wallSeconds']==1200 and m['maximumTicksPerEpisode']==2500
r={'distinctPairPlansChecked':20,'scheduledPairConditions':100,'wrongPlanDigestRejected':20,'handoffsRejected':20,'historicalOccupancyDiagnosticUnavailable':True,'interruptedEpisodeMovementUnknownNotZero':True,'preAdmissionFailureNoMovement':True,'nativeMeshLoaded':False,'physicalAuthority':False};(H/'ADAPTER_CONTRACT_RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
# A worker killed during a non-atomic progress write must not fabricate zero motion.
import tempfile
from run_bounded import optional_json
with tempfile.TemporaryDirectory(dir=H)as temporary:
 damaged=Path(temporary)/'partial.json';damaged.write_text('{"actualDistanceMetres":')
 value,error=optional_json(damaged,1024);assert value=={} and error is not None
 assert terminal_motion_fields(value,True,'episode')==(None,None)
report=json.loads((H/'ADAPTER_CONTRACT_RESULT.json').read_text());report['truncatedPartialJSONPreservesUnknownMovement']=True;(H/'ADAPTER_CONTRACT_RESULT.json').write_text(json.dumps(report,indent=2)+'\n')

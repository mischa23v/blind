"""Read saved map masks only; no fusion, labels, route search or reference geometry."""
from pathlib import Path
import hashlib,json,numpy as np
ROOT=Path(__file__).resolve().parent
source=ROOT/'run-01/map/SURFACE_EVIDENCE.npz'
digest=hashlib.sha256(source.read_bytes()).hexdigest()
if digest!='c4b80a0305a82fd7dfe1e7de8d8a5da6396634dd8afd832663f5eb31baffdfd8':raise ValueError('changed saved evidence')
d=np.load(source);s=d['support'];b=d['surfaceBelowFloorContradiction'];o=d['surfacePositiveOccupied'];u=d['surfacePositiveUnresolved'];clear=d['surfaceClearanceKnown']
r={'surfaceCells':len(s),'missingSupport':int((~s).sum()),'supported':int(s.sum()),'supportedWithNativeOccupied':int((s&o).sum()),'supportedWithBelowFloorContradiction':int((s&b).sum()),'supportedWithBoth':int((s&o&b).sum()),'supportedWithUnknownPositive':int((s&u).sum()),'supportedBlockedNativeOnly':int((s&o&~b).sum()),'supportedBlockedBelowOnly':int((s&~o&b).sum()),'supportedUnblocked':int((s&~o&~b&~u).sum()),'unblockedButCoverageIncomplete':int((~d['blocked']&~clear).sum()),'finalClearanceCells':int(clear.sum()),'groundFreeConflictTotal':int(d['surfaceGroundNativeFreeConflict'].sum()),'groundFreeConflictAmongFinalClearance':int((d['surfaceGroundNativeFreeConflict']&clear).sum()),'eachCellSquareMetres':.01,'interpretation':'Overlapping blockers reported separately; no map/body/threshold/route change.','inputSHA256':digest,'sourceSHA256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest()}
assert r['supported']==r['supportedBlockedNativeOnly']+r['supportedBlockedBelowOnly']+r['supportedWithBoth']+r['supportedUnblocked']
assert hashlib.sha256(source.read_bytes()).hexdigest()==digest
with (ROOT/'BLOCKER_BREAKDOWN_VERIFIED.json').open('x')as f:f.write(json.dumps(r,indent=2)+'\n')
print(json.dumps(r))

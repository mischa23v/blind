"""Read-only saved-trace recount; does not rerun physics or alter frozen inputs."""
from pathlib import Path
import csv,gzip,hashlib,json,lzma,math,sys
H=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
count=int(sys.argv[1]); matrix=json.loads((H/'MATRIX.json').read_text()); rows=[]
ledger=json.loads((H/'EPISODE_LEDGER.json').read_text()); skipped=[]; budget=[]
for index in range(count):
 if ledger[index]['status']=='interruptedUnknown':
  skipped.append({'episodeIndex':index,'status':'interruptedUnknown','notScored':True});continue
 if ledger[index]['status']=='computeBudgetOrInfrastructureFailure':
  receiptpath=H/ledger[index]['receipt'];receipt=json.loads(receiptpath.read_text());assert receipt['processStarted'] and not receipt['processCompleted'] and receipt['failure'] and not ledger[index]['arrival'];assert receipt['limits']==matrix['episodeLimits'] and receipt['evaluatorManifestSHA256']==sha(H/'FROZEN.json')
  partial=H/ledger[index]['partialTracePath'];progresspath=H/'episodes'/f'episode-{index:03d}'/'result/LIVE_PROGRESS.json';progress=json.loads(progresspath.read_text())
  assert not (progresspath.parent/'RESULT.json').exists()
  budget.append({'episodeIndex':index,'status':'computeBudgetOrInfrastructureFailure','notScored':True,'terminalMotionOutcome':'unavailable','boundedReceipt':receipt,'boundedReceiptSHA256':sha(receiptpath),'partialTraceSHA256':sha(partial),'partialProgressSHA256':sha(progresspath),'partialProgressNotTerminal':progress})
  continue
 d=H/'episodes'/f'episode-{index:03d}'/'result';r=json.loads((d/'RESULT.json').read_text());schedule=matrix['episodes'][index];plan=json.loads((H/matrix['plans'][schedule['pairIndex']]['path']).read_text());receipt=json.loads((H/'runs'/f'episode-{index:03d}'/'RUN_RECEIPT.json').read_text())
 assert r['schedule']==schedule and receipt['processCompleted'] and r['physicalAuthority']is False
 item={'episodeIndex':index,'pairIndex':schedule['pairIndex'],'conditionID':schedule['conditionID'],'status':r['status'],'arrival':r['arrival'],'resultSHA256':sha(d/'RESULT.json'),'boundedReceiptSHA256':sha(H/'runs'/f'episode-{index:03d}'/'RUN_RECEIPT.json')}
 if not(d/'ACTUAL_TRACE_PARTIAL.csv').exists():
  assert not r['motionExecuted']and r['actualDistanceMetres']==0 and r['ticks']==0;item.update(movementExecuted=False,horizontalMetres=0,traceAbsentForZeroTickOutcome=True);rows.append(item);continue
 assert sha(d/'ACTOR_TRACE.npz')==r['traceSHA256']
 with(d/'ACTUAL_TRACE_PARTIAL.csv').open()as f:trace=list(csv.DictReader(f))
 assert len(trace)==r['ticks']+1
 xyz=[[float(x[k])for k in('x','y','z')]for x in trace];horizontal=sum(math.hypot(b[0]-a[0],b[2]-a[2])for a,b in zip(xyz,xyz[1:]));assert abs(horizontal-r['actualDistanceMetres'])<1e-9
 n=0;distance3d=0;moving=0;rejected=0;last=None
 with lzma.open(d/'TICK_EVIDENCE.jsonl.xz','rt')as f:
  for line in f:
   t=json.loads(line);assert t['tick']==n;n+=1;last=t
   assert t['cue']['physicalAuthority']is False
   if t['candidateStateCommitted'] and t['movement'] is not None:
    moving+=1;distance3d+=t['movement']['attempted3DDistanceMetres'];assert len(t['contacts'])==2 and t['underbodyGuard']['checkedHalfSegments']==2 and t['underbodyGuard']['actualMidpointCovered'] and not t['underbodyGuard']['contact']
    for c in t['contacts']:assert not c['actualBody']['contact']and not c['horizontalMargin']['contact']
    for g in t['underbodyGuard']['halfSegments']:assert not g['contact']
    for s in t['support']:assert s['acceptedFiniteSupportModel']
   if not t['candidateStateCommitted']:rejected+=1
 assert n==r['ticks']and abs(distance3d-r['actual3DDistanceMetres'])<1e-9 and math.dist(xyz[-1],r['finalPosition'])<1e-12
 if r['arrival']:
  assert not r['finalPendingMotion']and r['finalAppliedCommand']['forward_metres']==0 and r['finalAppliedCommand']['yaw_radians']==0
  assert math.dist(r['finalPosition'],plan['goal'])<=.35 and last['goalObservationCurrent']and last['cue']['goalReached']
  assert last['deliveredPose']['capturedTick']>last['lastCommittedMotionTick']
 if schedule['conditionID']=='tracking_interruption':assert r['interruptionExposureComplete']==(r['stressCounts'].get('captureWithheldTicks',0)==30)
 item.update(movementExecuted=horizontal>0,horizontalMetres=horizontal,actual3DMetres=distance3d,ticks=n,committedMovingTicks=moving,rejectedProposals=rejected,finalOriginalGoalErrorMetres=math.dist(r['finalPosition'],plan['goal']),drainedCurrentArrivalVerified=bool(r['arrival']),tickEvidenceSHA256=sha(d/'TICK_EVIDENCE.jsonl.xz'),csvSHA256=sha(d/'ACTUAL_TRACE_PARTIAL.csv'));rows.append(item)
result={'scope':'independent saved CSV/tick-evidence recount, not a second physics run','scheduledThroughExclusive':count,'skippedUnknown':skipped,'resourceOrInfrastructureOutcomes':budget,'episodesReviewed':len(rows),'movementEpisodes':sum(x['movementExecuted']for x in rows),'arrivals':sum(x['arrival']for x in rows),'evaluatorManifestSHA256':sha(H/'FROZEN.json'),'cacheManifestSHA256':sha(H/'CACHE_MANIFEST.json'),'physicalAuthority':False,'rows':rows}
out=H/'reviews'/f'RECOUNT_WITH_BUDGET_{count:03d}.json';assert not out.exists();out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

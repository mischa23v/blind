"""Read-only summary of frozen terminal receipts; no physics execution."""
from pathlib import Path
import collections,datetime,hashlib,json,sys
H=Path(sys.argv[1]).resolve(); O=Path(sys.argv[2]).resolve()
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
ledger=json.loads((H/'EPISODE_LEDGER.json').read_text());matrix=json.loads((H/'MATRIX.json').read_text());recount=json.loads((H/'reviews/RECOUNT_WITH_BUDGET_100.json').read_text())
assert len(ledger)==100 and recount['scheduledThroughExclusive']==100
assert not (H/'ACTIVE_RUN.lock').exists()
assert all(r['status'] not in ('notRun','running') for r in ledger)
expected='3d17b1b816abd553fde50ea9702e35b4bcd380d10b18375f5535be2a5101b525';assert sha(H/'FROZEN.json')==expected
verified={}
for n in ('FROZEN.json','CACHE_MANIFEST.json'):
 m=json.loads((H/n).read_text())
 for p,digest in m['files'].items():assert sha(H/p)==digest,(n,p)
 verified[n]={'sha256':sha(H/n),'verifiedFileCount':len(m['files'])}
rows=[]; completed=[];receiptRows=[]
for i,row in enumerate(ledger):
 assert row['episodeIndex']==i
 item={'episodeIndex':i,'pairIndex':row['pairIndex'],'conditionID':row['conditionID'],'status':row['status'],'arrival':row.get('arrival',False),'physicalAuthority':False}
 if row['status']=='interruptedUnknown':
  item.update(terminalMotionOutcome='unknown',includedInCompletedMovement=False)
 else:
  p=H/f'runs/episode-{i:03d}/RUN_RECEIPT.json';receipt=json.loads(p.read_text());assert receipt['limits']==matrix['episodeLimits'] and receipt['evaluatorManifestSHA256']==expected
  item.update(boundedReceiptSHA256=sha(p),CPUSeconds=receipt['CPUSeconds'],wallSeconds=receipt['wallSeconds'],peakRSSBytes=receipt['peakSampledTreeOrWaitRSSBytes']);receiptRows.append(receipt)
  if receipt['processCompleted']:
   assert not receipt['failure'] and receipt['CPUSeconds']<=900 and receipt['wallSeconds']<=1200 and receipt['peakSampledTreeOrWaitRSSBytes']<=matrix['episodeLimits']['RSSBytes']
   p=H/f'episodes/episode-{i:03d}/result/RESULT.json';r=json.loads(p.read_text());assert r['schedule']==matrix['episodes'][i] and r['arrival']==item['arrival'] and r['physicalAuthority'] is False
   item.update(includedInCompletedMovement=True,resultSHA256=sha(p),distanceMetres=r['actualDistanceMetres'],ticks=r['ticks'],actualBodyContactEvents=r['actualBodyContactEvents'],marginContactEvents=r['marginContactEvents'],rejectedPredictedBodyContactEvents=r['rejectedPredictedBodyContactEvents'],rejectedPredictedUnderbodyContactEvents=r['rejectedPredictedUnderbodyContactEvents'],groundContacts=r['groundContacts']);completed.append(item)
  else:
   assert row['status']=='computeBudgetOrInfrastructureFailure' and not item['arrival']
   item.update(includedInCompletedMovement=False,terminalMotionOutcome='unavailable',failure=receipt['failure'],partialProgress=row['partialProgress'])
 rows.append(item)
assert len(completed)==recount['episodesReviewed']==94
assert sum(x['arrival'] for x in completed)==recount['arrivals']==90
assert sum(x['actualBodyContactEvents'] for x in completed)==0
pairs=[]
for i in range(20):
 a=[x for x in rows if x['pairIndex']==i];assert len(a)==5
 pairs.append({'pairIndex':i,'arrivalCount':sum(x['arrival']for x in a),'allFiveArrived':all(x['arrival']for x in a),'outcomes':[{k:x[k]for k in ('episodeIndex','conditionID','status','arrival')}for x in a]})
summary={'createdUTC':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'all100 frozen schedules accounted;94 completed simulated movement episodes, not100 completed trials','countsByStatus':dict(collections.Counter(x['status']for x in rows)),'scheduled':100,'completedMovementEpisodes':len(completed),'arrivals':sum(x['arrival']for x in completed),'supportStops':[x['episodeIndex']for x in rows if x['status']=='unknownReferenceSupportDuringMotion'],'predictedUnderbodyRejections':[x['episodeIndex']for x in rows if x['status']=='rejectedPredictedUnderbodyObstacle'],'interruptedUnknown':[x['episodeIndex']for x in rows if x['status']=='interruptedUnknown'],'resourceLimitedPartial':[x['episodeIndex']for x in rows if x['status']=='computeBudgetOrInfrastructureFailure'],'allFiveConditionsArrivedPairCount':sum(x['allFiveArrived']for x in pairs),'completedActualBodyContacts':sum(x['actualBodyContactEvents']for x in completed),'completedMarginContacts':sum(x['marginContactEvents']for x in completed),'completedPredictedBodyContactRejections':sum(x['rejectedPredictedBodyContactEvents']for x in completed),'completedPredictedUnderbodyContactRejections':sum(x['rejectedPredictedUnderbodyContactEvents']for x in completed),'completedDistanceMetres':sum(x['distanceMetres']for x in completed),'completedTicks':sum(x['ticks']for x in completed),'arrivalDistanceRangeMetres':[min(x['distanceMetres']for x in completed if x['arrival']),max(x['distanceMetres']for x in completed if x['arrival'])],'maximumRecordedCPUSeconds':max(x['CPUSeconds']for x in receiptRows),'maximumCompletedCPUSeconds':max(x['CPUSeconds']for x in completed),'maximumRecordedWallSeconds':max(x['wallSeconds']for x in receiptRows),'maximumRecordedPeakRSSBytes':max(x['peakSampledTreeOrWaitRSSBytes']for x in receiptRows),'verifiedInputs':verified,'recountSHA256':sha(H/'reviews/RECOUNT_WITH_BUDGET_100.json'),'ledgerSHA256':sha(H/'EPISODE_LEDGER.json'),'matrixSHA256':sha(H/'MATRIX.json'),'activeRunLockAbsent':True,'physicalAuthority':False,'groundContacts':'unmeasured; immutable classified ground exempted','evaluatorWorldVetoIsNotPhoneDetection':True,'providedPoseNotLocalizationProof':True,'pairs':pairs,'episodes':rows}
assert not O.exists();O.write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps({k:v for k,v in summary.items()if k not in ('pairs','episodes')}))

"""Pin every prepared/unavailable evaluator cache before movement scoring."""
import json,sys
from runtime import H,sha,save,verify
expected=sys.argv[1];verify(expected);assert not(H/'CACHE_MANIFEST.json').exists();ledger=json.loads((H/'CACHE_LEDGER.json').read_text());assert len(ledger)==20 and all(r['status']!='notRun'for r in ledger),'all predeclared cache outcomes required'
files={'CACHE_LEDGER.json':sha(H/'CACHE_LEDGER.json')};records=[]
for i,row in enumerate(ledger):
 assert row['pairIndex']==i
 receipt=H/row['receipt'];files[str(receipt.relative_to(H))]=sha(receipt);result=H/'caches'/f'pair-{i:02d}'/'RESULT.json'
 record={'pairIndex':i,'status':row['status'],'resultPath':str(result.relative_to(H))if result.exists()else None,'computeReceipt':row['receipt']}
 if result.exists():
  files[str(result.relative_to(H))]=sha(result);r=json.loads(result.read_text())
  if row['processCompleted']and r['status']=='membershipReady':
   for name,digestkey in [('GROUND_IDS.npz','membershipSHA256'),('PATCH_FITS.json.gz','patchFitsSHA256')]:
    p=result.parent/name;assert sha(p)==r[digestkey];files[str(p.relative_to(H))]=sha(p)
  elif r['status']=='membershipReady':record['status']='computeBudgetOrInfrastructureFailure'
 records.append(record)
save(H/'CACHE_MANIFEST.json',{'evaluatorManifestSHA256':expected,'files':files,'records':records,'allCacheOutcomesRetained':True,'movementEpisodes':0,'physicalAuthority':False});print(sha(H/'CACHE_MANIFEST.json'))

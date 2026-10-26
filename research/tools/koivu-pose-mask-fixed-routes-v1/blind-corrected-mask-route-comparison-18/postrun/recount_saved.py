"""Saved candidates plus immutable mask flags; no native engine construction/query."""
from pathlib import Path
import hashlib,json,math,resource,signal,sys,time
START=time.monotonic();resource.setrlimit(resource.RLIMIT_CPU,(10,10));resource.setrlimit(resource.RLIMIT_FSIZE,(1024**2,1024**2));signal.alarm(15)
sys.dont_write_bytecode=True
import numpy as np
HERE=Path(__file__).resolve().parent;ROOT=HERE.parent;WS=ROOT.parent;OUT=ROOT/'run-01/result';sys.path.insert(0,str(ROOT))
import paired_adapter as a
FREEZE='9056e43f8ae3dde28ebf3176a76c8577502db0bec9eedafb35f9bdb13f5fea2e'
assert a.sha(ROOT/'FROZEN.json')==FREEZE
pins=json.loads((ROOT/'FROZEN.json').read_text())['files']
def check():
 for p,h in pins.items():assert a.sha(WS/p)==h,p
check();run=json.loads((ROOT/'run-01/RUN_RECEIPT.json').read_text());summary=json.loads((OUT/'RESULTS.json').read_text())
assert run['success']and run['frozenManifestSHA256']==FREEZE and summary['nativeQueries']==36 and len(summary['results'])==6
helpers=a.helper_modules();meta={k:a.metadata(k)for k in('old','new')}
B=np.array([[1.,0,0],[0,0,-1],[0,1,0]])
L={}
for k,m in meta.items():L[k]=np.eye(4);L[k][:3,:3]=m['R'];L[k][:3,3]=m['t']
matrices={k:np.linalg.inv(v)for k,v in L.items()}
artifacts={};report=[];roundtrip=0.;mapping_error=0.;vertical_requests=[];projected_deltas=[];native_queries=0
for row in summary['results']:
 path=OUT/row['artifact'];assert a.sha(path)==row['sha256'];r=json.loads(path.read_text());key=(r['profile'],r['map']);assert key not in artifacts;artifacts[key]=r
 assert len(r['legs'])==r['nativeQueries']==6;native_queries+=r['nativeQueries']
 assert [{'objectiveID':x['objectiveID'],'status':x['status']}for x in r['legs']]==row['legStatuses']
 if r['map']=='old':assert r['oldNativeHistoryParityAllFields']is True and all(all(x['oldHistoricalNativeParity'].values())for x in r['legs'][:4])
 for spec,leg in zip(r['fixedObjectiveSpecification'],r['legs']):
  assert spec['objectiveID']==leg['objectiveID']
  for end in('start','goal'):
   point=np.asarray(spec[end+'OldGame']);phone=matrices['old']@np.r_[B@point,1.];new_level=L[r['map']]@phone;expected=B.T@new_level[:3]
   actual=np.asarray(leg['requested'+end.title()+'XYZ']);mapping_error=max(mapping_error,float(abs(actual-expected).max()))
   prov=leg[end+'CoordinateProvenance'];assert np.allclose(phone[:3],prov['unchangedPhoneXYZ'],atol=1e-12,rtol=0)
   back=B.T@(L['old']@(matrices[r['map']]@np.r_[B@actual,1.]))[:3];roundtrip=max(roundtrip,float(abs(back-point).max()))
   assert np.allclose(actual,expected,atol=1e-12,rtol=0)and not prov['mappedHeightWasFlattened']
   vertical_requests.append(float(actual[1]))
   assoc=leg[end+'Association']
   if assoc['validProjectedXYZ']:
    delta=np.asarray(assoc['projectedXYZ'])-actual
    assert np.allclose(delta,assoc['deltaXYZMetres'],atol=0,rtol=0)
    assert float(delta[1])==assoc['verticalDisplacementMetres'];projected_deltas.append(float(delta[1]))
  if leg['kind']=='loopLeg'and r['map']=='old':
   fields=('complete','points','reason','nativeComplete','nativeStatus','nativeError','projectedStart','projectedGoal','sampledRectangleResult')
   assert all(leg['nativeAndOriginalRectangleResult'][k]==spec['priorNativeResult'][k]for k in fields)
  report.append({'profile':r['profile'],'map':r['map'],'objectiveID':leg['objectiveID'],'status':leg['status'],'nativeReason':leg['nativeAndOriginalRectangleResult']['reason']})
assert native_queries==36 and roundtrip<1e-12 and mapping_error<1e-12
# Models below have no engine. Original immutable methods only inspect arrays.
flags=[]
for (profile,label),r in artifacts.items():
 variants=a.load('flag_recount_profiles_'+profile+'_'+label,a.VARIANTS/'margin_variants.py',a.VARIANTS_SHA);cm=variants.base_module()
 model=cm.CandidateMap.__new__(cm.CandidateMap);model.engine=None;model.rr=variants.rectangle_module(profile)
 with np.load(a.INPUTS[label]['mask'],allow_pickle=False)as z:model.flags={k:z[k].copy()for k in a.PHONE_KEYS}
 model.mask=model.flags['walk'];model.origin=tuple((meta[label]['lo'][:2]*.05).tolist());model.revision=r['mapRevision']
 for v in model.flags.values():v.setflags(write=False)
 for leg in r['legs']:
  if leg['status']!='fixedPhoneModelLegAccepted':continue
  p=np.asarray(leg['planarFootprintValidationPath']);xy=np.c_[p[:,0],-p[:,2]];d=np.diff(xy,axis=0);length=np.linalg.norm(d,axis=1);theta=np.arctan2(d[:,1],d[:,0]);poses=[]
  for i,(u,v,ll,angle)in enumerate(zip(xy[:-1],xy[1:],length,theta)):
   if i:
    previous=float(theta[i-1]);change=(float(angle)-previous+math.pi)%(2*math.pi)-math.pi
    for k in range(int(abs(change)/math.radians(5))+2):poses.append((*u,previous+change*min(1,k*math.radians(5)/max(abs(change),1e-9))))
   for distance in np.arange(0,ll+1e-9,.025):poses.append((*(u+(v-u)*min(1,float(distance/ll))),float(angle)))
   poses.append((*v,float(angle)))
  receipts=[model.flag_receipt([x,0.,-y],-th)for x,y,th in poses]
  diagnostic=helpers['loop'].route_flags(model,poses)
  assert diagnostic['lowUnresolvedCellVisits']==sum(x['lowUnresolvedCells']for x in receipts)
  assert diagnostic['posesWithLowUnresolved']==sum(x['lowUnresolvedCells']>0 for x in receipts)
  fitfail=sum(not x['sampledFit']for x in receipts);assert fitfail==0
  flags.append({'profile':profile,'map':label,'objectiveID':leg['objectiveID'],'allOriginalFlagReceiptsSampledFit':True,**diagnostic})
 model.close()
changes=[]
for profile in a.PROFILES:
 old,new=artifacts[(profile,'old')],artifacts[(profile,'new')]
 for u,v in zip(old['legs'],new['legs']):
  assert u['objectiveID']==v['objectiveID'];changes.append({'profile':profile,'objectiveID':u['objectiveID'],'oldStatus':u['status'],'newStatus':v['status'],'acceptanceChanged':(u['status']=='fixedPhoneModelLegAccepted')!=(v['status']=='fixedPhoneModelLegAccepted')})
assert not any(x['acceptanceChanged']for x in changes)
assert not any(x['cycle'].get('accepted',False)for x in artifacts.values())
check()
result={'confirmed':True,'sixArtifactHashesReconciled':True,'all36FixedOutcomesReconciled':True,'oldLoopNativeHistoricalParityAll12Legs':True,'samePhoneSpaceObjectiveMappingMaxAbsErrorMetres':mapping_error,'coordinateRoundtripMaxAbsErrorMetres':roundtrip,'requestedGameYRangeMetres':[min(vertical_requests),max(vertical_requests)],'projectedMinusRequestedYRangeMetres':[min(projected_deltas),max(projected_deltas)],'acceptedLegs':len(flags),'fullLoopsAccepted':0,'pairedAcceptanceChanges':changes,'savedLegOutcomes':report,'acceptedLegSampledFlags':flags,'flagMethod':'Original CandidateMap.flag_receipt for every sampled pose plus unchanged table_loop.route_flags for unique-cell/visit reconciliation. No Engine constructor or route invocation.','currentNativeQueries':0,'referenceInputsUsed':False,'movementEpisodesExecuted':0,'physicalAuthority':False,'allFrozenFilesVerifiedBeforeAfter':True,'frozenSHA256':FREEZE,'wallSeconds':time.monotonic()-START,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
assert result['peakRSSBytes']<256*1024**2
signal.alarm(0)
with(HERE/'RECOUNT_AND_FLAGS.json').open('x')as f:json.dump(result,f,indent=2,allow_nan=False);f.write('\n')
print(json.dumps({k:result[k]for k in('confirmed','acceptedLegs','fullLoopsAccepted','samePhoneSpaceObjectiveMappingMaxAbsErrorMetres','coordinateRoundtripMaxAbsErrorMetres','requestedGameYRangeMetres','projectedMinusRequestedYRangeMetres','acceptedLegSampledFlags','wallSeconds','peakRSSBytes')}),flush=True)

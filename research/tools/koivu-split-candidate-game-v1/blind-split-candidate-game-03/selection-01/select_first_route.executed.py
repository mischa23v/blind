"""One deterministic phone-only route selection; never replace after truth scoring."""
from pathlib import Path
import argparse,json,math,resource,time,hashlib,os
import numpy as np
from scipy import ndimage
from candidate_map import CandidateMap,ROOT,RES,DISC,source_route,sha

def select(m):
 d=ndimage.distance_transform_edt(m.mask)*RES-RES*math.sqrt(2)/2
 candidates=np.argwhere(d>=DISC);rng=np.random.default_rng(11)
 pick=candidates[rng.choice(len(candidates),min(60,len(candidates)),replace=False)] if len(candidates) else np.empty((0,2),int)
 endpoints=[];endpoint_trials=[]
 for index,(i,j)in enumerate(pick):
  x=m.origin[0]+(int(i)+.5)*RES;y=m.origin[1]+(int(j)+.5)*RES
  fit=any(m.rr.rect_ok(m.mask,m.origin,x,y,math.radians(k*5))for k in range(72))
  p=[x,0.,-y];endpoint_trials.append({'pickedIndex':index,'sourceIJ':[int(i),int(j)],'gamePoint':p,'someSampledHeadingFits':bool(fit)})
  if fit:endpoints.append(p)
 trials=[];selected=None
 for ai,a in enumerate(endpoints):
  for bi in range(ai+1,len(endpoints)):
   b=endpoints[bi];r=m.route(a,b)
   path=[a]+r['points'];length=float(np.linalg.norm(np.diff(np.asarray(path)[:,[0,2]],axis=0),axis=1).sum()) if len(path)>1 else 0.
   reason=r['reason']
   if r['nativeComplete'] and reason not in ('query_association','incomplete') and not 2<=length<=6:reason='length_outside_2_to_6'
   trial={'pairIndex':len(trials),'endpointIndices':[ai,bi],'start':a,'goal':b,'reason':reason,'pathLengthMetres':length,'nativeComplete':r['nativeComplete'],'nativeStatus':r['nativeStatus'],'projectedStart':r['projectedStart'],'projectedGoal':r['projectedGoal'],'sampledRectangleResult':r['sampledRectangleResult']};trials.append(trial)
   if r['complete'] and 2<=length<=6:
    direction=next((np.asarray(p)-a for p in r['points'] if np.linalg.norm((np.asarray(p)-a)[[0,2]])>1e-9),None)
    if direction is None:raise RuntimeError('complete nonzero route has no first direction')
    yaw=math.atan2(float(direction[2]),float(direction[0]))
    selected={'start':a,'goal':b,'initialYawRadians':yaw,'nativeInitialRoute':r,'straightDistanceMetres':float(np.linalg.norm((np.asarray(b)-a)[[0,2]])),'pathLengthMetres':length,'selectedPairIndex':len(trials)-1,'initialFlags':m.flag_receipt(a,yaw)};break
  if selected is not None:break
 return {'scope':'First phone-only split0.7 permissive model candidate, not safety or a movement episode','selected':selected is not None,'status':'selectedPhoneOnly' if selected is not None else 'noPhoneMapRoute',**(selected or {}),'seed':11,'maximumSampledEndpoints':60,'discCentres':len(candidates),'pickedEndpoints':len(pick),'someHeadingFitEndpoints':len(endpoints),'endpointTrials':endpoint_trials,'pairTrials':trials,'mapRevision':m.revision,'sourceToGame':'[levelX,levelY,height] -> [levelX,height,-levelY]','maskCellConvention':'source(i,j) game z=[-(loY+j+1)*.05,-(loY+j)*.05]','nativeRadiusMetres':DISC,'actualBodyFullDimensionsMetres':{'lateral':.45,'forward':.30,'height':1.6},'planningMarginEachSideMetres':.15,'sampledFitSpacingMetres':.025,'sampledTurnStepDegrees':5,'FAROUsed':False,'physicalAuthority':False,'referenceOutcomeMayNotReplaceSelection':True,'farOnlyDipFlag':'unavailable'}

def json_safe(value):
 if isinstance(value,float) and not math.isfinite(value):return None
 if isinstance(value,dict):return {k:json_safe(v)for k,v in value.items()}
 if isinstance(value,(list,tuple)):return [json_safe(v)for v in value]
 return value

def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,default=ROOT/'FIRST_ROUTE.json');a=ap.parse_args()
 if a.output.exists():raise FileExistsError(a.output)
 resource.setrlimit(resource.RLIMIT_CPU,(60,65));start=time.monotonic()
 with CandidateMap()as m:result=select(m)
 result['resources']={'wallSeconds':time.monotonic()-start,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
 result['sourceSHA256']={'candidate_map.py':sha(Path(__file__).with_name('candidate_map.py')),'select_first_route.py':sha(Path(__file__))}
 a.output.write_text(json.dumps(json_safe(result),indent=2,allow_nan=False)+'\n');print(json.dumps({'selected':result['selected'],'pairTrials':len(result['pairTrials']),'pathLengthMetres':result.get('pathLengthMetres'),'output':str(a.output),'sha256':sha(a.output),'resources':result['resources']}))
if __name__=='__main__':main()

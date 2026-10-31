"""One frozen geometry-only recorded-ledger build and20queries; no movement."""
from pathlib import Path
import hashlib,json,os,resource,signal,subprocess,sys,time
H=Path(__file__).resolve().parent;ROOT=H.parents[2]
INPUT_SHA='9600a91793b48e6b1d8423c229a9136be17ba3b1c3337ef09b4d134b0807eb40'
def digest(p):
 h=hashlib.sha256()
 with p.open('rb')as f:
  for block in iter(lambda:f.read(1024*1024),b''):h.update(block)
 return h.hexdigest()
def inputs():
 p=H/'FROZEN_INPUTS_AND_ANCHORS.json';assert digest(p)==INPUT_SHA
 f=json.loads(p.read_text())
 for row in f['files']:
  p=ROOT/row['path'];assert p.stat().st_size==row['bytes'] and digest(p)==row['sha256'],str(p)
 return f
def worker():
 f=inputs();sys.path.insert(0,str(H.parent/'occupancy-prototype-v3'))
 import numpy as np
 from occupancy_engine import OccupancyEngine,Config,DT
 rows=np.memmap(ROOT/f['files'][0]['path'],dtype=DT,mode='r');assert len(rows)==2268956
 result={'scope':'projected corridor connectivity only, not actual task/landmark navigation','inputFreezeSHA256':INPUT_SHA,'syntheticProfile':True,'profileMeasured':False,'requestedEndpointConnectionsVerified':False,'requestedRouteComplete':False,'evidenceQualifiedTraversable':False,'physicalAuthority':False,'movementExecuted':False,'executedMovementMetres':0,'episodesExecuted':0,'queries':[]}
 started=time.monotonic()
 try:
  with OccupancyEngine(rows,Config(**f['configuration']))as engine:
   result['nativeBuildElapsedSeconds']=time.monotonic()-started;result['nativeStats']=engine.stats
   assert [engine.stats['width'],engine.stats['depth']]==f['expectedNativeHorizontalGrid']
   for pair in f['pairs']:
    a=f['anchors'][pair['startAnchorIndex']];b=f['anchors'][pair['goalAnchorIndex']]
    r=engine.diagnostic(a['requestedPlannerXYZ'],b['requestedPlannerXYZ'],query_half_extents=f['queryHalfExtents'],max_points=f['maxPoints'])
    assert r['requestedRouteComplete'] is False and r['requestedEndpointConnectionsVerified']is False and r['evidenceQualifiedTraversable']is False and r['physicalAuthority']is False
    if r['projectedCorridorComplete']:status='completeProjectedCorridor'
    elif r['error']and'no start or goal polygon'in r['error']:status='endpointAssociationFailed'
    elif r['path']:status='partialProjectedCorridor'
    else:status='queryErrorOrNoCorridor'
    path=np.asarray(r['path'],dtype=float);length=float(np.linalg.norm(np.diff(path,axis=0),axis=1).sum())if len(path)>1 else 0.
    result['queries'].append({**pair,'status':status,'startLeafRow':a['originalLeafRow'],'goalLeafRow':b['originalLeafRow'],'projectedCandidateLengthMetres':length,'result':r})
   result['status']='completedGeometryOnlyQueries'
 except Exception as e:
  result['status']='buildOrQueryFailure';result['errorType']=type(e).__name__;result['error']=str(e)
 result['elapsedSeconds']=time.monotonic()-started;result['queryCount']=len(result['queries']);result['scheduledQueryCount']=len(f['pairs'])
 result['outcomes']={s:sum(r['status']==s for r in result['queries'])for s in ['completeProjectedCorridor','endpointAssociationFailed','partialProjectedCorridor','queryErrorOrNoCorridor']}
 result['unexecutedQueries']=len(f['pairs'])-len(result['queries']);result['requestedRouteCompletions']=0;result['evidenceQualifiedTraversableCount']=0
 (H/'RECORDED_RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
 print(json.dumps({k:v for k,v in result.items()if k!='queries'},allow_nan=False),flush=True)
 return 0 if result['status']=='completedGeometryOnlyQueries'else 1
if '--worker'in sys.argv:sys.exit(worker())
assert not (H/'RESOURCE.json').exists()and not(H/'RECORDED_RESULT.json').exists(),'preserve prior attempt'
launch=json.loads((H/'LAUNCH_FREEZE.json').read_text());assert digest(Path(__file__))==launch['runnerSHA256']and launch['inputFreezeSHA256']==INPUT_SHA
cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu});cap=1024**3;env=os.environ.copy();env.update(OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',TBB_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
def limits():
 resource.setrlimit(resource.RLIMIT_AS,(cap,cap));resource.setrlimit(resource.RLIMIT_CPU,(60,60));resource.setrlimit(resource.RLIMIT_FSIZE,(128*1024**2,128*1024**2))
start=time.monotonic();samples=[];reason=None;peak=0;ticks=os.sysconf('SC_CLK_TCK');pages=os.sysconf('SC_PAGE_SIZE');cmd=[sys.executable,str(Path(__file__).resolve()),'--worker']
with(H/'recorded.log').open('x')as log:
 p=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,preexec_fn=limits)
 try:
  while p.poll()is None:
   rss=0;cpu_now=0.
   for path in Path('/proc').glob('[0-9]*/stat'):
    try:
     raw=path.read_text();s=raw[raw.rfind(')')+2:].split()
     if int(s[2])==p.pid:rss+=int(s[21])*pages;cpu_now+=sum(float(s[i])for i in [11,12,13,14])/ticks
    except(OSError,ValueError,IndexError):pass
   own=resource.getrusage(resource.RUSAGE_SELF);rss+=own.ru_maxrss*1024;cpu_now+=own.ru_utime+own.ru_stime;peak=max(peak,rss)
   disk=sum(x.stat().st_size for x in H.rglob('*')if x.is_file());stage=sum(x.stat().st_size for x in H.parent.rglob('*')if x.is_file())
   samples.append({'elapsedSeconds':time.monotonic()-start,'aggregateRSSBytes':rss,'aggregateCPUSeconds':cpu_now,'outputBytes':disk,'stageDiskBytes':stage})
   if rss>cap:reason='RSSLimit'
   if cpu_now>60:reason='CPULimit'
   if time.monotonic()-start>90:reason='wallLimit'
   if disk>128*1024**2 or stage>cap:reason='diskLimit'
   if reason:os.killpg(p.pid,signal.SIGKILL);break
   time.sleep(.1)
  rc=p.wait(timeout=5)
 finally:
  if p.poll()is None:os.killpg(p.pid,signal.SIGKILL);p.wait()
u=resource.getrusage(resource.RUSAGE_CHILDREN);r={'command':cmd,'inputFreezeSHA256':INPUT_SHA,'launchFreezeSHA256':digest(H/'LAUNCH_FREEZE.json'),'returncode':rc,'stopReason':reason,'elapsedSeconds':time.monotonic()-start,'childCPUSeconds':u.ru_utime+u.ru_stime,'peakSampledAggregateRSSBytes':peak,'cpuAffinity':[cpu],'samples':samples,'physicalAuthority':False};(H/'RESOURCE.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items()if k!='samples'}));sys.exit(rc if rc>=0 else 1)

from pathlib import Path
import sys,os,json,time
R=Path(__file__).resolve().parent;sys.path.insert(0,str(R/'source'));import acquire_environment as g
g.ROOT=R;g.CAP=3*1024**3;g.RESERVE=1024**3;g.CPU=600;g.WALL=900;g.RSS=2*1024**3
assert json.loads((R/'RESTORE_RECEIPT.json').read_text())['status']=='completed'
assert int(next(x for x in Path('/proc/meminfo').read_text().splitlines()if x.startswith('MemAvailable:')).split()[1])*1024>=4*1024**3
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});out=R/'fusion';out.mkdir();b=g.Bounds(R/'logs');f=R/'FUSION_FROZEN.json';freeze=json.loads(f.read_text());h=g.digest(f)
for p,v in freeze['pins'].items():assert g.digest(p)==v
cache=R/'logs/cache';cache.mkdir();home=R/'logs/home';home.mkdir();env=dict(os.environ)
for k in list(env):
 if k.startswith('PIP_')or k in ('PYTHONHOME','PYTHONPATH','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','LD_PRELOAD','LD_AUDIT','LD_LIBRARY_PATH'):env.pop(k,None)
env.update(PYTHONOPTIMIZE='0',PYTHONPATH=str(R/'environment/target'),PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',HOME=str(home),XDG_CACHE_HOME=str(cache),MPLCONFIGDIR=str(cache/'mpl'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',OPEN3D_DISABLE_WEB_VISUALIZER='true',TMPDIR=str(cache))
try:
 b.run([sys.executable,str(R/'fusion_worker.py'),str(f),str(out),h],out/'stdout.log',out/'stderr.log',env)
 for p,v in freeze['pins'].items():assert g.digest(p)==v
 result=json.loads((out/'RESULT.json').read_text());assert result['integratedFrameCount']==265
 receipt={'status':'completed','frozenSHA256':h,'pinsReverified':True,'wallSeconds':time.monotonic()-b.started,'cpuSeconds':g.cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'allocatedStageBytes':g.size(R),'phases':b.phases,'hardAggregateMemoryLimitEstablished':False};g.dump(out/'RECEIPT.json',receipt);print(json.dumps(receipt))
except BaseException as e:
 g.dump(out/'FAILURE.json',{'status':'failed','error':repr(e),'wallSeconds':time.monotonic()-b.started,'cpuSeconds':g.cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'phases':b.phases});raise

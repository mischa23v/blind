"""Prepared only. Root must release RTAB CPU ownership and supply frozen SHA."""
from pathlib import Path
import sys,os,json,hashlib,time
P=Path(__file__).resolve().parent;F=P.parent/'fresh-run';V=P/'run'
def digest(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
if len(sys.argv)!=3 or sys.argv[1]!='--root-confirmed-rtab-released':raise SystemExit('Not authorized to run automatically; root CPU-release flag and frozen SHA required')
assert digest(P/'FROZEN.json')==sys.argv[2]
freeze=json.loads((P/'FROZEN.json').read_text())
for p,h in freeze['pins'].items():assert digest(p)==h,p
assert not V.exists(),'one attempt only; preserve failed attempt, no automatic retry'
os.nice(10);os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
sys.path.insert(0,str(F/'source'));import acquire_environment as g
g.ROOT=F;g.CAP=3*1024**3;g.RESERVE=1024**3;g.CPU=1200;g.WALL=2700;g.RSS=2*1024**3
class AggregateBounds(g.Bounds):
 def new_bytes(self):return g.size(F)+g.size(P)+5*1024**2
assert int(next(x for x in Path('/proc/meminfo').read_text().splitlines()if x.startswith('MemAvailable:')).split()[1])*1024>=4*1024**3
V.mkdir();(V/'fusion').mkdir();(V/'evaluation').mkdir();(V/'logs').mkdir();(V/'cache').mkdir();(V/'home').mkdir()
b=AggregateBounds(V/'logs');b.check();env=dict(os.environ)
for k in list(env):
 if k.startswith('PIP_')or k in ('PYTHONHOME','PYTHONPATH','PYTHONUSERBASE','PYTHONPYCACHEPREFIX','LD_PRELOAD','LD_AUDIT','LD_LIBRARY_PATH'):env.pop(k,None)
env.update(PYTHONOPTIMIZE='0',PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',HOME=str(V/'home'),XDG_CACHE_HOME=str(V/'cache'),MPLCONFIGDIR=str(V/'cache/mpl'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',OPEN3D_DISABLE_WEB_VISUALIZER='true',TMPDIR=str(V/'cache'))
try:
 e=dict(env,PYTHONPATH=str(F/'environment/target'))
 b.run([sys.executable,str(P/'fusion_5m.py'),str(F/'FUSION_FROZEN.json'),str(V/'fusion'),digest(F/'FUSION_FROZEN.json')],V/'logs/fusion.stdout',V/'logs/fusion.stderr',e)
 # Same frozen evaluator settings and unchanged FARO arrays; only mesh and wrapper differ.
 evaluation=json.loads((F/'EVALUATOR_FROZEN.json').read_text());evaluation['pins']={str(V/'fusion/unfiltered-tsdf-mesh.ply'):digest(V/'fusion/unfiltered-tsdf-mesh.ply'),**freeze['pins']};g.dump(V/'EVALUATOR_FROZEN.json',evaluation)
 g.RSS=3*1024**3
 for script,args in [('evaluate_5m.py',['tsdf']),('summarize_5m.py',[]),('compare_fixed.py',[])]:
  b.run([sys.executable,str(P/script)]+args,V/'logs'/f'{script}.stdout',V/'logs'/f'{script}.stderr',env)
 for p,h in freeze['pins'].items():assert digest(p)==h
 g.dump(V/'RECEIPT.json',{'status':'completed','postHocDevelopmentOnly':True,'oneVariantDepthTrunc':5,'frozenSHA256':sys.argv[2],'peakSampledTreeRSS':b.peak_rss,'aggregateDiskBytes':b.new_bytes(),'phases':b.phases,'physicalAuthority':False,'hardAggregateMemoryLimitEstablished':False})
except BaseException as e:
 g.dump(V/'FAILURE.json',{'status':'failed','error':repr(e),'phases':b.phases,'sampledPeakRSS':b.peak_rss});raise

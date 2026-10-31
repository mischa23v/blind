from pathlib import Path
import sys,os,json,time
R=Path(__file__).resolve().parent;sys.path.insert(0,str(R/'source'));import acquire_environment as g
g.ROOT=R;g.CAP=3*1024**3;g.RESERVE=1024**3;g.RSS=3*1024**3
rest=json.loads((R/'RESTORE_RECEIPT.json').read_text());fusion=json.loads((R/'fusion/RECEIPT.json').read_text());g.CPU=1200-rest['cpuSeconds']-fusion['cpuSeconds'];g.WALL=2700-rest['wallSeconds']-fusion['wallSeconds'];assert g.CPU>0 and g.WALL>0
assert int(next(x for x in Path('/proc/meminfo').read_text().splitlines()if x.startswith('MemAvailable:')).split()[1])*1024>=4*1024**3
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});b=g.Bounds(R/'logs');contract=json.loads((R.parent/'DATA_CONTRACT.json').read_text());base=R/'inputs/room_datasets/koivu'
assert g.digest(base/'gt_mesh.ply')==contract['reference']['extractedMeshSHA256'];assert g.digest(base/'icp_iphone.json')==contract['reference']['registrationSHA256']
pins={str(p):g.digest(p)for p in [R/'fusion/unfiltered-tsdf-mesh.ply',base/'gt_mesh.ply',base/'icp_iphone.json',base/'iphone/long_capture/transformations.json',base/'iphone/long_capture/test.txt',R/'FUSION_FROZEN.json',R/'evaluate_common.py',R/'source/reference_geometry.py',R/'source/blind-koivu-tsdf-heldout-11-evaluate.py']}
g.dump(R/'EVALUATOR_FROZEN.json',{'frameIDs':contract['excludedTestIDs'],'pins':pins,'pixelOffset':0,'sampleStride':4,'scheduledRays':1335885,'residualTolerancesMetres':[.02,.05,.10],'fittingPerformed':False,'missingHitMeansFree':False,'physicalAuthority':False})
env=dict(os.environ);env.pop('PYTHONPATH',None);env.update(PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1')
try:
 for mode in ['tsdf','faro']:
  b.run([sys.executable,str(R/'evaluate_common.py'),mode],R/'logs'/('evaluate-'+mode+'.stdout'),R/'logs'/('evaluate-'+mode+'.stderr'),env)
 g.dump(R/'EVALUATION_RECEIPT.json',{'status':'completed','wallSeconds':time.monotonic()-b.started,'cpuSeconds':g.cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'totalAllocatedBytes':g.size(R),'phases':b.phases,'hardAggregateMemoryLimitEstablished':False})
except BaseException as exc:
 g.dump(R/'EVALUATION_FAILURE.json',{'status':'failed','error':repr(exc),'wallSeconds':time.monotonic()-b.started,'cpuSeconds':g.cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'phases':b.phases});raise

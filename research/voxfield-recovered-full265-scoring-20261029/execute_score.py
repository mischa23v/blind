"""One admitted arm, immutable input checks before and after scoring."""
from pathlib import Path
import os,subprocess,sys,json
from verify_inputs import verify,source_check,digest,ARMS
H=Path(__file__).resolve().parent
arm=sys.argv[1];assert arm in ARMS;D=H/arm
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
env=dict(os.environ);env.pop('PYTHONPATH',None)
env.update(PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',NUMEXPR_NUM_THREADS='1')
frozen=source_check()
receipt=verify(arm);(D/'INPUT_VERIFICATION.json').write_text(json.dumps(receipt,indent=2)+'\n')
subprocess.run([sys.executable,str(D/'evaluate_mapper.py'),'tsdf'],env=env,check=True)
subprocess.run([sys.executable,str(D/'summarize_mapper.py')],env=env,check=True)
after=verify(arm);assert receipt==after;source_check()
(D/'FINAL_INTEGRITY.json').write_text(json.dumps({'status':'passed','sourceAndInputAndCachePinsUnchanged':True,'filesReverified':len(after['checked']),'sourcePins':frozen['pins'],'fittingPerformed':False,'physicalAuthority':False},indent=2)+'\n')

"""Serial source-pinned 45/55/abstract28 phone-only feasibility; no world load."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
HERE=Path(__file__).resolve().parent;WS=HERE.parents[1]
sys.path.insert(0,str(WS/'blind-koivu-game-07'))
from run_bounded import current_tree_usage,output_bytes,kill_group
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
LIB='b6cd7e2ac35d738337e80597bcbdafd62e6884f5100867d7afbe1b77105709b0'
def main():
 out=HERE/'run-01';out.mkdir(exist_ok=False)
 paths=[HERE/x for x in ['margin_variants.py','run_variants.py','test_margin_variants.py','PROTOCOL.md','run_bounded_profiles.py','native025/libblind_detour.so','native025/detour_engine.py','native025/blind_detour.cpp','native025/blind_detour.h','native025/FINAL_VERIFICATION.json','native025/BUILD_RECEIPT.json']]
 paths += [WS/'blind-koivu-game-07/run_bounded.py',HERE.parent/'source/candidate_map.py',HERE.parent/'table-loop-proposal/table_loop.py',HERE.parent/'table-loop-proposal/topology_quick.py',HERE.parent/'table-loop-proposal/CENTRE_TOPOLOGY.json',HERE.parent/'table-loop-proposal/run-03/artifacts/PROPOSAL.json',HERE.parent/'inputs/koivu_5cm_occthres_split0.7.npz',HERE.parent/'inputs/koivu_5cm_v2_pipeline2_out.npz']
 pins={str(p.relative_to(WS)):sha(p)for p in paths};assert sha(HERE/'native025/libblind_detour.so')==LIB
 frozen={'sourceInputPins':pins,'scope':'three requested profiles and only predeclared third fallback; no world/reference','caps':{'CPUSeconds':60,'wallSeconds':90,'observedTreeRSSBytes':512*1024**2,'outputBytes':16*1024**2,'freeReserveBytes':768*1024**2},'physicalAuthority':False}
 (out/'FROZEN.json').write_text(json.dumps(frozen,indent=2)+'\n');frozen_sha=sha(out/'FROZEN.json')
 def verify():
  assert sha(out/'FROZEN.json')==frozen_sha
  for p,h in pins.items():assert sha(WS/p)==h,p
 start=time.monotonic();cpu0=current_tree_usage(os.getpid())[1];peak=0;cpu=0.;failure=None;child=None;phases=[]
 try:
  if shutil.disk_usage(HERE).free<768*1024**2+16*1024**2:raise RuntimeError('free reserve')
  verify()
  env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
  commands=[('fixtures',[sys.executable,'-B','-m','unittest','test_margin_variants','-v']),('profiles',[sys.executable,'-B',str(HERE/'run_variants.py'),'--native-directory',str(HERE/'native025'),'--native-library-sha',LIB,'--output',str(out/'artifacts')])]
  for phase,cmd in commands:
   def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(60,60));resource.setrlimit(resource.RLIMIT_FSIZE,(16*1024**2,16*1024**2));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
   with (out/(phase+'.stdout.log')).open('x')as so,(out/(phase+'.stderr.log')).open('x')as se:
    child=subprocess.Popen(cmd,cwd=HERE,stdout=so,stderr=se,env=env,start_new_session=True,preexec_fn=limits)
    while child.poll()is None:
     rss,spent=current_tree_usage(os.getpid());peak=max(peak,rss);cpu=max(cpu,spent-cpu0)
     if peak>512*1024**2 or cpu>60 or time.monotonic()-start>90 or output_bytes(out)>16*1024**2-65536 or shutil.disk_usage(HERE).free<768*1024**2:raise RuntimeError('resource cap')
     time.sleep(.1)
    code=child.wait();kill_group(child);child=None;phases.append({'phase':phase,'exitCode':code})
   verify()
   if code:raise RuntimeError(phase+' failed; evidence preserved')
 except BaseException as e:failure=repr(e)
 finally:
  if child:kill_group(child)
  rss,spent=current_tree_usage(os.getpid());peak=max(peak,rss,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024);cpu=max(cpu,spent-cpu0)
  if peak>512*1024**2 or cpu>60 or time.monotonic()-start>90:failure=failure or 'terminal resource cap'
  r={'technicalExecutionCompleted':failure is None,'failure':failure,'phases':phases,'sourceInputPinsVerifiedBeforeAfter':failure is None,'frozenSHA256':frozen_sha,'wallSeconds':time.monotonic()-start,'sampledCPUSeconds':cpu,'peakSampledOrWaitedRSSBytes':peak,'budgets':frozen['caps'],'physicalAuthority':False,'worldEpisodes':0,'referenceInputsUsed':False}
  (out/'RUN_RECEIPT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
 if failure:raise SystemExit(1)
if __name__=='__main__':main()

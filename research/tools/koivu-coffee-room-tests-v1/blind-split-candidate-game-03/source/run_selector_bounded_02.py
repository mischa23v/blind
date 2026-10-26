"""Small serial selector wrapper, reusing the reviewed game process-tree watchdog."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1];WS=ROOT.parent
sys.path.insert(0,str(WS/'blind-koivu-game-07'))
from run_bounded import current_tree_usage,output_bytes,kill_group
CPU=60;WALL=90;RSS=512*1024**2;OUTPUT=8*1024**2;RESERVE=768*1024**2
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main(expected):
 frozen=ROOT/'SELECTION_FROZEN-02.json'
 if sha(frozen)!=expected:raise ValueError('manifest SHA mismatch')
 pins=json.loads(frozen.read_text())['files']
 def verify():
  if sha(frozen)!=expected or any(sha(WS/p)!=h for p,h in pins.items()):raise ValueError('source/input pin mismatch')
 out=ROOT/'selection-02';out.mkdir(exist_ok=False);child=None;failure=None;code=None;start=time.monotonic();cpu0=current_tree_usage(os.getpid())[1];peak=0;cpu=0
 try:
  if (ROOT/'FIRST_ROUTE.json').exists():raise FileExistsError('never overwrite selected route')
  if shutil.disk_usage(ROOT).free<RESERVE+OUTPUT:raise RuntimeError('reserve preflight')
  verify()
  def limits():
   resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU));resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
  env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
  with (out/'stdout.log').open('x')as so,(out/'stderr.log').open('x')as se:
   child=subprocess.Popen([sys.executable,str(ROOT/'source/select_first_route.py')],stdout=so,stderr=se,env=env,start_new_session=True,preexec_fn=limits)
   while child.poll()is None:
    current,spent=current_tree_usage(os.getpid());peak=max(peak,current);cpu=max(cpu,spent-cpu0)
    route_bytes=(ROOT/'FIRST_ROUTE.json').stat().st_size if (ROOT/'FIRST_ROUTE.json').exists() else 0
    if peak>RSS or cpu>CPU or time.monotonic()-start>WALL or output_bytes(out)+route_bytes>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:raise RuntimeError('selector sampled resource cap')
    time.sleep(.1)
   code=child.wait();kill_group(child)
  verify()
  if code!=0:raise RuntimeError('selector child failed')
 except BaseException as e:failure=repr(e)
 finally:
  if child is not None:kill_group(child);code=child.returncode
  current,spent=current_tree_usage(os.getpid());peak=max(peak,current,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024);cpu=max(cpu,spent-cpu0)
  if peak>RSS or cpu>CPU or time.monotonic()-start>WALL:failure='terminal selector resource cap'
  result={'success':code==0 and failure is None,'failure':failure,'exitCode':code,'frozenSHA256':expected,'wallSeconds':time.monotonic()-start,'sampledCPUSeconds':cpu,'peakSampledOrWaitedRSSBytes':peak,'sourceInputHashesVerifiedBeforeAndAfter':code==0 and failure is None,'physicalAuthority':False,'FAROUsed':False,'budgets':{'CPUSeconds':CPU,'wallSeconds':WALL,'RSSBytes':RSS,'outputBytes':OUTPUT,'freeReserveBytes':RESERVE},'sampledNotCgroup':True}
  (out/'RUN_RECEIPT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result))
 if not result['success']:raise SystemExit(1)
if __name__=='__main__':main(sys.argv[1])

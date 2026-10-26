"""Single small phone-only attribution run; no original files are written."""
from pathlib import Path
import hashlib,importlib.util,json,os,resource,shutil,signal,subprocess,sys,time
sys.dont_write_bytecode=True
HERE=Path(__file__).resolve().parent;WS=HERE.parents[2];OUT=HERE/'run-01'
CPU=30;WALL=45;RSS=256*1024**2;CAP=2*1024**2;RESERVE=768*1024**2
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 helper=WS/'blind-koivu-game-07/run_bounded.py'
 if sha(helper)!='1f695e6c927fba3cb20ee157e2f04cc74a71c1051937fc061ad2e956b6db7735':raise ValueError('watchdog pin')
 spec=importlib.util.spec_from_file_location('attribution_watchdog',helper);w=importlib.util.module_from_spec(spec);spec.loader.exec_module(w)
 if shutil.disk_usage(HERE).free<RESERVE+CAP:raise RuntimeError('reserve preflight')
 OUT.mkdir(exist_ok=False);pins={str(p):sha(p)for p in [Path(__file__),HERE/'attribute_failures.py',helper]}
 with (OUT/'SOURCE_PINS.json').open('x')as f:json.dump(pins,f,indent=2)
 start=time.monotonic();cpu0=w.current_tree_usage(os.getpid())[1];peak=0;cpu=0.;child=None;failure=None;code=None;verified=False
 def check():
  nonlocal peak,cpu
  current,spent=w.current_tree_usage(os.getpid());peak=max(peak,current);cpu=max(cpu,spent-cpu0)
  if peak>RSS or cpu>CPU or time.monotonic()-start>WALL or w.output_bytes(OUT)>CAP-65536 or shutil.disk_usage(HERE).free<RESERVE:raise RuntimeError('attribution resource cap')
 signal.signal(signal.SIGALRM,lambda *_:(_ for _ in()).throw(TimeoutError('45 second cap')));signal.alarm(WALL)
 try:
  def limits():
   resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU));resource.setrlimit(resource.RLIMIT_FSIZE,(CAP,CAP));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
  env=dict(os.environ);[env.pop(k,None)for k in ('LD_PRELOAD','LD_AUDIT','PYTHONPATH','PYTHONHOME')]
  env.update(OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1',PYTHONNOUSERSITE='1',PYTHONOPTIMIZE='0')
  with (OUT/'stdout.log').open('x')as so,(OUT/'stderr.log').open('x')as se:
   child=subprocess.Popen([sys.executable,str(HERE/'attribute_failures.py'),str(OUT/'RESULT.json')],cwd=HERE,stdout=so,stderr=se,env=env,start_new_session=True,preexec_fn=limits)
   while child.poll()is None:check();time.sleep(.05)
   code=child.wait();w.kill_group(child);child=None;check()
  if code:raise RuntimeError('attribution child failed')
  if any(sha(p)!=h for p,h in pins.items()):raise ValueError('source changed')
  verified=True
 except BaseException as e:failure=repr(e)
 finally:
  if child is not None:w.kill_group(child)
  signal.alarm(0)
  try:check()
  except BaseException as e:failure=failure or repr(e)
  peak=max(peak,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024)
  if peak>RSS:failure=failure or 'terminal RSS cap'
  result=dict(technicalExecutionCompleted=failure is None and verified,failure=failure,exitCode=code,
   sourcePinsVerifiedBeforeAfter=verified,wallSeconds=time.monotonic()-start,sampledCPUSeconds=cpu,peakSampledOrWaitedRSSBytes=peak,
   budgets=dict(CPUSeconds=CPU,wallSeconds=WALL,RSSBytes=RSS,outputBytes=CAP,freeReserveBytes=RESERVE),sampledNotCgroup=True,nativeRouteQueries=0,referenceInputsUsed=False,physicalAuthority=False)
  if verified:result['resultSHA256']=sha(OUT/'RESULT.json')
  data=(json.dumps(result,indent=2)+'\n').encode()
  if w.output_bytes(OUT)+len(data)>CAP or shutil.disk_usage(HERE).free-len(data)<RESERVE:raise RuntimeError('receipt cap')
  with (OUT/'RUN_RECEIPT.json').open('xb')as f:f.write(data)
  print(json.dumps(result),flush=True)
 if failure:raise SystemExit(1)
if __name__=='__main__':main()

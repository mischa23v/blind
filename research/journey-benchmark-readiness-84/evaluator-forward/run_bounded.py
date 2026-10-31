"""One serial process group; sampled aggregate CPU/RSS and bounded durable ledger."""
from pathlib import Path
import json,os,resource,signal,subprocess,sys,time,shutil
from runtime import H,sha,save,verify
CLK=os.sysconf('SC_CLK_TCK');PAGE=os.sysconf('SC_PAGE_SIZE')
def proc_group(group):
 cpu=0.;rss=0
 for p in Path('/proc').iterdir():
  if not p.name.isdigit():continue
  try:
   a=(p/'stat').read_text().rsplit(')',1)[1].split()
   if int(a[2])!=group:continue
   cpu+=sum(int(a[i])for i in(11,12,13,14))/CLK;rss+=int(a[21])*PAGE
  except(FileNotFoundError,ProcessLookupError,PermissionError):pass
 return cpu,rss

def size(path):return sum(p.stat().st_size for p in Path(path).rglob('*')if p.is_file())if Path(path).exists()else 0

def optional_json(path,cap):
 if not path.exists():return {},None
 try:
  if path.stat().st_size>cap:raise ValueError('JSON evidence exceeds byte cap')
  value=json.loads(path.read_text())
  if not isinstance(value,dict):raise ValueError('JSON evidence is not an object')
  return value,None
 except (OSError,ValueError)as e:return {},repr(e)

def terminal_motion_fields(result,started,mode):
 if result:return bool(result.get('motionExecuted',False)),result.get('actualDistanceMetres',0.)
 if not started or mode=='cache':return False,0.
 return None,None  # interrupted worker without terminal result is UNKNOWN, never zero

def main(expected,mode,index):
 if mode not in('parse','cache','episode'):raise ValueError('explicit bounded phase')
 verify(expected)
 if mode=='cache'and(H/'CACHE_MANIFEST.json').exists():raise ValueError('immutable cache cohort already frozen')
 m=json.loads((H/'MATRIX.json').read_text());limit=m['episodeLimits'if mode=='episode'else'cacheLimits'];assert 0<=index<(100 if mode=='episode'else 20 if mode=='cache'else 1)
 # Exclusive shared launch lock prevents simultaneous geometry workers.
 lock=H/'ACTIVE_RUN.lock';fd=os.open(lock,os.O_CREAT|os.O_EXCL|os.O_WRONLY,0o600);os.write(fd,f'{os.getpid()} {mode} {index}\n'.encode());os.close(fd)
 run=H/'runs'/f'{mode}-{index:03d}';child=None;failure=None;code=None;peak=0;cpu=0.;start=time.monotonic();self_start=resource.getrusage(resource.RUSAGE_SELF);usage_start=resource.getrusage(resource.RUSAGE_CHILDREN);sampled=[];output=None;started=False
 try:
  run.mkdir(parents=True,exist_ok=False)
  available=int(next(x.split()[1]for x in Path('/proc/meminfo').read_text().splitlines()if x.startswith('MemAvailable:')))*1024
  if available<m['minimumAvailableRAMBytes']:raise RuntimeError('4.3GiB available RAM admission failed')
  if shutil.disk_usage(H).free<768*1024**2+limit['outputBytes']:raise RuntimeError('disk reserve admission failed')
  initial_stage=size(H.parent)
  if initial_stage+limit['outputBytes']>m['stageDiskCapBytes']:raise RuntimeError('4GiB total stage disk admission failed')
  save(run/'PREFLIGHT.json',{'availableRAMBytes':available,'minimumBytes':m['minimumAvailableRAMBytes'],'sampledNotReservation':True,'stageBytes':initial_stage,'limits':limit})
  target=H/({'parse':'parse_reference.py','cache':'prepare_cache.py','episode':'run_episode.py'}[mode]);cmd=[sys.executable,str(target),expected]+([]if mode=='parse'else[str(index)])
  output=(H/'caches'/f'pair-{index:02d}'if mode=='cache'else H/'episodes'/f'episode-{index:03d}'if mode=='episode'else H/'REFERENCE_PARSE_RESULT.json')
  def limits():
   resource.setrlimit(resource.RLIMIT_CPU,(limit['CPUSeconds'],limit['CPUSeconds']));resource.setrlimit(resource.RLIMIT_AS,(limit['RSSBytes'],limit['RSSBytes']));resource.setrlimit(resource.RLIMIT_FSIZE,(limit['outputBytes'],limit['outputBytes']));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
  env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',VTK_SMP_IMPLEMENTATION_TYPE='Sequential',VTK_SMP_MAX_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
  with (run/'stdout.log').open('x')as so,(run/'stderr.log').open('x')as se,(run/'HEARTBEAT.jsonl').open('x')as hb:
   child=subprocess.Popen(cmd,stdout=so,stderr=se,env=env,start_new_session=True,preexec_fn=limits);started=True
   if mode in('cache','episode'):
    lp=H/('CACHE_LEDGER.json'if mode=='cache'else'EPISODE_LEDGER.json');lr=json.loads(lp.read_text());lr[index].update(status='running',processStarted=True,movementExecuted=None,actualDistanceMetres=None);save(lp.with_suffix('.tmp'),lr);os.replace(lp.with_suffix('.tmp'),lp)
   while child.poll()is None:
    spent,rss=proc_group(child.pid);self_now=resource.getrusage(resource.RUSAGE_SELF);cpu=max(cpu,spent+self_now.ru_utime+self_now.ru_stime-self_start.ru_utime-self_start.ru_stime);rss+=int(Path('/proc/self/stat').read_text().rsplit(')',1)[1].split()[21])*PAGE;peak=max(peak,rss);wall=time.monotonic()-start
    hb.write(json.dumps({'wallSeconds':wall,'aggregateCPUSeconds':cpu,'treeRSSBytes':rss,'peakTreeRSSBytes':peak})+'\n');hb.flush()
    output_size=(output.stat().st_size if output.is_file()else size(output))+size(run)
    if cpu>limit['CPUSeconds']or wall>limit['wallSeconds']or peak>limit['RSSBytes']or output_size>limit['outputBytes']-65536 or shutil.disk_usage(H).free<768*1024**2 or size(H.parent)>m['stageDiskCapBytes']:raise RuntimeError('aggregate resource/output/disk budget reached')
    time.sleep(.1)
   code=child.wait()
  if code!=0:raise RuntimeError('worker failed; retain logs and partial traces')
  verify(expected)
 except BaseException as e:failure=repr(e)
 finally:
  if child is not None:
   try:os.killpg(child.pid,signal.SIGKILL)
   except ProcessLookupError:pass
   child.wait();code=child.returncode
  try:
   u=resource.getrusage(resource.RUSAGE_CHILDREN);self_now=resource.getrusage(resource.RUSAGE_SELF);terminal_cpu=u.ru_utime+u.ru_stime-usage_start.ru_utime-usage_start.ru_stime+self_now.ru_utime+self_now.ru_stime-self_start.ru_utime-self_start.ru_stime;cpu=max(cpu,terminal_cpu);peak=max(peak,u.ru_maxrss*1024);wall=time.monotonic()-start
   if cpu>limit['CPUSeconds']or wall>limit['wallSeconds']or peak>limit['RSSBytes']:failure=failure or'terminal resource budget exceeded'
   terminal_output=((output.stat().st_size if output.is_file()else size(output))if output is not None else 0)+size(run)
   if terminal_output>limit['outputBytes']-65536 or shutil.disk_usage(H).free<768*1024**2 or size(H.parent)>m['stageDiskCapBytes']:failure=failure or'terminal output/disk budget exceeded'
   receipt={'processStarted':started,'terminalOutputBytes':terminal_output,'processCompleted':code==0 and failure is None,'failure':failure,'exitCode':code,'mode':mode,'index':index,'CPUSeconds':cpu,'wallSeconds':wall,'peakSampledTreeOrWaitRSSBytes':peak,'limits':limit,'sampledNotCgroup':True,'processGroupKilledAtEnd':child is not None,'evaluatorManifestSHA256':expected,'physicalAuthority':False}
   if run.exists():save(run/'RUN_RECEIPT.json',receipt)
   if mode in('cache','episode'):
    ledgerpath=H/('CACHE_LEDGER.json'if mode=='cache'else'EPISODE_LEDGER.json');rows=json.loads(ledgerpath.read_text());resultpath=(H/'caches'/f'pair-{index:02d}'/'RESULT.json'if mode=='cache'else H/'episodes'/f'episode-{index:03d}'/'result/RESULT.json')
    result,result_parse_error=optional_json(resultpath,limit['outputBytes']);partial=resultpath.parent/'LIVE_PROGRESS.json';trace=resultpath.parent/'ACTUAL_TRACE_PARTIAL.csv';progress,progress_parse_error=optional_json(partial,limit['outputBytes'])
    movement,distance=terminal_motion_fields(result,started,mode)
    rows[index].update(status=result.get('status','computeUnavailable')if receipt['processCompleted']else'computeBudgetOrInfrastructureFailure',processStarted=started,processCompleted=receipt['processCompleted'],movementExecuted=movement,actualDistanceMetres=distance,arrival=bool(result.get('arrival',False))and receipt['processCompleted'],partialProgress=progress or None,terminalResultParseError=result_parse_error,partialProgressParseError=progress_parse_error,partialTracePath=str(trace.relative_to(H))if trace.exists()else None,partialProgressNotTerminal=True if progress and not result else False,receipt=str((run/'RUN_RECEIPT.json').relative_to(H)),resultPath=str(resultpath.relative_to(H))if resultpath.exists()else None,failure=failure)
    tmp=ledgerpath.with_suffix('.tmp');save(tmp,rows);os.replace(tmp,ledgerpath)
  finally:lock.unlink(missing_ok=True)
  print(json.dumps(receipt),flush=True)
 if not receipt['processCompleted']:raise SystemExit(1)
if __name__=='__main__':main(sys.argv[1],sys.argv[2],int(sys.argv[3]))

"""One explicitly admitted arm; budget includes monitor/prechecks/final checks."""
import time,resource
start=time.monotonic()
def self_cpu():
 usage=resource.getrusage(resource.RUSAGE_SELF)
 return usage.ru_utime+usage.ru_stime
from pathlib import Path
import subprocess,os,signal,json,sys,fcntl
from verify_inputs import admission,source_check,ARMS
H=Path(__file__).resolve().parent
arm=sys.argv[1];assert arm in ARMS;D=H/arm
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
# Fail before starting a worker unless root has bound the reviewed final outputs.
source_check();admission(arm)
import psutil
monitor=psutil.Process(os.getpid())
lock=(H/'scoring.lock').open('a')
fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
assert not (D/'evaluation').exists() and not (D/'RESOURCE.json').exists()
peak=monitor.memory_info().rss;cpupeak=self_cpu();reason=None;known={}
assert time.monotonic()-start<=90 and cpupeak<=60 and peak<=1024**3,'prelaunch_budget_exceeded'
env=dict(os.environ);env.pop('PYTHONPATH',None)
env.update(PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',NUMEXPR_NUM_THREADS='1')
with (D/'guard.stdout').open('x')as out,(D/'guard.stderr').open('x')as err:
 p=subprocess.Popen([sys.executable,str(H/'execute_score.py'),arm],stdout=out,stderr=err,env=env,start_new_session=True);root=psutil.Process(p.pid)
 try:
  while p.poll()is None:
   rss=monitor.memory_info().rss;cpu=self_cpu()
   try:procs=[root]+root.children(recursive=True)
   except psutil.NoSuchProcess:procs=[]
   for proc in procs:
    try:
     known[(proc.pid,proc.create_time())]=proc;rss+=proc.memory_info().rss;t=proc.cpu_times()
     cpu+=t.user+t.system+getattr(t,'children_user',0)+getattr(t,'children_system',0)
    except psutil.NoSuchProcess:continue
   peak=max(peak,rss);cpupeak=max(cpupeak,cpu)
   disk=sum(f.stat().st_size for f in D.rglob('*')if f.is_file())
   if rss>1024**3:reason='rss_1GiB'
   if cpu>60:reason='cpu_60s'
   if time.monotonic()-start>90:reason='wall_90s'
   if disk>1024**3:reason='disk_1GiB'
   if reason:
    try:os.killpg(p.pid,signal.SIGTERM)
    except ProcessLookupError:pass
    try:p.wait(timeout=.5)
    except subprocess.TimeoutExpired:
     try:os.killpg(p.pid,signal.SIGKILL)
     except ProcessLookupError:pass
    break
   time.sleep(.1)
  code=p.wait()
 finally:
  for (pid,ct),proc in known.items():
   try:
    if proc.is_running()and proc.create_time()==ct:proc.kill()
   except psutil.Error:pass
  try:os.killpg(p.pid,signal.SIGKILL)
  except ProcessLookupError:pass
disk=sum(f.stat().st_size for f in D.rglob('*')if f.is_file())
peak=max(peak,monitor.memory_info().rss)
child=resource.getrusage(resource.RUSAGE_CHILDREN)
final_cpu=child.ru_utime+child.ru_stime+self_cpu();wall=time.monotonic()-start
cpupeak=max(cpupeak,final_cpu)
if final_cpu>60 or wall>90 or peak>1024**3 or disk>1024**3:
 reason=reason or 'final_guard_budget_cap'
receipt={'arm':arm,'exitCode':code,'stopReason':reason,'wallSeconds':wall,'peakSummedRSSBytes':peak,'peakCumulativeCPUSeconds':cpupeak,'finalActualChildPlusGuardCPUSeconds':final_cpu,'monitorAndPrechecksIncluded':True,'samplingSeconds':.1,'caps':{'cpuSeconds':60,'wallSeconds':90,'RSSBytes':1024**3,'diskBytes':1024**3,'logicalCPUs':1},'scope':'immutable source/output/cache checks + primary heldout score + original summary + frozen secondary common-pair analysis; no mapping','partialOutputsAdmissible':False}
(D/'RESOURCE.json').write_text(json.dumps(receipt,indent=2)+'\n')
print(json.dumps(receipt));sys.exit(0 if code==0 and not reason else 1)

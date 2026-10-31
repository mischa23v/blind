"""One CPU/2GiB/300 CPU-s/420 wall-s/512MiB disk guard; no retries or scope expansion."""
from pathlib import Path
import subprocess,psutil,time,os,signal,json,sys,hashlib,resource
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
initial_self=resource.getrusage(resource.RUSAGE_SELF)
def self_cpu():
 r=resource.getrusage(resource.RUSAGE_SELF);return r.ru_utime+r.ru_stime-initial_self.ru_utime-initial_self.ru_stime
H=Path(__file__).resolve().parent;start=time.monotonic();peak=0;cpupeak=0;reason=None;known={}
with (H/'guard.stdout').open('x')as out,(H/'guard.stderr').open('x')as err:
 p=subprocess.Popen([sys.executable,str(H/'execute.py')],stdout=out,stderr=err,start_new_session=True);root=psutil.Process(p.pid)
 try:
  while p.poll()is None:
   rss=psutil.Process(os.getpid()).memory_info().rss;cpu=0
   try:procs=[root]+root.children(recursive=True)
   except psutil.NoSuchProcess:procs=[]
   for x in procs:
    try:
     known[(x.pid,x.create_time())]=x;rss+=x.memory_info().rss;t=x.cpu_times();cpu+=t.user+t.system+getattr(t,'children_user',0)+getattr(t,'children_system',0)
    except psutil.NoSuchProcess:continue
   cpu+=self_cpu();peak=max(peak,rss);cpupeak=max(cpupeak,cpu)
   disk=sum(f.stat().st_size for f in H.rglob('*')if f.is_file())
   if rss>2*1024**3:reason='rss_2GiB'
   if cpu>300:reason='cpu_300s'
   if time.monotonic()-start>420:reason='wall_420s'
   if disk>512*1024**2:reason='disk_512MiB'
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
  for (pid,ct),x in known.items():
   try:
    if x.is_running()and x.create_time()==ct:x.kill()
   except psutil.Error:pass
  try:os.killpg(p.pid,signal.SIGKILL)
  except ProcessLookupError:pass
receipt={'exitCode':code,'stopReason':reason,'wallSeconds':time.monotonic()-start,'peakSummedRSSBytes':peak,'peakCumulativeCPUSeconds':cpupeak,'samplingSeconds':.1,'caps':{'cpuSeconds':300,'wallSeconds':420,'RSSBytes':2*1024**3,'diskBytes':512*1024**2,'logicalCPUs':1},'scope':'All original265 training frames D1+N2 B/C0/C1 fusion and native meshes; no accuracy/reference/GT inputs'}
frozen=json.loads((H/'EXECUTION_FREEZE.json').read_text())['files']
changed=[p for p,h in frozen.items() if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
(H/'POST_RUN_INTEGRITY.json').write_text(json.dumps({'checked':len(frozen),'changedOrMissing':changed,'passed':not changed},indent=2)+'\n')
receipt['frozenIntegrityPassed']=not changed
child=resource.getrusage(resource.RUSAGE_CHILDREN)
receipt['finalActualChildPlusGuardCPUSeconds']=child.ru_utime+child.ru_stime+self_cpu()
receipt['wallSeconds']=time.monotonic()-start
if receipt['finalActualChildPlusGuardCPUSeconds']>300 or receipt['wallSeconds']>420:
 reason=reason or 'final_guard_or_integrity_budget_cap';receipt['stopReason']=reason
(H/'OUTPUT_ADMISSION.json').write_text(json.dumps({'admittedForSubsequentReview':code==0 and not reason and not changed,'partialOutputsQuarantined':not(code==0 and not reason and not changed),'accuracyEvaluated':False,'scoringRequiresSeparateAdmission':True},indent=2)+'\n')
(H/'RESOURCE.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt));sys.exit(0 if code==0 and not reason and not changed else 1)

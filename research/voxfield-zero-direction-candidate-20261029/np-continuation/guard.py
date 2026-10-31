"""One CPU/2GiB/30 CPU-s/45 wall-s/32MiB disk guard; no retries or scope expansion."""
from pathlib import Path
import subprocess,psutil,time,os,signal,json,sys,hashlib
H=Path(__file__).resolve().parent;start=time.monotonic();peak=0;cpupeak=0;reason=None;known={}
with (H/'guard.stdout').open('x')as out,(H/'guard.stderr').open('x')as err:
 p=subprocess.Popen([sys.executable,str(H/'execute.py')],stdout=out,stderr=err,start_new_session=True);root=psutil.Process(p.pid)
 try:
  while p.poll()is None:
   rss=cpu=0
   try:procs=[root]+root.children(recursive=True)
   except psutil.NoSuchProcess:procs=[]
   for x in procs:
    try:
     known[(x.pid,x.create_time())]=x;rss+=x.memory_info().rss;t=x.cpu_times();cpu+=t.user+t.system+getattr(t,'children_user',0)+getattr(t,'children_system',0)
    except psutil.NoSuchProcess:continue
   peak=max(peak,rss);cpupeak=max(cpupeak,cpu)
   disk=sum(f.stat().st_size for f in H.rglob('*')if f.is_file())
   if rss>2*1024**3:reason='rss_2GiB'
   if cpu>30:reason='cpu_30s'
   if time.monotonic()-start>45:reason='wall_45s'
   if disk>32*1024**2:reason='disk_32MiB'
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
receipt={'exitCode':code,'stopReason':reason,'wallSeconds':time.monotonic()-start,'peakSummedRSSBytes':peak,'peakCumulativeCPUSeconds':cpupeak,'samplingSeconds':.1,'caps':{'cpuSeconds':30,'wallSeconds':45,'RSSBytes':2*1024**3,'diskBytes':32*1024**2,'logicalCPUs':1},'scope':'Unchanged original NP synthetic fixture linked to existing D1 core; no recorded inputs'}
frozen=json.loads((H/'EXECUTION_FREEZE.json').read_text())['files']
changed=[p for p,h in frozen.items() if not Path(p).is_file() or hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h]
(H/'POST_RUN_INTEGRITY.json').write_text(json.dumps({'checked':len(frozen),'changedOrMissing':changed,'passed':not changed},indent=2)+'\n')
receipt['frozenIntegrityPassed']=not changed
(H/'RESOURCE.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt));sys.exit(0 if code==0 and not reason and not changed else 1)

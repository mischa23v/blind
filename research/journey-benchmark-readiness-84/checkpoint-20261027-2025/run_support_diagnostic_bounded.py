from pathlib import Path
import sys,os,json,time,subprocess,resource,signal,shutil
B=Path(__file__).resolve().parents[1];H=B/'evaluator-forward-recovery-02';sys.path.insert(0,str(H));from run_bounded import proc_group,size
assert not (H/'ACTIVE_RUN.lock').exists();assert json.loads((H/'EPISODE_LEDGER.json').read_text())[19]['processCompleted'];m=json.loads((H/'MATRIX.json').read_text());limit=m['cacheLimits'];out=H/'reviews/support-diagnostic-run';out.mkdir(exist_ok=False)
available=int(next(x.split()[1] for x in Path('/proc/meminfo').read_text().splitlines() if x.startswith('MemAvailable:')))*1024;assert available>=m['minimumAvailableRAMBytes'];assert size(B)+limit['outputBytes']<m['stageDiskCapBytes'];assert shutil.disk_usage(B).free>768*1024**2+limit['outputBytes']
def limits():
 resource.setrlimit(resource.RLIMIT_CPU,(limit['CPUSeconds'],limit['CPUSeconds']));resource.setrlimit(resource.RLIMIT_AS,(limit['RSSBytes'],limit['RSSBytes']));resource.setrlimit(resource.RLIMIT_FSIZE,(limit['outputBytes'],limit['outputBytes']));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
watches=json.loads((H/'RECOVERY02_PREFLIGHT.json').read_text())['watches']
def check_previous():
 for root, entries in watches.items():
  for n,x in entries.items():
   st=(Path(root)/n).stat();assert st.st_size==x['bytes'] and st.st_mtime_ns==x['mtimeNs'],'previous producer resumed'
check_previous()
p=None;fail=None;start=time.monotonic();peak=0;cpu=0
try:
 with (out/'stdout.log').open('x') as so,(out/'stderr.log').open('x') as se:
  p=subprocess.Popen([sys.executable,str(B/'recovery-tools/diagnose_support_stops.py')],stdout=so,stderr=se,start_new_session=True,preexec_fn=limits,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
  while p.poll() is None:
   check_previous();cpu,rss=proc_group(p.pid);peak=max(peak,rss);wall=time.monotonic()-start
   if cpu>limit['CPUSeconds'] or peak>limit['RSSBytes'] or wall>limit['wallSeconds'] or size(out)>limit['outputBytes'] or size(B)>m['stageDiskCapBytes'] or shutil.disk_usage(B).free<768*1024**2:raise RuntimeError('bounded diagnostic resource limit')
   time.sleep(.2)
  if p.returncode!=0:raise RuntimeError('diagnostic failed')
except BaseException as e:fail=repr(e)
finally:
 if p is not None:
  try:os.killpg(p.pid,signal.SIGKILL)
  except ProcessLookupError:pass
  p.wait()
 r={'completed':fail is None,'failure':fail,'exitCode':p.returncode if p else None,'wallSeconds':time.monotonic()-start,'sampledCPUSeconds':cpu,'peakSampledRSSBytes':peak,'limits':limit,'noActorReplay':True,'physicalAuthority':False};(out/'RUN_RECEIPT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r))
if fail:raise SystemExit(1)

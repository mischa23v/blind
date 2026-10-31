import os,sys,time,json,subprocess,signal,datetime
from pathlib import Path
H=Path(__file__).resolve().parent
label=sys.argv[1];cmd=sys.argv[2:];deadline=datetime.datetime(2026,10,28,18,29,tzinfo=datetime.timezone.utc).timestamp()
env=os.environ.copy();env.update(LD_LIBRARY_PATH=str(H/'prefix/usr/lib/x86_64-linux-gnu')+':'+str(H/'prefix/usr/lib')+':'+str(H/'build/bin'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',TBB_NUM_THREADS='1')
cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu});f=(H/'logs'/f'{label}.log').open('w');p=subprocess.Popen(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True);peak=0;start=time.time();reason=None;samples=[]
while p.poll() is None:
 rss=0
 for proc in Path('/proc').glob('[0-9]*'):
  try:
   stat=(proc/'stat').read_text().split();pgid=int(stat[4]);
   if pgid==p.pid:rss+=int(stat[23])*os.sysconf('SC_PAGE_SIZE')
  except (OSError,ValueError,IndexError):pass
 disk=int(subprocess.check_output(['du','-sb',str(H)]).split()[0]);peak=max(peak,rss);samples.append({'elapsed':time.time()-start,'rss':rss,'disk':disk})
 if rss>3*1024**3:reason='RSS_3GiB'
 if disk>6*1024**3:reason='disk_6GiB'
 if time.time()>deadline:reason='stage_deadline'
 if reason:os.killpg(p.pid,signal.SIGTERM);break
 time.sleep(2)
try:rc=p.wait(timeout=10)
except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);rc=p.wait()
f.close();result={'command':cmd,'cpuAffinity':[cpu],'returncode':rc,'stopReason':reason,'peakSampledTreeRSS':peak,'elapsedSeconds':time.time()-start,'samples':samples};(H/'logs'/f'{label}_RESOURCE.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='samples'}));sys.exit(rc if rc>=0 else 1)

import os,sys,time,json,subprocess,signal,datetime,resource
from pathlib import Path
S=Path(__file__).resolve().parent;H=S.parent;limits=json.loads((S/'STAGE_LIMITS.json').read_text());deadline=datetime.datetime.fromisoformat(limits['deadlineUTC']).timestamp()
label=sys.argv[1];cmd=sys.argv[2:];assert not(S/'logs'/f'{label}_RESOURCE.json').exists()
previous=sum(json.loads(p.read_text()).get('childCPUSeconds',0)for p in(S/'logs').glob('*_RESOURCE.json'))
env=os.environ.copy();env.update(LD_LIBRARY_PATH=str(H/'prefix/usr/lib/x86_64-linux-gnu')+':'+str(H/'prefix/usr/lib')+':'+str(S/'build/bin'),OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',TBB_NUM_THREADS='1')
cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu});f=(S/'logs'/f'{label}.log').open('w');p=subprocess.Popen(cmd,env=env,stdout=f,stderr=subprocess.STDOUT,start_new_session=True);peak=0;start=time.time();reason=None;samples=[];ticks=os.sysconf('SC_CLK_TCK')
while p.poll() is None:
 rss=0;cpu_now=0
 for proc in Path('/proc').glob('[0-9]*'):
  try:
   raw=(proc/'stat').read_text();stat=raw[raw.rfind(')')+2:].split();pgid=int(stat[2])
   if pgid==p.pid:rss+=int(stat[21])*os.sysconf('SC_PAGE_SIZE');cpu_now+=sum(float(stat[i])for i in [11,12,13,14])/ticks
  except (OSError,ValueError,IndexError):pass
 disk=int(subprocess.check_output(['du','-sb',str(H.parent)]).split()[0]);peak=max(peak,rss);samples.append({'elapsed':time.time()-start,'rss':rss,'aggregateDisk':disk,'processGroupCPUSecondsIncludingReaped':cpu_now})
 if rss>limits['maxSampledTreeRSSBytes']:reason='RSS_3GiB'
 if disk>limits['aggregateDiskBytes']:reason='aggregate_disk_6GiB'
 if previous+cpu_now>limits['maxStageCPUSeconds']:reason='stage_cpu_35min'
 if time.time()>deadline:reason='stage_wall_40min'
 if reason:os.killpg(p.pid,signal.SIGTERM);break
 time.sleep(2)
try:rc=p.wait(timeout=10)
except subprocess.TimeoutExpired:os.killpg(p.pid,signal.SIGKILL);rc=p.wait()
f.close();u=resource.getrusage(resource.RUSAGE_CHILDREN);result={'command':cmd,'cpuAffinity':[cpu],'returncode':rc,'stopReason':reason,'peakSampledTreeRSS':peak,'elapsedSeconds':time.time()-start,'childCPUSeconds':u.ru_utime+u.ru_stime,'priorStageCPUSeconds':previous,'samples':samples};(S/'logs'/f'{label}_RESOURCE.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k!='samples'}));sys.exit(rc if rc>=0 else 1)

"""Bounded serial build + unchanged 12-fixture wrapper smoke. No recorded routes."""
from pathlib import Path
import hashlib,json,os,resource,signal,subprocess,sys,time
H=Path(__file__).resolve().parent
assert not (H/'SMOKE_RESULT.json').exists(), 'preserve original attempt'
cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
env=os.environ.copy();env.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',TBB_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
cap=1024**3;begin=time.monotonic();ticks=os.sysconf('SC_CLK_TCK');pages=os.sysconf('SC_PAGE_SIZE')
def limits():
 resource.setrlimit(resource.RLIMIT_AS,(cap,cap));resource.setrlimit(resource.RLIMIT_CPU,(300,300));resource.setrlimit(resource.RLIMIT_FSIZE,(256*1024**2,256*1024**2))
def run(label,cmd):
 start=time.monotonic();samples=[];peak=0;reason=None
 with (H/(label+'.log')).open('x') as log:
  p=subprocess.Popen(cmd,cwd=H,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True,preexec_fn=limits)
  try:
   while p.poll() is None:
    rss=0;proc_cpu=0.
    for f in Path('/proc').glob('[0-9]*/stat'):
     try:
      raw=f.read_text();s=raw[raw.rfind(')')+2:].split()
      if int(s[2])==p.pid:rss+=int(s[21])*pages;proc_cpu+=sum(float(s[i])for i in [11,12,13,14])/ticks
     except (OSError,ValueError,IndexError):pass
    own=resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024
    peak=max(peak,rss+own);disk=sum(f.stat().st_size for f in H.rglob('*') if f.is_file())
    samples.append({'elapsed':time.monotonic()-start,'processTreeRSS':rss,'wrapperPeakRSS':own,'processGroupCPUSecondsIncludingReaped':proc_cpu,'stageDiskBytes':disk})
    if rss+own>cap:reason='sampledAggregateRSSExceeded'
    if disk>cap:reason='stageDiskExceeded'
    if time.monotonic()-begin>300:reason='totalWallExceeded'
    if reason:os.killpg(p.pid,signal.SIGKILL);break
    time.sleep(.1)
   rc=p.wait(timeout=5)
  finally:
   if p.poll() is None:os.killpg(p.pid,signal.SIGKILL);p.wait()
 result={'command':cmd,'returncode':rc,'stopReason':reason,'elapsedSeconds':time.monotonic()-start,'peakSampledAggregateRSSBytes':peak,'cpuAffinity':[cpu],'samples':samples}
 (H/(label+'_RESOURCE.json')).write_text(json.dumps(result,indent=2)+'\n')
 print(json.dumps({k:v for k,v in result.items() if k!='samples'}),flush=True)
 return result
sources=[str(p.relative_to(H)) for part in ('Recast','Detour','DetourCrowd') for p in sorted((H/'native'/'upstream'/part/'Source').glob('*.cpp'))]
cmd=['g++','-std=c++11','-O1','-ffp-contract=off','-fPIC','-shared','-fno-rtti','-fno-exceptions','-Wall','-Wextra']+['-Inative/upstream/'+part+'/Include' for part in ('Recast','Detour','DetourCrowd')]+sources+['native/clearance_adapter.cpp','-o','libblind_detour.so']
build=run('build',cmd);test=None
if build['returncode']==0 and build['stopReason'] is None:test=run('wrapper-tests',[sys.executable,'-m','unittest','-v','test_detour_engine'])
u=resource.getrusage(resource.RUSAGE_CHILDREN)
result={'buildPassed':build['returncode']==0 and build['stopReason'] is None,'wrapperTestsPassed':test is not None and test['returncode']==0 and test['stopReason'] is None,'testCount':12 if test is not None else None,'childCPUSeconds':u.ru_utime+u.ru_stime,'wallSeconds':time.monotonic()-begin,'maxSampledAggregateRSSBytes':max(x['peakSampledAggregateRSSBytes']for x in [build,test]if x),'stageDiskBytes':sum(f.stat().st_size for f in H.rglob('*')if f.is_file()),'bounds':{'cpuAffinity':[cpu],'RSSBytes':cap,'diskBytes':cap,'wallSeconds':300},'librarySHA256':hashlib.sha256((H/'libblind_detour.so').read_bytes()).hexdigest()if(H/'libblind_detour.so').exists()else None,'recordedRoutesExecuted':0,'physicalAuthority':False}
(H/'SMOKE_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
sys.exit(0 if result['buildPassed']and result['wrapperTestsPassed']else 1)

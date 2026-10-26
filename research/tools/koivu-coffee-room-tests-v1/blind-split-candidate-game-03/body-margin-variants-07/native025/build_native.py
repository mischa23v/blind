from pathlib import Path
import hashlib,json,os,resource,subprocess,sys,time,shutil
HERE=Path(__file__).resolve().parent;WS=HERE.parents[2]
sys.path.insert(0,str(WS/'blind-koivu-game-07'))
from run_bounded import current_tree_usage,output_bytes,kill_group
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def main():
 assert not(HERE/'libblind_detour.so').exists()
 if shutil.disk_usage(HERE).free<768*1024**2+50*1024**2:raise RuntimeError('disk reserve')
 files=[*sorted((HERE/'upstream/Recast/Source').glob('*.cpp')),*sorted((HERE/'upstream/Detour/Source').glob('*.cpp')),*sorted((HERE/'upstream/DetourCrowd/Source').glob('*.cpp')),HERE/'blind_detour.cpp']
 pins={str(p.relative_to(HERE)):sha(p)for p in [*files,*sorted((HERE/'upstream').rglob('*.h')),HERE/'blind_detour.h']}
 cmd=['g++','-std=c++11','-O1','-fPIC','-shared','-fno-rtti','-fno-exceptions','-Wall','-Wextra',*[f'-I{HERE}/upstream/{x}/Include'for x in ['Recast','Detour','DetourCrowd']],*map(str,files),'-o',str(HERE/'libblind_detour.so.pending')]
 start=time.monotonic();cpu0=current_tree_usage(os.getpid())[1];peak=0;cpu=0;failure=None;p=None;code=None
 def limits():
  resource.setrlimit(resource.RLIMIT_CPU,(600,600));resource.setrlimit(resource.RLIMIT_FSIZE,(50*1024**2,50*1024**2));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 try:
  with (HERE/'build.stdout.log').open('x')as out,(HERE/'build.stderr.log').open('x')as err:
   p=subprocess.Popen(cmd,stdout=out,stderr=err,start_new_session=True,preexec_fn=limits)
   while p.poll()is None:
    rss,spent=current_tree_usage(os.getpid());peak=max(peak,rss);cpu=max(cpu,spent-cpu0)
    if peak>1024**3 or cpu>600 or time.monotonic()-start>900 or output_bytes(HERE)>50*1024**2 or shutil.disk_usage(HERE).free<768*1024**2:raise RuntimeError('bounded serial build cap')
    time.sleep(.2)
   code=p.wait()
  if code!=0:raise RuntimeError('compiler failure')
  for name,h in pins.items():assert sha(HERE/name)==h
  (HERE/'libblind_detour.so.pending').rename(HERE/'libblind_detour.so')
 except BaseException as e:failure=repr(e)
 finally:
  if p:kill_group(p)
  peak=max(peak,resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024)
  r={'success':failure is None,'failure':failure,'exitCode':code,'serialCommand':cmd,'sourcePins':pins,'wallSeconds':time.monotonic()-start,'sampledCPUSeconds':cpu,'peakSampledOrWaitedRSSBytes':peak,'sourcePinsVerifiedAfter':failure is None,'librarySHA256':sha(HERE/'libblind_detour.so')if failure is None else None,'compiler':subprocess.check_output(['g++','--version'],text=True).splitlines()[0],'workBytes':output_bytes(HERE),'physicalAuthority':False}
  (HERE/'BUILD_RECEIPT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps({k:v for k,v in r.items()if k not in ['sourcePins','serialCommand']}))
 if failure:raise SystemExit(1)
if __name__=='__main__':main()

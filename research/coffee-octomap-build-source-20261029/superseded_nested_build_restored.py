from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,time,traceback
ROOT=Path(__file__).resolve().parent;RESERVE=768*1024**2;WORK=50*1024**2;MAXRSS=1024**3

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def total():return sum(p.stat().st_size for p in ROOT.rglob('*')if p.is_file())
def limits():
 os.setsid()
 resource.setrlimit(resource.RLIMIT_CPU,(120,120))
 resource.setrlimit(resource.RLIMIT_AS,(1024**3,)*2)
def main():
 assert sha(ROOT/'octomap_adapter.cpp')=='715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7'
 receipt=json.loads((ROOT/'ACQUISITION_RECEIPT.json').read_text());assert receipt['success'] and receipt['sourceBytesTransferred']==380478
 for r in receipt['files']:assert sha(ROOT/'sources'/r['path'])==r['sha256']
 out=ROOT/'build-restored-01';out.mkdir(exist_ok=False);before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic();peak=0;failure=None;p=None;code=None
 cpp=sorted((ROOT/'sources/octomap/src').glob('*.cpp'))+sorted((ROOT/'sources/octomap/src/math').glob('*.cpp'));assert len(cpp)==12
 command=['g++','-std=c++17','-O2','-DNDEBUG','-fPIC','-shared','-I'+str(ROOT/'sources/octomap/include'),*[str(p)for p in cpp],str(ROOT/'octomap_adapter.cpp'),'-o',str(out/'libblind_octomap.so')]
 pins={str(p.relative_to(ROOT)):sha(p) for p in [ROOT/'octomap_adapter.cpp',Path(__file__),ROOT/'SOURCE_SELECTION.json',ROOT/'ACQUISITION_RECEIPT.json']}
 try:
  with (out/'stdout.log').open('x')as so,(out/'stderr.log').open('x')as se,(out/'heartbeat.jsonl').open('x')as hb:
   p=subprocess.Popen(command,stdout=so,stderr=se,preexec_fn=limits)
   while p.poll()is None:
    # g++ launches one compiler subprocess at a time. Inspect all descendants in this namespace.
    parent={};stats={}
    for entry in Path('/proc').iterdir():
     if not entry.name.isdigit():continue
     try:
      raw=(entry/'stat').read_text().split(') ',1)[1].split();pid=int(entry.name);parent[pid]=int(raw[1]);stats[pid]=((int(raw[11])+int(raw[12])+int(raw[13])+int(raw[14]))/os.sysconf('SC_CLK_TCK'),int(raw[21])*os.sysconf('SC_PAGE_SIZE'))
     except (FileNotFoundError,ProcessLookupError,PermissionError):pass
    selected={p.pid};changed=True
    while changed:
     more={pid for pid,ppid in parent.items()if ppid in selected};changed=not more.issubset(selected);selected|=more
    cpu_live=sum(stats.get(pid,(0,0))[0]for pid in selected);rss=sum(stats.get(pid,(0,0))[1]for pid in selected);peak=max(peak,rss);row={'wallSeconds':time.monotonic()-start,'treeRSSBytes':rss,'liveAndWaitedTreeCPUSeconds':cpu_live,'peakTreeRSSBytes':peak,'workBytes':total(),'freeBytes':shutil.disk_usage(ROOT).free};hb.write(json.dumps(row)+'\n');hb.flush()
    if cpu_live>120 or row['wallSeconds']>180 or rss>MAXRSS or row['workBytes']>WORK-65536 or row['freeBytes']<RESERVE+65536:
     failure={'budgetViolation':row}
     try:os.killpg(p.pid,9)
     except ProcessLookupError:pass
     break
    time.sleep(.2)
   code=p.wait()
 except BaseException as e:
  failure={'exception':repr(e),'traceback':traceback.format_exc()}
 finally:
  if p is not None and p.poll()is None:
   try:os.killpg(p.pid,9)
   except ProcessLookupError:pass
   code=p.wait()
  after=resource.getrusage(resource.RUSAGE_CHILDREN);cpu=after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime;peak=max(peak,int(after.ru_maxrss)*1024);wall=time.monotonic()-start
  if cpu>120 or wall>180 or peak>MAXRSS or total()>WORK-65536 or shutil.disk_usage(ROOT).free<RESERVE+65536:failure={'terminalBudgetFailure':True,'previous':failure}
  for path,digest in pins.items():
   if sha(ROOT/path)!=digest:failure={'changedBuildSource':path}
  for r in receipt['files']:
   if sha(ROOT/'sources'/r['path'])!=r['sha256']:failure={'changedOfficialSource':r['path']}
  result={'buildVariant':'restored-20261029-v1','historicalBinaryNotAssumed':True,'success':code==0 and failure is None,'exitCode':code,'failure':failure,'wallSeconds':wall,'CPUSeconds':cpu,'peakSampledOrWaitedTreeRSSBytes':peak,'pins':pins,'command':command,'sourcePin':receipt['pin'],'sourceFiles':48,'compilerVersion':subprocess.check_output(['g++','--version'],text=True).splitlines()[0],'serial':True,'OpenMP':False,'systemInstall':False,'sourceUnchanged':True,'librarySHA256':sha(out/'libblind_octomap.so')if (out/'libblind_octomap.so').exists()else None,'libraryBytes':(out/'libblind_octomap.so').stat().st_size if (out/'libblind_octomap.so').exists()else None,'workBytes':total(),'freeBytes':shutil.disk_usage(ROOT).free}
  (out/'BUILD_RECEIPT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
 if not result['success']:raise SystemExit(1)
if __name__=='__main__':main()

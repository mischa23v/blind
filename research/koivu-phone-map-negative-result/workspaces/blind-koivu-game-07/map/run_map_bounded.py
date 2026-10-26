"""Serial map-build watchdog; exclusive result directory, terminal resource checks."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time,traceback
ROOT=Path(__file__).resolve().parent
CPU=600;WALL=900;RSS=2*1024**3;OUTPUT=64*1024**2;RESERVE=768*1024**2

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def usage(pid):
 try:
  stat=Path(f'/proc/{pid}/stat').read_text().split(') ',1)[1].split();cpu=(int(stat[11])+int(stat[12]))/os.sysconf('SC_CLK_TCK');rss=int(stat[21])*os.sysconf('SC_PAGE_SIZE');return cpu,rss
 except FileNotFoundError:return 0.,0

def limits():resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU));resource.setrlimit(resource.RLIMIT_AS,(3*1024**3,)*2)
def size(out):return sum(x.stat().st_size for x in out.rglob('*') if x.is_file())
def main():
 expected=sys.argv[1]
 if sha(ROOT/'FROZEN.json')!=expected:raise ValueError('frozen config hash mismatch')
 out=ROOT/'run-01';out.mkdir(exist_ok=False);start=time.monotonic();peak=0;maxcpu=0;failure=None;code=None;p=None
 before=resource.getrusage(resource.RUSAGE_CHILDREN)
 env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',NUMEXPR_NUM_THREADS='1')
 try:
  with (out/'stdout.log').open('x') as so,(out/'stderr.log').open('x') as se,(out/'heartbeat.jsonl').open('x') as hb:
   p=subprocess.Popen([sys.executable,str(ROOT/'map_builder.py'),str(out/'map'),expected],stdout=so,stderr=se,env=env,preexec_fn=limits)
   while p.poll() is None:
    cpu,rss=usage(p.pid);peak=max(peak,rss);maxcpu=max(maxcpu,cpu);wall=time.monotonic()-start;amount=size(out);free=shutil.disk_usage(ROOT).free
    row={'wallSeconds':wall,'sampledCPUSeconds':cpu,'sampledRSSBytes':rss,'peakSampledRSSBytes':peak,'outputBytes':amount,'freeBytes':free};hb.write(json.dumps(row)+'\n');hb.flush()
    if wall>WALL or cpu>CPU or rss>RSS or amount>OUTPUT-65536 or free<RESERVE+65536:failure={'budgetViolation':row};p.kill();break
    time.sleep(2)
   code=p.wait()
 except BaseException as exc:
  failure={'exception':repr(exc),'traceback':traceback.format_exc()}
 finally:
  if p is not None and p.poll() is None:p.kill();code=p.wait()
  after=resource.getrusage(resource.RUSAGE_CHILDREN);cpu=after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime;maxcpu=max(maxcpu,cpu);peak=max(peak,int(after.ru_maxrss)*1024);wall=time.monotonic()-start;amount=size(out);free=shutil.disk_usage(ROOT).free
  if cpu>CPU or wall>WALL or peak>RSS or amount>OUTPUT-65536 or free<RESERVE+65536:failure={'terminalBudgetViolation':{'cpu':cpu,'wall':wall,'peakRSS':peak,'outputs':amount,'free':free},'priorFailure':failure}
  if sha(ROOT/'FROZEN.json')!=expected:failure={'frozenConfigChanged':True,'priorFailure':failure}
  receipt={'exitCode':code,'success':code==0 and failure is None,'wallSeconds':wall,'waitedChildCPUSeconds':cpu,'maxSampledOrWaitedCPUSeconds':maxcpu,'peakSampledOrWaitedRSSBytes':peak,'budgets':{'cpuSeconds':CPU,'wallSeconds':WALL,'RSSBytes':RSS,'outputBytes':OUTPUT,'freeReserveBytes':RESERVE},'outputBytesBeforeReceipt':amount,'freeBytesBeforeReceipt':free,'frozenConfigSHA256':expected,'failure':failure,'evaluationOrNavigationRun':False}
  with (out/'RUN_RECEIPT.json').open('x') as f:f.write(json.dumps(receipt,indent=2)+'\n')
  print(json.dumps(receipt),flush=True)
 if not receipt['success']:raise SystemExit(1)
if __name__=='__main__':main()

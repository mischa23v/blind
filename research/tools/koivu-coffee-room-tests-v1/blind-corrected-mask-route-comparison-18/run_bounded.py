"""One small serial read-only reproduction, preserving failed partial evidence."""
from pathlib import Path
import hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parent;CPU=120;WALL=180;RSS=1024*1024**2;OUTPUT=16*1024**2;RESERVE=768*1024**2

def limits():resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU));resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT))
def size(p):return sum(f.stat().st_size for f in p.rglob('*')if f.is_file())
def usage(pid):
    try:
        f=Path(f'/proc/{pid}/stat').read_text().rsplit(') ',1)[1].split();return int(f[21])*os.sysconf('SC_PAGE_SIZE')
    except FileNotFoundError:return 0

def main():
    expected=sys.argv[1]
    if hashlib.sha256((ROOT/'FROZEN.json').read_bytes()).hexdigest()!=expected:raise ValueError('frozen manifest changed')
    out=ROOT/'run-01';out.mkdir(exist_ok=False);start=time.monotonic();peak=0;failure=None;child=None;code=None
    if shutil.disk_usage(ROOT).free<RESERVE+OUTPUT:raise ValueError('reserve preflight')
    before=resource.getrusage(resource.RUSAGE_CHILDREN)
    try:
        with (out/'stdout.log').open('x')as so,(out/'stderr.log').open('x')as se:
            child=subprocess.Popen([sys.executable,str(ROOT/'compare_fixed.py'),str(out/'result'),expected],stdout=so,stderr=se,env=dict(os.environ,OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1'),preexec_fn=limits)
            while child.poll()is None:
                peak=max(peak,usage(child.pid))
                if time.monotonic()-start>WALL or peak>RSS or size(out)>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:failure='observed resource budget';child.kill();break
                time.sleep(.1)
            code=child.wait()
    except BaseException as e:failure=repr(e)
    finally:
        if child is not None and child.poll()is None:child.kill();code=child.wait()
        after=resource.getrusage(resource.RUSAGE_CHILDREN);peak=max(peak,after.ru_maxrss*1024);cpu=after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime;wall=time.monotonic()-start
        if peak>RSS or cpu>CPU or wall>WALL or size(out)>OUTPUT-65536 or shutil.disk_usage(ROOT).free<RESERVE:failure='terminal resource budget'
        if hashlib.sha256((ROOT/'FROZEN.json').read_bytes()).hexdigest()!=expected:failure='frozen manifest changed'
        receipt={'frozenManifestSHA256':expected,'exitCode':code,'success':code==0 and failure is None,'failure':failure,'wallSeconds':wall,'childCPUSeconds':cpu,'peakSampledOrWaitedRSSBytes':peak,'budgets':{'CPUSeconds':CPU,'wallSeconds':WALL,'RSSBytes':RSS,'outputBytes':OUTPUT,'freeReserveBytes':RESERVE},'sampledNotCgroupEnforcement':True,'referenceMeshLoaded':False,'savedReferenceProxyUsed':False,'gameEpisodesExecuted':0}
        (out/'RUN_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))
    if not receipt['success']:raise SystemExit(1)

if __name__=='__main__':main()

#!/usr/bin/env python3
"""SOURCE ONLY: root review/admission required. Never invokes installs or retries.
Native fixed15 comparator: adapted from the passed exact-XYZ aggregate guard.
Adds compile/ELF/native-boundary checks; accounting/limits remain unchanged.
This source-only adapter needs independent review and root admission.
"""
import hashlib, json, math, os, pathlib, re, resource, signal, stat, subprocess, sys, time
H = pathlib.Path(__file__).resolve().parent
ROOT = H.parents[3]
CPU, WALL, RSS, OUTPUT = 120, 180, 1024**3, 64*1024**2

def file_record(fd, hashed):
    before=os.fstat(fd)
    if not stat.S_ISREG(before.st_mode): raise RuntimeError('Nonregular file refused')
    row={'bytes':before.st_size,'device':before.st_dev,'inode':before.st_ino,
         'mtimeNs':before.st_mtime_ns,'ctimeNs':before.st_ctime_ns}
    if hashed:
        if before.st_size>OUTPUT: raise RuntimeError('File exceeds output bound')
        with os.fdopen(os.dup(fd),'rb') as f: row['sha256']=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise RuntimeError('File changed during terminal hashing')
    return row

def sha(p):
    fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode): raise RuntimeError('Nonregular pinned input')
        before=os.fstat(fd)
        with os.fdopen(os.dup(fd),'rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
        after=os.fstat(fd)
        if (before.st_size,before.st_mtime_ns,before.st_ctime_ns)!=(after.st_size,after.st_mtime_ns,after.st_ctime_ns):
            raise RuntimeError('Pinned input changed during hash')
        return digest
    finally: os.close(fd)

def inventory(root, active):
    """Bounded descriptor traversal. Only active ENOENT races may be skipped."""
    result={}; visits=0; total=0
    def walk(fd,prefix,depth):
        nonlocal visits,total
        if depth>8: raise RuntimeError('Output nesting cap')
        with os.scandir(fd) as entries:
            for entry in entries:
                visits+=1
                if visits>4096: raise RuntimeError('Output entry cap')
                name=entry.name; key=prefix+name
                try:
                    seen=os.stat(name,dir_fd=fd,follow_symlinks=False);mode=seen.st_mode
                    if stat.S_ISLNK(mode): raise RuntimeError('Output symlink refused: '+key)
                    if stat.S_ISDIR(mode):
                        child=os.open(name,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd)
                        try:
                            opened=os.fstat(child)
                            if (opened.st_dev,opened.st_ino)!=(seen.st_dev,seen.st_ino):
                                raise RuntimeError('Output directory replaced: '+key)
                            result[key+'/']={'bytes':0,'device':opened.st_dev,'inode':opened.st_ino,
                                             'mtimeNs':opened.st_mtime_ns,'ctimeNs':opened.st_ctime_ns}
                            walk(child,key+'/',depth+1)
                        finally: os.close(child)
                    elif stat.S_ISREG(mode):
                        child=os.open(name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=fd)
                        try:
                            opened=os.fstat(child)
                            if (opened.st_dev,opened.st_ino)!=(seen.st_dev,seen.st_ino):
                                raise RuntimeError('Output file replaced: '+key)
                            total+=opened.st_size
                            if total>OUTPUT: raise RuntimeError('Aggregate output inventory cap')
                            result[key]=file_record(child,not active and key!='GUARD_RUN/RESULT.json')
                        finally: os.close(child)
                    else: raise RuntimeError('Output special file refused: '+key)
                except FileNotFoundError:
                    if not active: raise
    fd=os.open(root,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    try: walk(fd,'',0)
    finally: os.close(fd)
    return result

def stable_inventory(root):
    first=inventory(root,False)
    if first!=inventory(root,False): raise RuntimeError('Terminal output inventory changed')
    return {name:row for name,row in first.items() if name!='GUARD_RUN/RESULT.json'}

def usage():
    r=resource.getrusage(resource.RUSAGE_CHILDREN)
    s=resource.getrusage(resource.RUSAGE_SELF)
    return r.ru_utime+r.ru_stime+s.ru_utime+s.ru_stime

def group_sample(pgid):
    cpu=rss=members=0
    for entry in pathlib.Path('/proc').iterdir():
        if not entry.name.isdecimal(): continue
        try:
            # comm may contain whitespace or parentheses; split after final ')'.
            a=(entry/'stat').read_text().rsplit(')',1)[1].split()
            if int(a[2])!=pgid: continue  # Original field 5: pgrp.
            members+=1
            cpu+=sum(int(a[i]) for i in (11,12,13,14))/os.sysconf('SC_CLK_TCK')
            rss+=int(a[21])*os.sysconf('SC_PAGE_SIZE')
        except (FileNotFoundError, ProcessLookupError): pass
    return cpu,rss,members

def kill_group(pid):
    try: os.killpg(pid,signal.SIGKILL)
    except ProcessLookupError: pass

def main():
    if len(sys.argv)!=3 or sys.argv[1]!='--admitted-source-commit':
        raise SystemExit('Requires root admission: --admitted-source-commit <exact git HEAD>')
    if sys.platform!='linux': raise SystemExit('Linux procfs required')
    def interrupted(signum, frame):
        raise SystemExit('Supervisor interrupted by signal '+str(signum))
    for signum in (signal.SIGTERM,signal.SIGHUP): signal.signal(signum,interrupted)
    start=time.monotonic(); initial=usage()
    manifestBytes=(H/'NATIVE_GROUND_RUN_PINS.json').read_bytes()
    manifestDigest=hashlib.sha256(manifestBytes).hexdigest()
    pins=json.loads(manifestBytes)
    wrapperDigest=None
    def expand(value):
        if '@WRAPPER_SHA256@' in value and wrapperDigest is None:
            raise RuntimeError('Wrapper digest unavailable before verified build')
        return (value.replace('@WORKSPACE@',str(ROOT.parent))
                     .replace('@PROTOCOL@',str(H.parent))
                     .replace('@CANDIDATE@',str(H))
                     .replace('@WRAPPER_SHA256@',wrapperDigest or ''))
    def verify_runtime_links():
        if os.path.lexists('/etc/ld.so.preload'):
            raise RuntimeError('Host loader preload file is outside admitted closure')
        for name,target in pins['runtimeSymlinkTargets'].items():
            if str(pathlib.Path(name).resolve(strict=True))!=target:
                raise RuntimeError('Runtime symlink target changed: '+name)
    def verify_pins():
        verify_runtime_links()
        if sha(H/'NATIVE_GROUND_RUN_PINS.json')!=manifestDigest: raise RuntimeError('Run manifest changed')
        actual={}
        for name,digest in pins['inputs'].items():
            expanded=expand(name)
            p=pathlib.Path(expanded) if expanded.startswith('/') else ROOT/expanded
            actual[name]=sha(p)
            if actual[name]!=digest: raise RuntimeError('Pin mismatch: '+name)
        return actual
    beforePins=verify_pins()
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True,timeout=5).strip()
    if head!=sys.argv[2]: raise SystemExit('Admitted source commit mismatch')
    committed=subprocess.check_output(['git','show',head+':'+str((H/'NATIVE_GROUND_RUN_PINS.json').relative_to(ROOT))],
                                      cwd=ROOT,timeout=5)
    if committed!=manifestBytes: raise RuntimeError('Run manifest differs from admitted commit')
    # Bind every repository source byte to the admitted commit. The restored
    # schedule is instead bound to its committed gzip and original SHA256.
    for name,digest in pins['inputs'].items():
        if name.startswith('/') or name.startswith('@WORKSPACE@'): continue
        if name.endswith('/SCHEDULE_20.json'): continue
        data=subprocess.check_output(['git','show',head+':'+name],cwd=ROOT,timeout=5)
        if hashlib.sha256(data).hexdigest()!=digest:
            raise RuntimeError('Input differs from admitted commit: '+name)
    # Refuse existing attempts; preserve all native failures and partial logs.
    work=pathlib.Path(expand(pins['workRoot']))
    work.mkdir(exist_ok=False)
    out=work/'GUARD_RUN';out.mkdir(exist_ok=False)
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    receipt={'schema':1,'sourceCommit':head,'status':'started','commands':[],
             'limits':{'cpuSeconds':CPU,'wallSeconds':WALL,'observedRSSBytes':RSS,'outputBytes':OUTPUT},
             'cpuAffinity':[cpu], 'manifestSHA256':manifestDigest, 'pins':pins, 'inputHashesBefore':beforePins, 'physicalAuthority':False,
             'peakObservedAggregateRSS':0,'peakFastExitChildRSS':0,
             'nativeBoundaryChecks':[], 'nativeBinaryInitiallyUnbuilt':True,
             'limitations':['Observed RSS polling, not hard cgroup memory limit',
                 'Same-mesh contacts cannot reveal tabletops absent from the mesh',
                 'Nine probes are not complete-footprint support; labels are not semantic truth',
                 'No-contact never establishes real-world clearance or navigation accuracy',
                 'Pinned primary planner ELF, selected host library bytes and loader cache are not a hermetic OS/toolchain attestation']}
    def write_receipt(encoded):
        # Validate before truncation; never follow even a terminally refused symlink.
        fd=os.open(out/'RESULT.json',os.O_WRONLY|os.O_CREAT|os.O_NOFOLLOW|os.O_NONBLOCK,0o600)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode): raise RuntimeError('Receipt is not regular')
            os.ftruncate(fd,0)
            with os.fdopen(os.dup(fd),'w') as f: f.write(encoded)
        finally: os.close(fd)
    def save():
        receipt['wallSeconds']=time.monotonic()-start
        receipt['aggregateCPUSeconds']=usage()-initial
        encoded=json.dumps(receipt,indent=2)+'\n'
        if len(encoded.encode())>262144:
            write_receipt(json.dumps({'status':'failed','error':'receipt size cap',
                'sourceCommit':head,'commands':[{'label':r['label'],'exitCode':r.get('exitCode'),
                'groupRetired':r.get('groupRetired')} for r in receipt['commands']]}))
            raise RuntimeError('Receipt size cap')
        write_receipt(encoded)
    env={'PATH':'/usr/bin:/bin','LC_ALL':'C','HOME':str(out), 'TMPDIR':str(out),
         'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1','PYTHONDONTWRITEBYTECODE':'1'}
    def retire(p,row):
        kill_group(p.pid)
        row['exitCode']=p.wait(timeout=2)
        deadline=min(start+WALL,time.monotonic()+2)
        while group_sample(p.pid)[2]:
            if time.monotonic()>=deadline:
                row['groupRetired']=False
                raise RuntimeError('Process group retirement not observed')
            time.sleep(.02)
        row['groupRetired']=True
    def command(args,label):
        row={'label':label,'argv':args};receipt['commands'].append(row);save()
        consumed=usage()-initial
        if consumed>=CPU or time.monotonic()-start>=WALL: raise RuntimeError('Aggregate budget exhausted')
        def limits():
            # Aggregate remaining budget is enforced by supervisor accounting.
            resource.setrlimit(resource.RLIMIT_CPU,(CPU,CPU))
            resource.setrlimit(resource.RLIMIT_FSIZE,(OUTPUT,OUTPUT))
            resource.setrlimit(resource.RLIMIT_CORE,(0,0))
        p=None
        try:
            with (out/(label+'.stdout')).open('xb') as stdout, (out/(label+'.stderr')).open('xb') as stderr:
                p=subprocess.Popen(args,cwd=work,env=env,stdout=stdout,stderr=stderr,
                                   start_new_session=True,preexec_fn=limits)
                while True:
                    liveCPU,liveRSS,_=group_sample(p.pid)
                    selfRSS=int(pathlib.Path('/proc/self/statm').read_text().split()[1])*os.sysconf('SC_PAGE_SIZE')
                    receipt['peakObservedAggregateRSS']=max(receipt['peakObservedAggregateRSS'],liveRSS+selfRSS)
                    size=sum(f['bytes'] for f in inventory(work,True).values())
                    if usage()-initial+liveCPU>CPU: raise RuntimeError('Aggregate CPU breach')
                    if time.monotonic()-start>WALL: raise RuntimeError('Aggregate wall breach')
                    if liveRSS+selfRSS>RSS: raise RuntimeError('Observed aggregate RSS breach')
                    if size>OUTPUT: raise RuntimeError('Aggregate output breach')
                    code=p.poll()
                    if code is not None: break
                    time.sleep(.02)
                # A completed leader must not leave descendants running.
                row['exitCode']=p.wait()
                leftovers=group_sample(p.pid)[2]
                retire(p,row)
                if leftovers: raise RuntimeError('Leader exited leaving group members')
                fast=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss*1024
                receipt['peakFastExitChildRSS']=max(receipt['peakFastExitChildRSS'],fast)
                if fast>RSS or usage()-initial>CPU: raise RuntimeError('Fast-exit resource breach')
                if time.monotonic()-start>WALL: raise RuntimeError('Final aggregate wall breach')
                # Reserve 256 KiB for final JSON evidence, never silently drop it.
                terminal=stable_inventory(work)
                if sum(f['bytes'] for f in terminal.values())>OUTPUT-262144:
                    raise RuntimeError('Final output/reserved receipt breach')
                row['terminalInventory']=terminal
                if row['exitCode']!=0: raise RuntimeError(label+' nonzero exit')
        finally:
            if p is not None:
                try: retire(p,row)
                finally: save()
            else: save()
    def native_boundary(label):
        verify_runtime_links()
        hashes={}
        for name in pins['nativeBoundaryInputs']:
            p=pathlib.Path(expand(name))
            hashes[name]=sha(p)
            if hashes[name]!=pins['inputs'][name]:
                raise RuntimeError('Native boundary pin changed: '+name)
        if wrapperDigest is not None:
            wrapper=pathlib.Path(expand(pins['wrapperPath']))
            if wrapper.parent!=work or wrapper.name!='libcoffee_mark_walkable_15.so':
                raise RuntimeError('Unexpected wrapper output ownership')
            if sha(wrapper)!=wrapperDigest: raise RuntimeError('Generated wrapper changed')
        receipt['nativeBoundaryChecks'].append({'stage':label,'wrapperSHA256':wrapperDigest,'inputHashes':hashes})
    def inspect_elf(label,required):
        # readelf is a bounded child process, not a library loader.
        data=(out/(label+'.stdout')).read_text()
        needed=re.findall(r'\(NEEDED\).*Shared library: \[([^\]]+)\]',data)
        if len(needed)!=len(set(needed)) or not set(required).issubset(needed):
            raise RuntimeError('Missing/duplicate required ELF dependency: '+label)
        if any(tag in data for tag in ('(RPATH)','(RUNPATH)','(SONAME)')):
            raise RuntimeError('Unexpected ELF search path or SONAME: '+label)
        allowed=set(pins['allowedHostNeededNames'])|set(required)
        if any(name not in allowed for name in needed):
            raise RuntimeError('Unreviewed ELF dependency: '+label)
        receipt[label]={'needed':needed,'required':list(required),'rpath':None,'runpath':None}
    try:
        native_boundary('before-build')
        command([expand(arg) for arg in pins['compileCommand']],'compile')
        command([expand(arg) for arg in pins['dependencyELFCommand']],'dependency-elf')
        inspect_elf('dependency-elf',pins['plannerNeededNames'])
        command([expand(arg) for arg in pins['wrapperELFCommand']],'wrapper-elf')
        inspect_elf('wrapper-elf',[expand(pins['plannerLibraryPath'])])
        wrapperDigest=sha(pathlib.Path(expand(pins['wrapperPath'])))
        receipt['compiledWrapperSHA256']=wrapperDigest
        native_boundary('before-controls')
        command([expand(arg) for arg in pins['controlsCommand']],'controls')
        native_boundary('after-controls')
        controlText=(out/'controls.stderr').read_text()
        if not re.search(r'\nRan 67 tests in [^\n]+\n\nOK\n\Z',controlText):
            raise RuntimeError('Expected all 67 controls with no skips')
        receipt['controlsExecuted']=67
        native_boundary('before-comparison')
        command([expand(arg) for arg in pins['comparisonCommand']],'comparison')
        native_boundary('after-comparison')
        actual=json.loads((work/'comparison/RECEIPT.json').read_text())
        receipt['comparison']={key:actual[key] for key in
            ('groundAdjacencyMode','triangleEligibilityPolicy','nativeClassifier',
             'candidatePinsSHA256','originalDefaultPolicyUnmodified',
             'status','error','counters','arms','physicalAuthority','continuousSupportProven',
             'semanticFloorEstablished','coverageEstablished','movementEpisode')}
        if actual['groundAdjacencyMode']!=pins['groundAdjacencyMode'] or actual['candidatePinsSHA256']!=pins['candidatePinsSHA256']:
            raise RuntimeError('Candidate output mode/pin mismatch')
        native=actual['nativeClassifier']
        if (actual['triangleEligibilityPolicy']!=pins['triangleEligibilityPolicy'] or
            native['policy']!=pins['triangleEligibilityPolicy'] or
            native['wrapperSHA256']!=wrapperDigest or native['abiVersion']!=1 or
            native['slopeDegrees']!=15. or native['initialTriangleMarkingOnly'] is not True):
            raise RuntimeError('Native classifier output policy/identity mismatch')
        if actual['originalDefaultPolicyUnmodified'] is not True or any(actual[key] is not False for key in
                ('physicalAuthority','continuousSupportProven','semanticFloorEstablished','coverageEstablished','movementEpisode')):
            raise RuntimeError('Diagnostic authority boundary changed')
        if actual['status']!='diagnosticCompleted':
            raise RuntimeError('Incomplete comparison retained; not clear')
        receipt['status']='completed-zero-exit' # Same-mesh diagnostic, not clearance.
    except BaseException as error:
        receipt['status']='failed';receipt['error']=type(error).__name__+': '+str(error)
        raise
    finally:
        finalError=None
        try:
            receipt['inputHashesAfter']=verify_pins()
            if wrapperDigest is not None: native_boundary('final')
        except BaseException as error:
            receipt['status']='failed'
            receipt['postPinError']=type(error).__name__+': '+str(error)
            finalError=error
        if all(row.get('groupRetired') is True for row in receipt['commands']):
            try:
                receipt['finalPayloadInventory']=stable_inventory(work)
                payloadBytes=sum(row['bytes'] for row in receipt['finalPayloadInventory'].values())
                if payloadBytes>OUTPUT-262144: raise RuntimeError('Final payload/receipt reserve breach')
            except BaseException as error:
                receipt['status']='failed'
                receipt['inventoryError']=type(error).__name__+': '+str(error)
                finalError=error
        else:
            receipt['terminalInventoryStatus']='unverified: process group retirement not established'
            receipt['status']='failed'
            finalError=RuntimeError('Unverified process group retirement')
        if usage()-initial>CPU or time.monotonic()-start>WALL:
            receipt['status']='failed';receipt['resourceError']='Final evidence resource budget breach'
            finalError=RuntimeError(receipt['resourceError'])
        save()
        # Final encoding/writing is charged too; no second full pin hash.
        if usage()-initial>CPU or time.monotonic()-start>WALL:
            receipt['status']='failed';receipt['resourceError']='Final receipt resource budget breach'
            finalError=RuntimeError(receipt['resourceError']);save()
        if finalError is not None: raise finalError

if __name__=='__main__': main()

"""Bounded eight-frame audit; explicit local roots, immutable input/source pins."""
from pathlib import Path
import hashlib,json,math,os,resource,shutil,signal,subprocess,sys,time,struct

ROOT=Path(__file__).resolve().parent
CAP=32*1024**2; RESERVE=768*1024**2; CPU=60.; WALL=90.; RSS=512*1024**2

def digest(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
    return h.hexdigest()
def dump(path,value):path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
def size(path):return sum(p.stat().st_size for p in path.rglob('*') if p.is_file()) if path.exists() else 0
def current_tree_usage(rootpid):
    """Sample live tree RSS and CPU including each process's already-waited descendants.

    A child's live CPU is not in its parent's waited-child counters. Summing
    utime/stime/cutime/cstime once per currently live tree process includes active
    compiler/plot CPU without waiting for RUSAGE_CHILDREN to update. This remains
    a sampled Linux watchdog, with tick resolution and process-exit sampling races.
    """
    entries={};page=os.sysconf('SC_PAGE_SIZE');hz=os.sysconf('SC_CLK_TCK')
    for p in Path('/proc').iterdir():
        if not p.name.isdigit():continue
        try:
            fields=(p/'stat').read_text().rsplit(')',1)[1].split()
            entries[int(p.name)]=(int(fields[1]),int(fields[21])*page,sum(int(fields[i]) for i in (11,12,13,14))/hz)
        except (OSError,ValueError,IndexError):continue
    if rootpid not in entries:raise RuntimeError('own resource counters unavailable')
    selected={rootpid}
    while True:
        new={pid for pid,(ppid,_,_) in entries.items() if ppid in selected}
        if new<=selected:break
        selected|=new
    return sum(entries[p][1] for p in selected),sum(entries[p][2] for p in selected)

def cpu():return current_tree_usage(os.getpid())[1]

class Bounds:
    def __init__(self,cache):
        self.started=time.monotonic();self.cpu_start=cpu();self.cache=cache;self.cache_before=size(cache)
        self.root_before=size(ROOT);self.peak_rss=0;self.phases=[]
    def check(self):
        observed_rss,observed_cpu=current_tree_usage(os.getpid())
        self.peak_rss=max(self.peak_rss,observed_rss)
        if self.peak_rss>RSS:raise RuntimeError('sampled process-tree RSS cap')
        if time.monotonic()-self.started>WALL:raise RuntimeError('total wall cap')
        if observed_cpu-self.cpu_start>CPU:raise RuntimeError('total CPU cap')
        if self.new_bytes()>CAP:raise RuntimeError('new output cap')
        if shutil.disk_usage(ROOT).free<RESERVE:raise RuntimeError('free-space reserve')
    def new_bytes(self):return max(0,size(ROOT)-self.root_before)
    def run(self,args,stdout,stderr,env):
        self.check();remaining=max(1,int(math.floor(CPU-(cpu()-self.cpu_start))))
        def limits():resource.setrlimit(resource.RLIMIT_CPU,(remaining,remaining))
        start=time.monotonic();before=cpu()
        with stdout.open('wb') as out,stderr.open('wb') as err:
            p=subprocess.Popen(args,stdout=out,stderr=err,env=env,start_new_session=True,preexec_fn=limits)
            try:
                while p.poll() is None:self.check();time.sleep(.04)
                self.check()
            except BaseException:
                try:os.killpg(p.pid,signal.SIGKILL)
                except ProcessLookupError:pass
                p.wait();raise
        self.phases.append({'command':args,'exitCode':p.returncode,'wallSeconds':time.monotonic()-start,'cpuSeconds':cpu()-before})
        if p.returncode:raise RuntimeError('phase failed; original logs retained: '+str(stdout))


SPECS={
 'EM1-1093':([0,56,112,168,224,280,336,393],'5cd8b4d03fd7e1ed2ec28d005d4e01209dddd9583029787f85e5b5f65376e6cb'),
 'EM1-0387':([0,12,25,37,50,62,75,88],'aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4')}

VERIFIED_INPUT_PINS={
 'EM1-1093':{'FIELD_AUDIT.json':'957260087da568068c81acdf801d586a997b6c43ce666339e4d31a6f8947c00b','NATIVE_MANIFEST.json':'3a5eea34ee42f30faa63af0400b225360dec88a474e098dd56e464278d43b1bb'},
 'EM1-0387':{'FIELD_AUDIT.json':'8f6781e8c4ba1e1a0174211c5d1694eaedf84bad89ebc501620794ca69460b99','NATIVE_MANIFEST.json':'ca8dc82d0ac3f14f96a6d800ce6f447b02f7861f223831fac9d21b9c6d9ce3b8'}}

def main():
    base=ROOT.parent.parent.resolve(); shared=Path(os.environ['SHARED']).resolve()
    native=base/'blind-native-depth-policy/build-01';recorded=base/'blind-navigation-recorded/build-06'
    core=shared/'blind-body-warning-build/.build/debug'
    out=ROOT/'run.partial';final=ROOT/'run'
    if out.exists() or final.exists():raise RuntimeError('refuse historical result overwrite')
    swift=shutil.which('swiftc')
    if swift is None:raise RuntimeError('source existing toolchain; no install permitted')
    out.mkdir();build=out/'build';build.mkdir();cache=build/'cache';b=Bounds(cache)
    pins={};summaries=[]
    try:
        b.check()
        fixed={
         base/'blind-native-depth-policy/source/BlindCore/Sources/BlindCore/NativeDepthObservationPolicy.swift':'0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c',
         native/'libNativeDepthPolicySupport.so':'b52ad4059563b983e4277fcdca28238475c3d1884c2be4846d16796bbc180d2f',
         native/'NativeDepthPolicySupport.swiftmodule':'0c291a5601d20324377a62939672806b06900e2b000d04fb0bca4ea6e828e9d5',
         recorded/'libRecordedNavigationSupport.so':'259d738498f385fb8753755dd2e54554d7f1d13df800a77d872aae5504586531',
         recorded/'RecordedNavigationSupport.swiftmodule':'c237f45c0365ce065b7ff345008b474b2d291f5e73d5c8fc1a093f0b094cf081',
         core/'BlindCore.o':'f358f20627bb535cef83783061af827cf5784148409e98edc9e3aeec3f836d52',
         core/'BlindCore.swiftmodule/x86_64-unknown-linux-gnu.swiftmodule':'88bbf07e1a9dbfff7915423f7d65855c4146cf5cc9b777084c9c263a9e9fcbf2',
         base/'blind-navigation-combined/full-source/BlindCore/Sources/BlindCore/Geometry.swift':'f7a27aff67ed97dda0550463e70ee9df9c85381024ce02f2f091a2b35f353eb5',
         shared/'blind-body-warning-build/Sources/BlindCore/Geometry.swift':'f7a27aff67ed97dda0550463e70ee9df9c85381024ce02f2f091a2b35f353eb5'}
        for path,expected in fixed.items():
            if digest(path)!=expected:raise ValueError('production dependency pin mismatch: '+str(path))
        policy=base/'blind-native-depth-policy/source/BlindCore/Sources/BlindCore/NativeDepthObservationPolicy.swift'
        if (native/'NativeDepthObservationPolicy.swift').read_bytes()!=b'import BlindCore\n'+policy.read_bytes():raise ValueError('compiled policy adaptation changed')
        fixed[native/'NativeDepthObservationPolicy.swift']=digest(native/'NativeDepthObservationPolicy.swift')
        for path in (ROOT/'PROTOCOL.md',ROOT/'NativeCameraAudit.swift',Path(__file__).resolve()):fixed[path]=digest(path)
        manifests=[]
        for clip,(ids,archive_sha) in SPECS.items():
            d=ROOT.parent/'audited'/clip;manifest=d/'NATIVE_MANIFEST.json';fieldpath=d/'FIELD_AUDIT.json';metadata=d/'selected/metadata'
            for name,expected in VERIFIED_INPUT_PINS[clip].items():
                if digest(d/name)!=expected:raise ValueError('independently verified acquisition receipt changed: '+name)
            f=json.loads(fieldpath.read_text());m=json.loads(metadata.read_text());inp=json.loads(manifest.read_text())
            if f['clipID']!=clip or f['archiveSHA256']!=archive_sha or f['frozenFrameIDs']!=ids or inp['clipID']!=clip:raise ValueError('provenance/selection gate')
            if [r['id'] for r in inp['frames']]!=ids or [r['frameID'] for r in f['frames']]!=ids:raise ValueError('frame order gate')
            expected_metadata=next(v for v in f['selectedMembers'] if v['name']=='metadata')
            if metadata.stat().st_size!=expected_metadata['bytes'] or digest(metadata)!=expected_metadata['sha256']:raise ValueError('original metadata pin')
            if [m[k] for k in ('dw','dh','w','h')]!=[256,192,1920,1440]:raise ValueError('dimensions')
            first=m['perFrameIntrinsicCoeffs'][0]
            if m['K']!=[first[0],0,0,0,first[1],0,first[2],first[3],1]:raise ValueError('global K first-frame association')
            for row,fr in zip(inp['frames'],f['frames']):
                i=row['id'];coeff=[row[k] for k in ('fx','fy','cx','cy')]
                if coeff!=m['perFrameIntrinsicCoeffs'][i] or coeff!=fr['intrinsics'] or not all(math.isfinite(x) and struct.unpack('<f',struct.pack('<f',x))[0]==x for x in coeff) or min(coeff[:2])<=0:raise ValueError('per-frame original Float intrinsics')
                if row['originalRelativeTimestamp']!=m['frameTimestamps'][i] or not math.isfinite(row['originalRelativeTimestamp']):raise ValueError('timestamp provenance')
                if [row[k] for k in ('width','height','imageWidth','imageHeight')]!=[256,192,1920,1440]:raise ValueError('manifest dimensions')
                for key,suffix,expected_size,hashkey in [('depthPath','depth.f32le',196608,'depthSHA256'),('confidencePath','confidence.u8',49152,'confidenceSHA256')]:
                    p=d/'decoded'/f'{i}.{suffix}'
                    if Path(row[key]).resolve()!=p.resolve() or p.stat().st_size!=expected_size or digest(p)!=fr[hashkey]:raise ValueError('decoded input pin')
                    fixed[p]=fr[hashkey]
            for p in (manifest,fieldpath,metadata):fixed[p]=digest(p)
            manifests.append((clip,manifest))
        pins={str(p):h for p,h in fixed.items()};dump(out/'SOURCE_DATA_PINS.json',{'scope':'Unmatched clips; camera-relative policy/projection only','files':pins})
        env=dict(os.environ)
        for k in ('LD_PRELOAD','LD_AUDIT'):env.pop(k,None)
        env['LD_LIBRARY_PATH']=str(native)+':'+str(recorded)
        env.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
        binary=build/'native-camera-audit'
        command=[swift,'-parse-as-library','-module-cache-path',str(cache),'-I',str(core),'-I',str(recorded),'-I',str(native),'-L',str(recorded),'-L',str(native),'-lRecordedNavigationSupport','-lNativeDepthPolicySupport',str(ROOT/'NativeCameraAudit.swift'),'-o',str(binary)]
        b.run(command,out/'compile.stdout.log',out/'compile.stderr.log',env)
        b.run(['ldd',str(binary)],out/'resolved-libraries.log',out/'ldd.stderr.log',env)
        resolved=(out/'resolved-libraries.log').read_text()
        for name,directory in [('libNativeDepthPolicySupport.so',native),('libRecordedNavigationSupport.so',recorded)]:
            line=next((s for s in resolved.splitlines() if name+' =>' in s),None)
            if line is None or line.split('=>',1)[1].strip().split()[0]!=str(directory/name):raise ValueError('wrong loaded library')
        for clip,manifest in manifests:
            b.run([str(binary),str(manifest)],out/(clip+'.json'),out/(clip+'.stderr.log'),env)
            result=json.loads((out/(clip+'.json')).read_text());ids=SPECS[clip][0]
            if result['clipID']!=clip or [r['frameID'] for r in result['frames']]!=ids or len(result['goldenProbes'])!=5 or result['scalarBoundaryProbesPassed']!=9:raise ValueError('native result identity/probes')
            fields=['fullRasterPixels','attemptedStridePixels','scalarAdmitted','projectedPoints','rejectedConfidence0','rejectedConfidence1','rejectedOtherConfidence','rejectedDepthNonfinite','rejectedDepthBelowRange','rejectedDepthAboveRange']
            totals={k:sum(r[k] for r in result['frames']) for k in fields}
            if totals['attemptedStridePixels']!=98304 or totals['scalarAdmitted']+sum(totals[k] for k in fields if k.startswith('rejected'))!=98304 or totals['projectedPoints']!=totals['scalarAdmitted']:raise ValueError('count reconciliation')
            summaries.append({'clipID':clip,'originalFrameIDs':ids,'counts':totals,'admittedFractionOfAttempted':totals['scalarAdmitted']/98304,'maxRoundTripPixelResidual':max(r['maxRoundTripPixelResidual'] for r in result['frames']),'maxRoundTripDepthResidual':max(r['maxRoundTripDepthResidual'] for r in result['frames'])})
        for p,h in pins.items():
            if digest(p)!=h:raise ValueError('source/data changed during native audit: '+p)
        b.check()
        receipt={'status':'completed','scope':'Actual unchanged production scalar admission and camera-relative projection only','unmatchedScenes':True,'hardwareAccuracyComparison':False,'worldOrBodyOrNavigation':False,'clips':summaries,'wallSeconds':time.monotonic()-b.started,'cpuSeconds':cpu()-b.cpu_start,'sampledPeakProcessTreeRSSBytes':b.peak_rss,'newOutputBytesBeforeReceipt':b.new_bytes(),'freeAfterBytes':shutil.disk_usage(ROOT).free,'caps':{'cpuSeconds':CPU,'wallSeconds':WALL,'sampledRSSBytes':RSS,'newBytes':CAP,'freeReserveBytes':RESERVE},'phases':b.phases,'binarySHA256':digest(binary),'sourceDataRehashedAfter':True,'artifacts':[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(out.rglob('*')) if p.is_file() and 'cache' not in p.relative_to(out).parts]}
        receipt['newOutputBytesIncludingReceipt']=0
        for _ in range(8):
            dump(out/'RECEIPT.json',receipt)
            actual=b.new_bytes()
            if receipt['newOutputBytesIncludingReceipt']==actual:break
            receipt['newOutputBytesIncludingReceipt']=actual
        else:raise RuntimeError('receipt size did not converge')
        b.check()  # Includes final receipt bytes and final free-space reserve.
        out.rename(final);print(json.dumps(receipt,indent=2))
    except BaseException as exc:
        dump(out/'FAILURE.json',{'status':'failed','error':repr(exc),'phases':b.phases,'wallSeconds':time.monotonic()-b.started,'sourceDataPins':pins});raise

if __name__=='__main__':main()

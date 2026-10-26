"""Bounded eight-frame audit; explicit local roots, immutable input/source pins."""
from pathlib import Path
import hashlib,json,math,os,resource,shutil,signal,subprocess,sys,time
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
CAP=24*1024**2; RESERVE=768*1024**2; CPU=60.; WALL=90.; RSS=512*1024**2
PROTOCOL_SHA='c464922f1fa4799d83f9eef5da6fb0158a62df134777ff7218181aa6f196cfaf'
POLICY_SHA='0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c'
LIB_SHA='b52ad4059563b983e4277fcdca28238475c3d1884c2be4846d16796bbc180d2f'
GEOMETRY_SHA='f7a27aff67ed97dda0550463e70ee9df9c85381024ce02f2f091a2b35f353eb5'
METADATA_SHA='fa1cab04539609735af5282726a453ce8e8da1b63e45e372bd3a70e03303f1fa'
CLIP_SHA='aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4'

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
    def new_bytes(self):return max(0,size(ROOT)-self.root_before)+max(0,size(self.cache)-self.cache_before)
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


def main():
    for key in ('WORKSPACE','SHARED'):
        if not os.environ.get(key):raise RuntimeError(key+' must explicitly select approved local inputs')
    base=Path(os.environ['WORKSPACE']).resolve();shared=Path(os.environ['SHARED']).resolve()
    data=base/'blind-raw-iphone-feasibility-01';native=base/'blind-native-depth-policy/build-01';recorded=base/'blind-navigation-recorded/build-06'
    core=shared/'blind-body-warning-build/.build/debug';cache=recorded/'cache'
    out=ROOT/'run.partial';final=ROOT/'run'
    if out.exists() or final.exists():raise RuntimeError('refuse historical result overwrite')
    swift=shutil.which('swiftc')
    if swift is None:raise RuntimeError('source the existing toolchain environment; no toolchain install is permitted')
    b=Bounds(cache);b.check();out.mkdir();build=out/'build';build.mkdir()
    try:
        protocol=base/'blind-raw-iphone-geometry-proposal-03/PROTOCOL.md'
        policy=base/'blind-native-depth-policy/source/BlindCore/Sources/BlindCore/NativeDepthObservationPolicy.swift'
        geometry=base/'blind-navigation-combined/full-source/BlindCore/Sources/BlindCore/Geometry.swift'
        built_geometry=shared/'blind-body-warning-build/Sources/BlindCore/Geometry.swift'
        metadata=data/'selected/metadata'
        prior_pins=base/'blind-raw-iphone-admission-02/SOURCE_DATA_PINS.json'
        selection=data/'SELECTION_RECEIPT.json'
        fixed={prior_pins:'de104438ce42ec161e399e1209d5c9044eb0bafaca406b6ce0210b7c9ab6a250',
               selection:'4a74d36dbe122b6080e8df6b31f19b7c4728f1b4698f241ef334d12c85e997b2',
               core/'BlindCore.o':'f358f20627bb535cef83783061af827cf5784148409e98edc9e3aeec3f836d52',
               core/'BlindCore.swiftmodule/x86_64-unknown-linux-gnu.swiftmodule':'88bbf07e1a9dbfff7915423f7d65855c4146cf5cc9b777084c9c263a9e9fcbf2',
               recorded/'RecordedNavigationSupport.swiftmodule':'c237f45c0365ce065b7ff345008b474b2d291f5e73d5c8fc1a093f0b094cf081',
               protocol:PROTOCOL_SHA,policy:POLICY_SHA,native/'libNativeDepthPolicySupport.so':LIB_SHA,
               geometry:GEOMETRY_SHA,built_geometry:GEOMETRY_SHA,metadata:METADATA_SHA}
        for p,h in fixed.items():
            if digest(p)!=h:raise ValueError('fixed source/data pin mismatch: '+str(p))
        if (native/'NativeDepthObservationPolicy.swift').read_bytes()!=b'import BlindCore\n'+policy.read_bytes():raise ValueError('compiled policy adaptation changed')
        prior=json.loads(prior_pins.read_text());selected=json.loads(selection.read_text())
        prior_dependencies={data/'FIELD_DECODE_AUDIT.json':prior['originalFieldAuditSHA256'],
            native/'NativeDepthPolicySupport.swiftmodule':prior['policyModule']['sha256'],
            recorded/'libRecordedNavigationSupport.so':prior['supportBinary']['sha256']}
        for p,h in prior_dependencies.items():
            if digest(p)!=h:raise ValueError('frozen stage-02 dependency changed: '+str(p))
        fixed.update(prior_dependencies)
        if selected['clipSHA256']!=CLIP_SHA or selected['frameIDs']!=list(range(8)):raise ValueError('original image selection')
        selected_files={f['name']:f for f in selected['files']}
        field=json.loads((data/'FIELD_DECODE_AUDIT.json').read_text());m=json.loads(metadata.read_text())
        if field['clipSHA256']!=CLIP_SHA or field['selectedFrameIDs']!=list(range(8)):raise ValueError('source selection')
        if field['datasetRevision']!='a285cd1249fe9762085713a1c796ab68b1810ac2':raise ValueError('dataset revision')
        if [m[k] for k in ('w','h','dw','dh')]!=[1920,1440,256,192]:raise ValueError('original dimension association')
        dependencies=[native/'NativeDepthPolicySupport.swiftmodule',recorded/'libRecordedNavigationSupport.so',
            recorded/'RecordedNavigationSupport.swiftmodule',core/'BlindCore.o',
            core/'BlindCore.swiftmodule/x86_64-unknown-linux-gnu.swiftmodule',
            data/'FIELD_DECODE_AUDIT.json',ROOT/'CameraGeometryAudit.swift',ROOT/'plot_camera_diagnostics.py',Path(__file__).resolve()]
        pins={str(p):digest(p) for p in list(fixed)+dependencies};frames=[]
        for row in field['frames']:
            i=row['frameID']
            if not isinstance(i,int) or not 0<=i<8:raise ValueError('unapproved frame')
            expected={f'{i}.depth.f32le',f'{i}.confidence.u8'}
            if {f['path'] for f in row['decodedFiles']}!=expected:raise ValueError('non-whitelisted decoded path')
            for f in row['decodedFiles']:
                p=data/'decoded'/f['path']
                if p.stat().st_size!=f['bytes'] or digest(p)!=f['sha256']:raise ValueError('decoded input changed')
                pins[str(p)]=f['sha256']
            rgb=data/'selected/rgbd'/f'{i}.jpg'
            with Image.open(rgb) as im:
                if im.size!=(m['w'],m['h']):raise ValueError('actual JPEG resolution differs')
            original=selected_files[f'rgbd/{i}.jpg']
            if rgb.stat().st_size!=original['bytes'] or digest(rgb)!=original['sha256']:raise ValueError('original JPEG changed')
            pins[str(rgb)]=original['sha256']
            coeff=m['perFrameIntrinsicCoeffs'][i]
            if len(coeff)!=4 or not all(math.isfinite(v) and float(np.float32(v))==v for v in coeff) or min(coeff[:2])<=0:raise ValueError('invalid/nonexact Float32 coefficients')
            timestamp=m['frameTimestamps'][i]
            if not math.isfinite(timestamp):raise ValueError('invalid original timestamp')
            frames.append({'id':i,'width':m['dw'],'height':m['dh'],'imageWidth':m['w'],'imageHeight':m['h'],
                'depthPath':str(data/'decoded'/f'{i}.depth.f32le'),'confidencePath':str(data/'decoded'/f'{i}.confidence.u8'),
                'fx':coeff[0],'fy':coeff[1],'cx':coeff[2],'cy':coeff[3],'originalRelativeTimestamp':timestamp})
        if [f['id'] for f in frames]!=list(range(8)):raise ValueError('frame order')
        first=m['perFrameIntrinsicCoeffs'][0]
        if m['K']!=[first[0],0,0,0,first[1],0,first[2],first[3],1]:raise ValueError('global K first-frame association')
        manifest=out/'INPUT_MANIFEST.json';dump(manifest,{'frames':frames})
        dump(out/'SOURCE_DATA_PINS.json',{'protocolSHA256':PROTOCOL_SHA,'clipSHA256':CLIP_SHA,'datasetRevision':field['datasetRevision'],
            'scope':'No pose/tracking/body/world fields are forwarded to the Swift runner. Timestamp is provenance only.','files':pins})
        env=dict(os.environ)
        for injected in ('LD_PRELOAD','LD_AUDIT'):env.pop(injected,None)
        env['LD_LIBRARY_PATH']=str(native)+':'+str(recorded)
        env.update(OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MPLCONFIGDIR=str(build/'mpl-cache'),PYTHONDONTWRITEBYTECODE='1')
        binary=build/'geometry-audit'
        command=[swift,'-parse-as-library','-module-cache-path',str(cache),'-I',str(core),'-I',str(recorded),'-I',str(native),
                 '-L',str(recorded),'-L',str(native),'-lRecordedNavigationSupport','-lNativeDepthPolicySupport',str(ROOT/'CameraGeometryAudit.swift'),'-o',str(binary)]
        b.run(command,out/'compile.stdout.log',out/'compile.stderr.log',env)
        b.run(['ldd',str(binary)],out/'resolved-libraries.log',out/'ldd.stderr.log',env)
        resolved=(out/'resolved-libraries.log').read_text()
        for name,directory in [('libNativeDepthPolicySupport.so',native),('libRecordedNavigationSupport.so',recorded)]:
            line=next((s for s in resolved.splitlines() if name+' =>' in s),None)
            if line is None or line.split('=>',1)[1].strip().split()[0]!=str(directory/name):raise ValueError('wrong loaded library')
        b.run([str(binary),str(manifest),str(out)],out/'geometry-result.json',out/'runtime.stderr.log',env)
        result=json.loads((out/'geometry-result.json').read_text())
        if [r['frameID'] for r in result['frames']]!=list(range(8)) or sum(r['projectedPoints'] for r in result['frames'])!=31648:raise ValueError('geometry count cross-check')
        b.run([sys.executable,str(ROOT/'plot_camera_diagnostics.py'),str(manifest),str(out)],out/'plot.stdout.log',out/'plot.stderr.log',env)
        original=data/'selected/rgbd/0.jpg';shutil.copyfile(original,out/'original-frame-0000.jpg')
        if digest(out/'original-frame-0000.jpg')!=pins[str(original)]:raise ValueError('untouched original RGB copy mismatch')
        (out/'IMAGE_ATTRIBUTION.md').write_text('Original JPEG is byte-identical to CaryxAI everyday-manipulation-3d-raw EM1-0387 frame 0, pinned dataset https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/tree/a285cd1249fe9762085713a1c796ab68b1810ac2 , CC BY 4.0 https://creativecommons.org/licenses/by/4.0/ . It is an original recorded image, not a generated diagnostic. Separate PNGs are analytical visualizations from original arrays and shared-camera-projection points; no holes filled. Camera-relative only, not physical accuracy, hazard recall or clearance. Raw JPEG/point CSV/plots remain local and are excluded from the public source/aggregate packet.\n')
        for p,h in pins.items():
            if digest(p)!=h:raise ValueError('source/input changed during audit: '+p)
        b.check()
        artifacts=[{'path':str(p.relative_to(out)),'bytes':p.stat().st_size,'sha256':digest(p)} for p in sorted(out.rglob('*')) if p.is_file()]
        receipt={'status':'completed','scope':'Camera-relative numerical consistency and recorded-ray distributions ONLY; not physical accuracy, detection, clearance or navigation',
            'protocolSHA256':PROTOCOL_SHA,'sameEightFrameIDs':list(range(8)),'attempted':98304,'projectedPoints':31648,
            'maxRoundTripPixelResidual':max(f['maxRoundTripPixelResidual'] for f in result['frames']),
            'maxRoundTripDepthResidual':max(f['maxRoundTripDepthResidual'] for f in result['frames']),
            'goldenProbes':result['goldenProbes'],'allInputAndSourceHashesUnchanged':True,'originalRGBUntouched':True,
            'physicalAuthority':False,'worldPoseTrackingGravityBodyUsed':False,'detectorOrNavigationCalled':False,
            'bounds':{'outputCapBytes':CAP,'reserveBytes':RESERVE,'cpuCapSeconds':CPU,'wallCapSeconds':WALL,'sampledTreeRSSCapBytes':RSS},
            'resources':{'wallSeconds':time.monotonic()-b.started,'cpuSeconds':cpu()-b.cpu_start,'sampledPeakTreeRSSBytes':b.peak_rss,
                'peakChildRSSKiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'newOutputBytesBeforeReceipt':b.new_bytes(),
                'cpuMeasurement':'Sampled Linux live-tree utime/stime plus waited-descendant cutime/cstime; tick resolution, not a hard cgroup quota',
                'cacheGrowthBytes':max(0,size(cache)-b.cache_before),'freeBytes':shutil.disk_usage(ROOT).free},
            'phases':b.phases,'artifacts':artifacts}
        dump(out/'GEOMETRY_RECEIPT.json',receipt);b.check();out.rename(final)
        print(json.dumps({k:receipt[k] for k in ['status','attempted','projectedPoints','maxRoundTripPixelResidual','maxRoundTripDepthResidual','resources']},indent=2))
    except BaseException as error:
        dump(out/'FAILURE_RECEIPT.json',{'status':'failed; retained, not overwritten','error':repr(error),'phases':b.phases,
            'wallSeconds':time.monotonic()-b.started,'cpuSeconds':cpu()-b.cpu_start,'sampledPeakTreeRSSBytes':b.peak_rss})
        raise

if __name__=='__main__':main()

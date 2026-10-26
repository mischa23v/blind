"""Pin original data and existing production module, compile audit-only runner."""
from pathlib import Path
import hashlib,json,os,resource,shlex,shutil,subprocess,time
import numpy as np

ROOT=Path(__file__).resolve().parent
def configured_root(name):
    value=os.environ.get(name)
    if not value or not Path(value).expanduser().is_absolute():
        raise ValueError(f'{name} must be an explicitly configured absolute directory')
    path=Path(value).expanduser().resolve()
    if not path.is_dir():raise ValueError(f'{name} directory does not exist')
    return path

BASE=configured_root('WORKSPACE')
SHARED=configured_root('SHARED')
DATA=BASE/'blind-raw-iphone-feasibility-01'
NATIVE=BASE/'blind-native-depth-policy/build-01'
RECORDED=BASE/'blind-navigation-recorded/build-06'
CORE=SHARED/'blind-body-warning-build/.build/debug'
POLICY=BASE/'blind-native-depth-policy/source/BlindCore/Sources/BlindCore/NativeDepthObservationPolicy.swift'
POLICY_SHA='0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c'
LIB_SHA='b52ad4059563b983e4277fcdca28238475c3d1884c2be4846d16796bbc180d2f'

def digest(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def main():
    if (ROOT/'ADMISSION_RECEIPT.json').exists():raise RuntimeError('Historical receipt exists; copy audit sources and protocol into a clean work directory before a separately approved rerun')
    if digest(POLICY)!=POLICY_SHA or digest(NATIVE/'libNativeDepthPolicySupport.so')!=LIB_SHA:raise ValueError('production source/binary pin mismatch')
    if (NATIVE/'NativeDepthObservationPolicy.swift').read_text()!='import BlindCore\n'+POLICY.read_text():raise ValueError('compiled policy source adaptation changed')
    if shutil.disk_usage(ROOT).free<768*1024**2:raise RuntimeError('free-space reserve')
    field=json.loads((DATA/'FIELD_DECODE_AUDIT.json').read_text())
    if field['clipSHA256']!='aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4' or field['selectedFrameIDs']!=list(range(8)):raise ValueError('unapproved source selection')
    datafiles=[];inputs=[]
    for row in field['frames']:
        i=row['frameID'];expected={f'{i}.depth.f32le',f'{i}.confidence.u8'}
        if {f['path'] for f in row['decodedFiles']}!=expected:raise ValueError('non-whitelisted frame paths')
        for f in row['decodedFiles']:
            p=DATA/'decoded'/f['path']
            if p.stat().st_size!=f['bytes'] or digest(p)!=f['sha256']:raise ValueError('changed original decoded input')
            datafiles.append({'path':str(p),'bytes':f['bytes'],'sha256':f['sha256']})
        inputs.append({'id':i,'width':row['depthWidth'],'height':row['depthHeight'],
            'depthPath':str(DATA/'decoded'/f'{i}.depth.f32le'),'confidencePath':str(DATA/'decoded'/f'{i}.confidence.u8')})
    if [r['id'] for r in inputs]!=list(range(8)):raise ValueError('source frame ordering')
    (ROOT/'INPUT_MANIFEST.json').write_text(json.dumps({'frames':inputs},indent=2)+'\n')
    pins={'scope':'Production scalar depth/confidence admission only; no tracking/projection/detection/navigation',
        'clipSHA256':field['clipSHA256'],'datasetRevision':field['datasetRevision'],
        'policySource':{'path':str(POLICY),'sha256':POLICY_SHA},
        'policyBinary':{'path':str(NATIVE/'libNativeDepthPolicySupport.so'),'sha256':LIB_SHA},
        'policyModule':{'path':str(NATIVE/'NativeDepthPolicySupport.swiftmodule'),'sha256':digest(NATIVE/'NativeDepthPolicySupport.swiftmodule')},
        'actualNativeSamplerSource':{'path':str(BASE/'blind-native-depth-policy/source/ios/BlindAssist/DepthSampler.swift'),'sha256':digest(BASE/'blind-native-depth-policy/source/ios/BlindAssist/DepthSampler.swift')},
        'supportBinary':{'path':str(RECORDED/'libRecordedNavigationSupport.so'),'sha256':digest(RECORDED/'libRecordedNavigationSupport.so')},
        'runnerSHA256':digest(ROOT/'AdmissionAudit.swift'),'protocolSHA256':digest(ROOT/'PROTOCOL.md'),
        'originalFieldAuditSHA256':digest(DATA/'FIELD_DECODE_AUDIT.json'),'dataFiles':datafiles}
    (ROOT/'SOURCE_DATA_PINS.json').write_text(json.dumps(pins,indent=2)+'\n')
    build=ROOT/'build';build.mkdir(exist_ok=False)
    binary=build/'admission-audit'
    command=f'''source {shlex.quote(str(SHARED/'swift-toolchain/env.sh'))}
swiftc -parse-as-library -module-cache-path '{RECORDED}/cache' -I '{CORE}' -I '{RECORDED}' -I '{NATIVE}' -L '{RECORDED}' -L '{NATIVE}' -lRecordedNavigationSupport -lNativeDepthPolicySupport '{ROOT}/AdmissionAudit.swift' -o '{binary}'
'''
    started=time.monotonic();compiled=subprocess.run(['bash','-c',command],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=60)
    (ROOT/'compile.log').write_text(compiled.stdout)
    compile_receipt={'exitCode':compiled.returncode,'wallSeconds':time.monotonic()-started,'peakChildRSSKiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,'command':command}
    (ROOT/'COMPILE_RECEIPT.json').write_text(json.dumps(compile_receipt,indent=2)+'\n')
    if compiled.returncode:raise RuntimeError('audit runner compilation failed; no data execution')
    env=dict(os.environ);env['LD_LIBRARY_PATH']=str(NATIVE)+':'+str(RECORDED)+':'+env.get('LD_LIBRARY_PATH','')
    resolved=subprocess.check_output(['ldd',str(binary)],env=env,text=True)
    (ROOT/'resolved-libraries.log').write_text(resolved)
    for name,directory in [('libNativeDepthPolicySupport.so',NATIVE),('libRecordedNavigationSupport.so',RECORDED)]:
        line=next((line for line in resolved.splitlines() if name+' =>' in line),None)
        if line is None or line.split('=>',1)[1].strip().split()[0]!=str(directory/name):raise ValueError('unexpected loaded production/support library')
    started=time.monotonic();run=subprocess.run([str(binary),str(ROOT/'INPUT_MANIFEST.json')],env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=30)
    (ROOT/'runtime.stderr.log').write_text(run.stderr);(ROOT/'production-result.json').write_text(run.stdout)
    if run.returncode:raise RuntimeError(f'production audit failed: {run.returncode}')
    elapsed=time.monotonic()-started;result=json.loads(run.stdout)
    if [r['frameID'] for r in result['results']]!=list(range(8)) or result['pixelStride']!=2:raise ValueError('unexpected production output')
    aggregate={k:0 for k in result['results'][0]['counts']};frames=[]
    for row,source in zip(result['results'],inputs):
        d=np.fromfile(source['depthPath'],dtype='<f4').reshape(source['height'],source['width'])[::2,::2].astype(np.float64)
        c=np.fromfile(source['confidencePath'],dtype=np.uint8).reshape(source['height'],source['width'])[::2,::2]
        high=c==2;finite=np.isfinite(d);admitted=high&finite&(d>=.15)&(d<=5.)
        expected={'attempted':int(d.size),'admitted':int(admitted.sum()),'admittedConversionExact':int(admitted.sum()),
            'rejectedConfidence0':int((c==0).sum()),'rejectedConfidence1':int((c==1).sum()),'rejectedOtherConfidence':int(((c!=0)&(c!=1)&(c!=2)).sum()),
            'rejectedNonfiniteDepth':int((high&~finite).sum()),'rejectedDepthBelowRange':int((high&finite&(d<.15)).sum()),'rejectedDepthAboveRange':int((high&finite&(d>5.)).sum())}
        if expected!=row['counts']:raise ValueError('independent strided cross-check differs from production return')
        for k,v in row['counts'].items():aggregate[k]+=v
        frames.append(row)
    for f in datafiles:
        if digest(f['path'])!=f['sha256']:raise ValueError('input changed during execution')
    if digest(POLICY)!=POLICY_SHA or digest(NATIVE/'libNativeDepthPolicySupport.so')!=LIB_SHA or digest(ROOT/'AdmissionAudit.swift')!=pins['runnerSHA256']:raise ValueError('source/binary changed during execution')
    for entry in [pins['policyModule'],pins['supportBinary']]:
        if digest(entry['path'])!=entry['sha256']:raise ValueError('module/support dependency changed during execution')
    rejected=sum(v for k,v in aggregate.items() if k.startswith('rejected'))
    if aggregate['attempted']!=98304 or aggregate['admitted']+rejected!=98304:raise ValueError('aggregate reconciliation')
    receipt={'scope':'Executed unchanged production acceptedDepth scalar gate on original recorded Float32/confidence; NOT obstacle detection, avoidance, clearance, tracking, localization or navigation',
        'frameCount':8,'frameIDs':list(range(8)),'fullRasterPixels':8*256*192,'attemptedStride2Pixels':98304,'unsampledPixels':8*256*192-98304,
        'aggregate':aggregate,'totalRejected':rejected,'independentCrossCheckMatchesAllFrames':True,
        'dataAndProductionSourceUnchangedDuringRun':True,'Float32BitPatternsPreserved':True,'uint16QuantizationUsed':False,'confidenceFabricated':False,
        'trackingState':'unknown and unused','intrinsicsUsed':False,'worldPoseOrBodyOrFloorUsed':False,'physicalAuthority':False,
        'nativeObservationCreated':False,'obstacleDetectorCalled':False,'navigationRun':False,
        'sourceDataPinsSHA256':digest(ROOT/'SOURCE_DATA_PINS.json'),'protocolSHA256':pins['protocolSHA256'],
        'runnerBinarySHA256':digest(binary),'runnerBinaryBytes':binary.stat().st_size,'runtimeWallSeconds':elapsed,
        'runtimeMeaning':'Linux component runtime, not iPhone sensor-to-warning latency',
        'compile':compile_receipt,'frames':frames}
    (ROOT/'ADMISSION_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps({k:v for k,v in receipt.items() if k not in ('frames','compile')},indent=2))

if __name__=='__main__':main()

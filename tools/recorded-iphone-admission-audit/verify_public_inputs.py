"""Read-only portability/preflight and same-eight recount; never runs Swift/native code."""
from pathlib import Path
import hashlib,importlib.util,json,os,sys
import numpy as np
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parent

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    spec=importlib.util.spec_from_file_location('public_audit_driver',ROOT/'run_audit.py')
    driver=importlib.util.module_from_spec(spec);spec.loader.exec_module(driver)
    def expand(path):
        for prefix,base in [('$WORKSPACE',driver.BASE),('$SHARED',driver.SHARED)]:
            if path.startswith(prefix+'/'):return base/path[len(prefix)+1:]
        raise ValueError('receipt path is not a documented public placeholder')
    pins=json.loads((ROOT/'SOURCE_DATA_PINS.json').read_text())
    checked=[]
    for name in ['policySource','policyBinary','policyModule','actualNativeSamplerSource','supportBinary']:
        item=pins[name];p=expand(item['path'])
        if digest(p)!=item['sha256']:raise ValueError('dependency pin mismatch: '+name)
        checked.append(name)
    if driver.POLICY!=expand(pins['policySource']['path']):raise ValueError('configured policy path mismatch')
    if driver.NATIVE/'libNativeDepthPolicySupport.so'!=expand(pins['policyBinary']['path']):raise ValueError('configured library path mismatch')
    if driver.RECORDED/'libRecordedNavigationSupport.so'!=expand(pins['supportBinary']['path']):raise ValueError('configured support path mismatch')
    if not driver.CORE.is_dir() or not (driver.SHARED/'swift-toolchain/env.sh').is_file():raise ValueError('configured build prerequisite absent')
    if (driver.NATIVE/'NativeDepthObservationPolicy.swift').read_text()!='import BlindCore\n'+driver.POLICY.read_text():raise ValueError('production source adaptation changed')
    if digest(ROOT/'AdmissionAudit.swift')!=pins['runnerSHA256']:raise ValueError('Swift runner changed')
    if digest(ROOT/'PROTOCOL.md')!=pins['protocolSHA256']:raise ValueError('admission protocol changed')
    fieldpath=driver.DATA/'FIELD_DECODE_AUDIT.json'
    if digest(fieldpath)!=pins['originalFieldAuditSHA256']:raise ValueError('private original field receipt changed')
    field=json.loads(fieldpath.read_text())
    if field['selectedFrameIDs']!=list(range(8)) or field['clipSHA256']!=pins['clipSHA256']:raise ValueError('source selection changed')
    if digest(driver.DATA/'EM1-0387.r3d')!=pins['clipSHA256']:raise ValueError('clip hash mismatch')
    for item in pins['dataFiles']:
        p=expand(item['path'])
        if p.stat().st_size!=item['bytes'] or digest(p)!=item['sha256']:raise ValueError('original decoded frame changed')
    result=json.loads((ROOT/'production-result.json').read_text())
    if result['pixelStride']!=2 or [r['frameID'] for r in result['results']]!=list(range(8)):raise ValueError('historical result selection')
    totals={k:0 for k in result['results'][0]['counts']};frames=[]
    for row in result['results']:
        i=row['frameID']
        d=np.fromfile(driver.DATA/'decoded'/f'{i}.depth.f32le',dtype='<f4').reshape(192,256)[::2,::2].astype(np.float64)
        c=np.fromfile(driver.DATA/'decoded'/f'{i}.confidence.u8',dtype=np.uint8).reshape(192,256)[::2,::2]
        high=c==2;finite=np.isfinite(d);admitted=high&finite&(d>=.15)&(d<=5.)
        expected={'attempted':int(d.size),'admitted':int(admitted.sum()),'admittedConversionExact':int(admitted.sum()),
          'rejectedConfidence0':int((c==0).sum()),'rejectedConfidence1':int((c==1).sum()),'rejectedOtherConfidence':int(((c!=0)&(c!=1)&(c!=2)).sum()),
          'rejectedNonfiniteDepth':int((high&~finite).sum()),'rejectedDepthBelowRange':int((high&finite&(d<.15)).sum()),'rejectedDepthAboveRange':int((high&finite&(d>5.)).sum())}
        if expected!=row['counts']:raise ValueError('recount differs from original production result')
        for k,v in expected.items():totals[k]+=v
        frames.append({'frameID':i,'counts':expected})
    receipt=json.loads((ROOT/'ADMISSION_RECEIPT.json').read_text())
    if totals!=receipt['aggregate']:raise ValueError('aggregate mismatch')
    # All input arrays and referenced dependencies are read-only and checked once again.
    for item in pins['dataFiles']+[pins[name] for name in checked]:
        if digest(expand(item['path']))!=item['sha256']:raise ValueError('input changed during verification')
    report={'scope':'Public wrapper path/hash preflight plus read-only independent same-eight-array recount against historical production result; NOT a new native run',
      'checkedDependencyPins':checked,'checkedDecodedFiles':len(pins['dataFiles']),
      'configuredRoots':['$WORKSPACE','$SHARED'],'frameIDs':list(range(8)),'aggregate':totals,
      'matchesOriginalProductionAllFrames':True,'productionRunnerSourceUnchanged':True,'productionPolicySourceUnchanged':True,
      'Float32InputsPreserved':True,'newNativeRun':False,'compilerExecuted':False,'projectionExecuted':False,'navigationExecuted':False,
      'claimLimit':'The modified Python build/launch wrappers received syntax/configuration/hash checks only; their full compile/launch path was not rerun.',
      'verifierSHA256':digest(Path(__file__)),'publicDriverSHA256':digest(ROOT/'run_audit.py'),
      'originalClipSHA256':pins['clipSHA256'],'frames':frames}
    print(json.dumps(report,indent=2))
if __name__=='__main__':main()

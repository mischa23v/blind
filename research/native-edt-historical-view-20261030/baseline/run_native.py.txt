#!/usr/bin/env python3
"""Frozen public Apple-host diagnostic. No install or production-source edits.
Two25-request original controls gate execution of one25-request EDT candidate.
A completed diagnostic may report a failed candidate; job-green is not clearance.
"""
import difflib
import hashlib
import json
import os
import pathlib
import resource
import signal
import struct
import subprocess
import sys
import time

HERE=pathlib.Path(__file__).resolve().parent
ROOT=HERE.parents[2]
REPAIR=HERE.parent
OUT=pathlib.Path(os.environ['RUNNER_TEMP'])/'blind-edt-navigation-probe'
OUT.mkdir(parents=True,exist_ok=False) # Never overwrite retained earlier attempt evidence.
START=time.monotonic();DEADLINE=START+300
receipt={'schema':1,'sourceCommit':os.environ.get('GITHUB_SHA'),'physicalAuthority':False,
         'appActivation':False,'status':'started','commands':[],'sourcePins':{},
         'scope':'macOS fixed public geometry diagnostic; no production/iOS adoption'}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def save():
    receipt['elapsedSeconds']=time.monotonic()-START
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

def limits():
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
    resource.setrlimit(resource.RLIMIT_FSIZE,(128*1024**2,128*1024**2))

def command(args,label,limit=90):
    remaining=DEADLINE-time.monotonic()
    if remaining<=0:
        raise TimeoutError('global diagnostic deadline exhausted before '+label)
    timeout=min(limit,remaining);before=time.monotonic()
    stdout=OUT/(label+'.stdout.txt');stderr=OUT/(label+'.stderr.txt')
    row={'label':label,'command':[str(x) for x in args],'timeoutSeconds':timeout}
    receipt['commands'].append(row);save()
    with stdout.open('xb') as out,stderr.open('xb') as err:
        process=None
        try:
            process=subprocess.Popen([str(x) for x in args],cwd=ROOT,stdout=out,stderr=err,
                start_new_session=True,preexec_fn=limits,
                env={**os.environ,'OMP_NUM_THREADS':'1','OPENBLAS_NUM_THREADS':'1','MKL_NUM_THREADS':'1'})
            row.update(exitCode=process.wait(timeout=timeout),wallSeconds=time.monotonic()-before)
        except BaseException as error:
            # xcrun can own compiler descendants. Kill the entire isolated group,
            # not merely its parent, then reap the child before propagating.
            if process is not None:
                try:
                    os.killpg(process.pid,signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait()
            row.update(exitCode=None,timedOut=isinstance(error,subprocess.TimeoutExpired),
                       interruptedBy=type(error).__name__,wallSeconds=time.monotonic()-before)
            raise
        finally:
            out.flush();err.flush()
            for path in (stdout,stderr):
                row[path.name]={'bytes':path.stat().st_size,'sha256':sha(path)}
            save()
    if row['exitCode']!=0:
        raise RuntimeError('command failed: '+label)
    return stdout.read_text().strip()

def replace_once(text,old,new):
    assert text.count(old)==1,('instrumentation site differs',old)
    return text.replace(old,new,1)

try:
    assert sys.platform=='darwin','Apple host required; no local Swift/native execution'
    assert os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind'
    assert os.environ.get('GITHUB_REF') in ('refs/heads/master','refs/heads/codex/recovery-hazard-order-20261027')
    head=command(['git','rev-parse','HEAD'],'source-head')
    assert head==receipt['sourceCommit']
    before_status=command(['git','status','--porcelain'],'source-before')
    command(['git','diff','--exit-code'],'tracked-source-clean')
    pins=json.loads((HERE/'NATIVE_SOURCE_PINS.json').read_text())['files']
    assert 45<=len(pins)<=100
    for name,digest in pins.items():
        relative=pathlib.PurePosixPath(name)
        assert not relative.is_absolute() and '..' not in relative.parts
        path=ROOT/name
        assert path.is_file() and sha(path)==digest,('source pin mismatch',name)
    receipt['sourcePins']=pins;save()
    def require_pin(path):
        name=str(path.relative_to(ROOT))
        assert name in pins and sha(path)==pins[name],('unreviewed runtime input',name)

    geometry=REPAIR/'strict-endpoint-probe/PACKED_ROUTING_GEOMETRY.json'
    requests=REPAIR/'strict-endpoint-probe/REQUESTS_49A.json'
    masks=HERE/'EDT_MASK_INPUTS.json'
    reference=REPAIR/'native-strict-result-40791907324/RESULT.json'
    c=ROOT/'research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour'
    oracle=ROOT/'ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift'
    appendix=REPAIR/'strict-endpoint-probe/association_appendix.cpp'
    for path in [geometry,requests,masks,reference,HERE/'main.swift',HERE/'run_native.py',
                 HERE/'edt_probe.h',HERE/'edt_mask_hook.cpp',oracle,appendix,
                 HERE/'hook_tests.cpp',HERE/'hook_test_digest.hpp',HERE/'HOOK_TEST_FIXTURE.json',
                 c/'blind_detour_exclusion.cpp',c/'include/blind_detour.h']:
        require_pin(path)
    assert geometry.stat().st_size<=131072 and sha(geometry)=='0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7'
    assert requests.stat().st_size<=131072 and sha(requests)=='e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51'
    assert reference.stat().st_size<=1048576 and sha(reference)=='0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893'
    assert masks.stat().st_size<=1048576
    mask_json=json.loads(masks.read_text())
    assert mask_json['schema']=='blind.fixed-full-layer-edt-masks.v1' and mask_json['physicalAuthority'] is False
    assert mask_json['sourceSurfaceClearanceEstablished'] is False and len(mask_json['profiles'])==6
    hook_fixture=json.loads((HERE/'HOOK_TEST_FIXTURE.json').read_text())
    hook_words=hook_fixture['headerWords']+[v for row in hook_fixture['columns'] for v in row]+[v for row in hook_fixture['spans'] for v in row]
    hook_digest=hashlib.sha256(b''.join(struct.pack('<I',v & 0xffffffff) for v in hook_words)).hexdigest()
    assert hook_digest==hook_fixture['layoutSHA256']=='37b9e02b8b09b02b2e08ebe9c3b825980862078a5b5722bff09a4c0aafbc9f76'
    receipt['authoredHookControlLayoutSHA256']=hook_digest
    receipt['inputHashes']={str(p.relative_to(ROOT)):sha(p) for p in [geometry,requests,masks,reference]}
    save()
    sdk=command(['xcrun','--sdk','macosx','--show-sdk-path'],'sdk')
    version=command(['xcodebuild','-version'],'xcode-version')
    assert version.splitlines()[0]=='Xcode 27.0'
    command(['xcrun','swiftc','--version'],'swift-version')

    include=OUT/'include';include.mkdir()
    (include/'edt_probe.h').write_bytes((HERE/'edt_probe.h').read_bytes())
    (include/'blind_detour.h').write_bytes((c/'include/blind_detour.h').read_bytes())
    (include/'module.modulemap').write_text('module EDTNavigationProbe { header "edt_probe.h" export * }\n')
    common=['xcrun','clang++','-std=c++14','-O1','-ffp-contract=off','-fno-rtti','-fno-exceptions',
            '-fPIC','-isysroot',sdk,'-target','arm64-apple-macosx14.0','-I',c,'-I',c/'include','-I',include,'-I',HERE]
    for component in ['Recast','Detour','DetourCrowd']:
        common+=['-I',c/'upstream'/component/'Include']
        for header in sorted((c/'upstream'/component/'Include').glob('*.h')):
            require_pin(header)
    area_source=c/'upstream/Recast/Source/RecastArea.cpp';require_pin(area_source)
    original_area=area_source.read_text()
    observed_area=replace_once(original_area,'#include "Recast.h"',
        '#include "Recast.h"\nextern "C" void blind_edt_mask_hook(rcCompactHeightfield&,const unsigned char*,int,int);')
    observed_area=replace_once(observed_area,
        '\tconst unsigned char minBoundaryDistance = (unsigned char)(erosionRadius * 2);',
        '\tblind_edt_mask_hook(compactHeightfield,distanceToBoundary,erosionRadius,0);\n'
        '\tconst unsigned char minBoundaryDistance = (unsigned char)(erosionRadius * 2);')
    observed_area=replace_once(observed_area,'\trcFree(distanceToBoundary);',
        '\tblind_edt_mask_hook(compactHeightfield,distanceToBoundary,erosionRadius,1);\n\trcFree(distanceToBoundary);')
    generated_area=OUT/'RecastArea.cpp';generated_area.write_text(observed_area)
    patch=''.join(difflib.unified_diff(original_area.splitlines(True),observed_area.splitlines(True),
                                     fromfile='original/RecastArea.cpp',tofile='scratch/RecastArea.cpp'))
    (OUT/'NATIVE_MASK_INSTRUMENTATION.txt').write_text(patch)
    receipt['instrumentedAreaSHA256']=sha(generated_area);save()
    objects=[]
    for component in ['Recast','Detour','DetourCrowd']:
        for source in sorted((c/'upstream'/component/'Source').glob('*.cpp')):
            require_pin(source)
            selected=generated_area if source==area_source else source
            obj=OUT/(component+'-'+source.stem+'.o')
            command(common+['-c',selected,'-o',obj],'compile-'+component+'-'+source.stem)
            objects.append(obj)
    assert 15<=len(objects)<=64
    original=(c/'blind_detour_exclusion.cpp').read_text()
    assert original.count('config.maxSimplificationError = .5f;')==1
    generated=OUT/'adapter.cpp';generated.write_text(original+'\n'+appendix.read_text())
    receipt['generatedAdapterSHA256']=sha(generated);receipt['maskHookSHA256']=sha(HERE/'edt_mask_hook.cpp');save()
    for source,label in [(generated,'adapter'),(HERE/'edt_mask_hook.cpp','edt-hook')]:
        obj=OUT/(label+'.o');command(common+['-c',source,'-o',obj],'compile-'+label);objects.append(obj)
    library=OUT/'libedtprobe.a'
    command(['xcrun','ar','rcs',library]+objects,'archive')
    hook_binary=OUT/'edt-hook-tests'
    command(common+[HERE/'hook_tests.cpp',library,'-o',hook_binary],'hook-tests-compile')
    hook_result=json.loads(command([hook_binary],'hook-tests-run',30))
    assert hook_result=={'schema':1,'scope':'scratch-edt-hook','checks':51,'passed':51,'physicalAuthority':False}
    receipt['nativeHookChecks']=hook_result;save()
    binary=OUT/'edt-navigation-probe'
    command(['xcrun','swiftc','-j','1','-num-threads','1','-swift-version','5','-parse-as-library',
             '-sdk',sdk,'-target','arm64-apple-macosx14.0','-I',include,HERE/'main.swift',
             oracle,library,'-lc++','-o',binary],'swift-probe-compile',120)
    command([binary,geometry,requests,masks,reference,OUT/'RESULT.json'],'probe-run',120)
    assert (OUT/'RESULT.json').stat().st_size<=1048576
    data=json.loads((OUT/'RESULT.json').read_text())
    assert data['schema']=='blind.public-fixed-full-layer-edt-navigation.v1'
    assert data['physicalAuthority'] is False and data['appActivation'] is False
    assert data['candidateExecuted']==data['all50OriginalControlsReproduced']
    assert data['candidateRequests']==(25 if data['candidateExecuted'] else 0)
    assert len(data['rows'])==50+data['candidateRequests']
    receipt['status']=data['status'];receipt['resultSHA256']=sha(OUT/'RESULT.json')
    receipt['all50OriginalControlsReproduced']=data['all50OriginalControlsReproduced']
    receipt['candidateGoalsMet']=data['candidateGoalsMet']
    after_status=command(['git','status','--porcelain'],'source-after')
    assert before_status==after_status,'diagnostic changed checkout'
    # Only bounded JSON/text receipts are upload candidates, never build products.
    for path in OUT.iterdir():
        if path.suffix in ['.o','.a'] or path in (binary,hook_binary):
            path.unlink()
    save()
    print(json.dumps({'status':receipt['status'],'resultSHA256':receipt['resultSHA256'],
                      'candidateGoalsMet':receipt['candidateGoalsMet'],'physicalAuthority':False}))
except Exception as error:
    receipt['status']='failed-or-inconclusive-diagnostic';receipt['errorType']=type(error).__name__
    receipt['error']=str(error)[:1000];save();raise

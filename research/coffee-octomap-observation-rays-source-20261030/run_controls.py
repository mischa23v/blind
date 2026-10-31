#!/usr/bin/env python3
"""Prepared guarded runner: unchanged original 16 + conservative 22 + observation-only 10 controls.

NOT EXECUTED. A separately reviewed build receipt and external source manifest
check are required. This runner is not a build or held-out-data evaluator.
"""
import os
os.environ['OPENBLAS_NUM_THREADS']='1'
os.environ['OMP_NUM_THREADS']='1'
os.environ['MKL_NUM_THREADS']='1'
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import resource
import signal
import sys
import time
import unittest

ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'coffee-octomap-build-source-20261029'
OLD_TEST_SHA='d1e032ae6be16dbb99255118d1776b0df14ec5c5ffc3271bb47867ed4a434fd5'
OLD_ADAPTER_SHA='715b3e544dff913a82ec43f49c0255297af0c3a799397faceaa66ebe97f9dff7'


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def require(condition,message):
    if not condition:raise ValueError(message)
def load(path,name):
    spec=importlib.util.spec_from_file_location(name,path)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def main():
    p=argparse.ArgumentParser()
    p.add_argument('--library',type=Path,required=True)
    p.add_argument('--expected-library-sha256',required=True)
    p.add_argument('--build-receipt',type=Path,required=True)
    p.add_argument('--expected-build-receipt-sha256',required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--run-native-controls',action='store_true')
    a=p.parse_args()
    require(a.run_native_controls and os.environ.get('COFFEE_RAY_OUTER_GUARD')=='180',
            'explicit native controls admission and 180-second outer guard required')
    require(not a.output.exists(),'refuse replacing output')
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(120,120))
    resource.setrlimit(resource.RLIMIT_FSIZE,(32*1024**2,32*1024**2))
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    require(len(os.sched_getaffinity(0))==1,'one CPU required')
    def stop(_signum,_frame):raise TimeoutError('internal wall limit')
    signal.signal(signal.SIGALRM,stop);signal.alarm(175)
    start=time.monotonic();a.output.mkdir(parents=False)
    record={'status':'incomplete','nativeControlsOnly':True,'physicalAuthority':False,'suites':[]}
    try:
        manifest=json.loads((ROOT/'MANIFEST.json').read_text())
        for entry in manifest['files']:
            path=ROOT/entry['path'];require(path.stat().st_size==entry['bytes'] and sha(path)==entry['sha256'],
                                            'source manifest drift: '+entry['path'])
        require(sha(OLD/'test_octomap_engine.py')==OLD_TEST_SHA,'original controls drift')
        require(sha(OLD/'octomap_adapter.cpp')==OLD_ADAPTER_SHA,'included adapter drift')
        require(a.build_receipt.stat().st_size<=65536,'oversize build receipt')
        require(sha(a.build_receipt)==a.expected_build_receipt_sha256,'unreviewed build receipt')
        b=json.loads(a.build_receipt.read_text())
        require(b['success'] is True and b['exitCode']==0,'build failed or incomplete')
        require(a.library.is_file() and a.library.stat().st_size<=2*1024**2,'missing/oversize library')
        require(b['librarySHA256']==a.expected_library_sha256==sha(a.library),'library drift')
        require(b['adapterTranslationUnitSHA256']==sha(ROOT/'readonly_rays.cpp') and
                b['includedBaselineAdapterSHA256']==OLD_ADAPTER_SHA and
                b['sourceManifestSHA256']==sha(ROOT/'MANIFEST.json'),'wrong build source binding')
        binding=load(ROOT/'ray_binding.py','ray_binding');sys.modules['ray_binding']=binding
        # Same explicit private rebuilt binding pattern as the existing original
        # controls runner. Original wrapper and original tests remain byte-identical.
        base=binding.reviewed_base(a.library,a.expected_library_sha256)
        sys.modules['octomap_engine']=base
        old_tests=load(OLD/'test_octomap_engine.py','unchanged_original_octomap_controls')
        new_tests=load(ROOT/'test_readonly_rays.py','new_readonly_ray_controls')
        new_tests.REVIEWED_LIBRARY=a.library;new_tests.REVIEWED_SHA256=a.expected_library_sha256
        observed_tests=load(ROOT/'test_observation_rays.py','observation_only_controls')
        observed_tests.REVIEWED_LIBRARY=a.library;observed_tests.REVIEWED_SHA256=a.expected_library_sha256
        with (a.output/'controls.log').open('x') as log:
            for name,module,count in [('original',old_tests,16),('read-only-rays',new_tests,22),('observation-only-rays',observed_tests,10)]:
                suite=unittest.defaultTestLoader.loadTestsFromModule(module)
                require(suite.countTestCases()==count,'control inventory changed: '+name)
                result=unittest.TextTestRunner(stream=log,verbosity=2).run(suite)
                record['suites'].append({'name':name,'testsRun':result.testsRun,'expected':count,
                    'failures':len(result.failures),'errors':len(result.errors),'skipped':len(result.skipped),
                    'success':result.wasSuccessful() and result.testsRun==count and not result.skipped})
        require(all(s['success'] for s in record['suites']),'native controls failed')
        for entry in manifest['files']:require(sha(ROOT/entry['path'])==entry['sha256'],'source changed during controls')
        require(sha(a.library)==a.expected_library_sha256,'binary changed during controls')
        record.update(status='completed-controls-only',librarySHA256=a.expected_library_sha256,
                      sourceManifestSHA256=sha(ROOT/'MANIFEST.json'),
                      buildReceiptSHA256=a.expected_build_receipt_sha256)
    except Exception as error:
        record.update(status='failed',failure=type(error).__name__+': '+str(error));raise
    finally:
        record['wallSeconds']=time.monotonic()-start
        u=resource.getrusage(resource.RUSAGE_SELF)
        record['cpuSeconds']=u.ru_utime+u.ru_stime;record['peakRSSKiB']=u.ru_maxrss
        with (a.output/'RESULT.json').open('x') as stream:json.dump(record,stream,indent=2,allow_nan=False);stream.write('\n')
        signal.alarm(0)


if __name__=='__main__':main()

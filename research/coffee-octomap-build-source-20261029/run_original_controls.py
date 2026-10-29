#!/usr/bin/env python3
"""Run unchanged original adapter controls only against explicitly reviewed fresh build.
Never accepts an arbitrary library path. Does not grant Stage B authority by itself.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, resource, sys, unittest
ROOT=Path(__file__).resolve().parent

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def require(ok, why):
    if not ok: raise ValueError(why)
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--expected-build-receipt-sha256', required=True)
    parser.add_argument('--expected-library-sha256', required=True)
    args=parser.parse_args()
    resource.setrlimit(resource.RLIMIT_CPU,(30,30))
    resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3))
    manifest=json.loads((ROOT/'SOURCE_CLOSURE.json').read_text())
    for name,digest in manifest['pinnedLocalFiles'].items():
        require(sha(ROOT/name)==digest,'source changed: '+name)
    receipt_path=ROOT/'build-restored-01/BUILD_RECEIPT.json'
    require(sha(receipt_path)==args.expected_build_receipt_sha256,'unreviewed build receipt')
    receipt=json.loads(receipt_path.read_text())
    require(receipt['success'] is True and receipt['exitCode']==0 and receipt['failure'] is None,
            'build not successful')
    require(receipt['buildVariant']=='restored-20261029-v2-aggregate' and receipt['sourceUnchanged'] is True,
            'wrong source/build variant')
    require(receipt['CPUSeconds']<=120 and receipt['wallSeconds']<=180 and
            receipt['peakSampledOrWaitedTreeRSSBytes']<=1024**3,'build exceeded reviewed budget')
    guard=ROOT/'build-restored-01/GUARD_RUN/RESULT.json'
    require(sha(guard)==receipt['guardReceiptSHA256'] and json.loads(guard.read_text())['status']=='completed-zero-exit','guard receipt drift/failure')
    library=ROOT/'build-restored-01/libblind_octomap.so'
    digest=sha(library)
    require(digest==args.expected_library_sha256==receipt['librarySHA256'],'unreviewed library')
    output=ROOT/'build-restored-01/ORIGINAL_CONTROL_RECEIPT.json'
    require(not output.exists(),'refuse prior control result overwrite')
    wrapper=ROOT/'octomap_engine.py'
    spec=importlib.util.spec_from_file_location('octomap_engine',wrapper)
    engine=importlib.util.module_from_spec(spec);spec.loader.exec_module(engine)
    # Explicit rebuilt variant binding; original wrapper bytes remain unchanged.
    engine.LIBRARY=library
    engine.LIBRARY_SHA256=digest
    sys.modules['octomap_engine']=engine
    spec=importlib.util.spec_from_file_location('original_octomap_controls',ROOT/'test_octomap_engine.py')
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    suite=unittest.defaultTestLoader.loadTestsFromModule(module)
    require(suite.countTestCases()==16,'original control inventory changed')
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    record={'variant':'restored-20261029-v2-aggregate','success':result.wasSuccessful(),
            'testsRun':result.testsRun,'failures':len(result.failures),'errors':len(result.errors),
            'skipped':len(result.skipped),'expectedTests':16,'librarySHA256':digest,
            'buildReceiptSHA256':sha(receipt_path),'sourceClosureSHA256':sha(ROOT/'SOURCE_CLOSURE.json'),
            'physicalAuthority':False,'tableRetentionNotYetRun':True}
    with output.open('x') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    require(record['success'] and record['testsRun']==16 and record['skipped']==0,'original controls failed')
if __name__=='__main__':main()

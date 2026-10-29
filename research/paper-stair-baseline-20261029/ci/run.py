#!/usr/bin/env python3
"""One bounded synthetic SwiftPM verification. No app or empirical sensor inputs."""
import hashlib,importlib.util,json,os,selectors,signal,subprocess,time
from pathlib import Path
HERE=Path(__file__).resolve().parent
PACKAGE=HERE.parent
ROOT=PACKAGE.parents[1]
OUT=Path(os.environ['RUNNER_TEMP'])/'paper-stair-reference'
OUT.mkdir(exist_ok=True)
def require(ok,message):
    if not ok:raise ValueError(message)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True,timeout=20).strip()
def stop_process_group(proc):
    # The parent can exit while descendants still hold stdout; always retire its group.
    try:os.killpg(proc.pid,signal.SIGKILL)
    except ProcessLookupError:pass
    proc.wait(timeout=10)

def pins():
    manifest=PACKAGE/'SOURCE_MANIFEST.json'
    require(hashlib.sha256(manifest.read_bytes()).hexdigest()=='d281d86812fe407a07444c37e88138a0f0fbc51f9718ae4578b41ef3816a1779','unreviewed source manifest')
    expected=json.loads(manifest.read_text())['files_sha256']
    for path,digest in expected.items():require(hashlib.sha256((PACKAGE/path).read_bytes()).hexdigest()==digest,'source pin mismatch: '+path)
    return expected
receipt={'scope':'17 authored synthetic macOS XCTest cases only','appActivation':False,'physicalAuthority':False,'status':'failed','nativeTestsVerified':False}
try:
    receipt['sourceCommit']=git('rev-parse','HEAD')
    require(receipt['sourceCommit']==os.environ['GITHUB_SHA'],'unexpected source commit')
    before=git('status','--porcelain','--untracked-files=all','--',str(PACKAGE.relative_to(ROOT)),'.github/workflows/native-paper-stair-reference.yml')
    require(before=='','dirty baseline')
    receipt['sourcePins']=pins()
    cmd=['xcrun','swift','test','--package-path',str(PACKAGE),'--scratch-path',os.environ['RUNNER_TEMP']+'/paper-stair-build','--build-system','native','--jobs','1']
    receipt['command']=['xcrun','swift','test','--package-path','research/paper-stair-baseline-20261029','--scratch-path','<runner-temp>/paper-stair-build','--build-system','native','--jobs','1']
    started=time.monotonic();proc=subprocess.Popen(cmd,cwd=ROOT,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,start_new_session=True)
    sel=selectors.DefaultSelector();sel.register(proc.stdout,selectors.EVENT_READ);data=bytearray()
    try:
        while sel.get_map():
            if time.monotonic()-started>240:raise TimeoutError('240 second Swift test limit')
            for key,_ in sel.select(1):
                chunk=os.read(key.fd,65536)
                if not chunk:sel.unregister(key.fileobj);continue
                data.extend(chunk)
                require(len(data)<=4*1024*1024,'4 MiB output cap exceeded')
        code=proc.wait(timeout=max(0.001,240-(time.monotonic()-started)))
    finally:
        stop_process_group(proc)
        sel.close()
    receipt['elapsedSeconds']=time.monotonic()-started;receipt['swiftExitCode']=code
    lines=data.decode('utf-8',errors='replace').splitlines()
    records=[line[:2000] for line in lines if line.startswith(('Test Case ', 'Test Suite ', 'Executed ')) or 'error:' in line][:200]
    (OUT/'synthetic-test-records.json').write_text(json.dumps({'sourceCommit':receipt['sourceCommit'],'diagnosticOnly':True,'records':records},indent=2)+'\n')
    after=git('status','--porcelain','--untracked-files=all','--',str(PACKAGE.relative_to(ROOT)),'.github/workflows/native-paper-stair-reference.yml')
    require(pins()==receipt['sourcePins'],'source changed')
    spec=importlib.util.spec_from_file_location('collector',HERE/'collect.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    result=module.collect((PACKAGE/'Tests/PaperStairReferenceTests/ReferenceTests.swift').read_text(),data.decode('utf-8',errors='strict'),{'swift_test_exit_code':code,'log_writer_exit_code':0},before,after)
    (OUT/'xctest-results.json').write_text(json.dumps(result,indent=2)+'\n')
    receipt.update(status='passed',nativeTestsVerified=True,outputSHA256=hashlib.sha256(data).hexdigest())
except Exception as e:
    receipt['error']=str(e)[:1000]
    raise
finally:
    (OUT/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')

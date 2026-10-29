"""Exact flag-only synthetic hosted identities; no live camera, guidance or physical proof."""
import hashlib,importlib.util,json,os,re,sys
from pathlib import Path
sys.dont_write_bytecode=True
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
spec=importlib.util.spec_from_file_location('native_status_reader',H/'export-native-unit-statuses.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
EXPECTED=['SeatedMeshProjectionTests/testIdentityKeepsRawARKitAxesAndMetres', 'SeatedMeshProjectionTests/testColumnMajorRotationTranslationAppliedExactlyOnce', 'SeatedMeshProjectionTests/testEachAnchorUsesItsOwnTransformWithoutFrameSubstitution', 'SeatedMeshProjectionTests/testMalformedNonfiniteAndPerspectiveInputRejectWholeProjection', 'SeatedMeshProjectionTests/testWholeProjectionRejectsVertexBudgetAndFloatOverflow', 'SeatedMeshProjectionTests/testDoubleLocalValuesCanCancelBeforeBoundedFloatProjection', 'SeatedMeshProjectionTests/testRouteMustMatchExactCurrentSourceSessionGenerationAndRevision', 'SeatedMeshProjectionTests/testConfirmationIsExactSingleUseAndRetiresOnStopOrViewReplacement', 'SeatedMeshProjectionTests/testStopKeepsOwnerUntilNativeAndHeldRendererBothDrain', 'SeatedMeshProjectionTests/testMainDeliveryCannotReleaseOwnerBeforeWorkerClosureReturns']

def require(value,message):
    if not value:raise ValueError(message)

def collect(cases,summary,log,command,source):
    names=re.findall(r'^\s*(?:@MainActor\s+)?func (test\w+)\(',source,re.M)
    require(['SeatedMeshProjectionTests/'+n for n in names]==EXPECTED,'exact reviewed10 fixture source required')
    require(source.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n'),'fixture must remain flag-only')
    require(type(command.get('exit_code')) is int and command['exit_code']==0,'focused native command failed or unavailable')
    counts=native.reconcile(cases,summary)
    require(len(cases)==10 and {x['identifier'].removesuffix('()') for x in cases}==set(EXPECTED),'missing/extra/duplicate focused identities')
    require(all(x['result']=='Passed' for x in cases),'failed/skipped focused fixture')
    require(len(log.encode())<=64*1024*1024,'bounded test log required')
    events={}
    pattern=r"Test Case '-\[(?:BlindAssistTests\.)?SeatedMeshProjectionTests (test\w+)\]' (started|passed|failed|skipped)(?:\.| \([0-9]+(?:\.[0-9]+)? seconds\)\.)"
    for line in log.splitlines():
        if not line.startswith('Test Case '):continue
        match=re.fullmatch(pattern,line)
        require(match is not None,'unexpected hosted test line/class')
        name,status=match.groups();events.setdefault('SeatedMeshProjectionTests/'+name,[]).append(status)
    require(events=={n:['started','passed'] for n in EXPECTED},'missing/extra/duplicate/failed/skipped exact log witnesses')
    return {'status':'passed','scope':'10 flag-only synthetic hosted fixtures; no live sensing or physical authority','executed':10,'counts':counts,'cases':cases,'logWitnesses':events,'commandExit':0}

def main():
    out=Path(sys.argv[1]);result={'status':'unavailable','complete':False,'source_verified':False,'expected_commit':os.environ.get('GITHUB_SHA')}
    try:
        before=native.provenance(ROOT,os.environ.get('GITHUB_SHA'))
        bundle=out/'diagnostics-unit.xcresult';raw=native.query(['xcrun','xcresulttool','get','test-results','tests','--path',str(bundle),'--compact']);cases=native.cases_from(json.loads(raw))
        summary=json.loads(native.query(['xcrun','xcresulttool','get','test-results','summary','--path',str(bundle),'--compact']))
        log=out/'diagnostics-unit.log';require(log.stat().st_size<=64*1024*1024,'log exceeds64MiB');command=json.loads((out/'diagnostics-unit-exit.json').read_text())
        source=ROOT/'ios/BlindAssistTests/SeatedMeshProjectionTests.swift'
        result.update(collect(cases,summary,log.read_text(errors='replace'),command,source.read_text()))
        after=native.provenance(ROOT,os.environ.get('GITHUB_SHA'));require(before==after,'source identity changed during collection')
        result.update(complete=True,source_verified=True,source_commit=before['actual_head'],provenance=before,querySHA256=hashlib.sha256(raw).hexdigest(),fixtureSHA256=hashlib.sha256(source.read_bytes()).hexdigest())
    except (OSError,ValueError,RecursionError, __import__('subprocess').SubprocessError) as error:
        result.update(status='unavailable',complete=False,source_verified=False,error_type=type(error).__name__,error=str(error)[:256])
    (out/'seated-projection-results.json').write_text(json.dumps(result,indent=2)+'\n');print('SEATED_PROJECTION_RESULTS='+json.dumps(result,separators=(',',':')))
    return 0 if result['complete'] else 1
if __name__=='__main__':raise SystemExit(main())

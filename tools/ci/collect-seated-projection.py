"""Exact flag-only synthetic hosted identities; no live camera, guidance or physical proof."""
import hashlib,importlib.util,json,os,re,sys
from pathlib import Path
sys.dont_write_bytecode=True
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
spec=importlib.util.spec_from_file_location('native_status_reader',H/'export-native-unit-statuses.py');native=importlib.util.module_from_spec(spec);spec.loader.exec_module(native)
PROJECTION_EXPECTED=['SeatedMeshProjectionTests/testIdentityKeepsRawARKitAxesAndMetres', 'SeatedMeshProjectionTests/testColumnMajorRotationTranslationAppliedExactlyOnce', 'SeatedMeshProjectionTests/testEachAnchorUsesItsOwnTransformWithoutFrameSubstitution', 'SeatedMeshProjectionTests/testMalformedNonfiniteAndPerspectiveInputRejectWholeProjection', 'SeatedMeshProjectionTests/testWholeProjectionRejectsVertexBudgetAndFloatOverflow', 'SeatedMeshProjectionTests/testDoubleLocalValuesCanCancelBeforeBoundedFloatProjection', 'SeatedMeshProjectionTests/testRouteMustMatchExactCurrentSourceSessionGenerationAndRevision', 'SeatedMeshProjectionTests/testConfirmationIsExactSingleUseAndRetiresOnStopOrViewReplacement', 'SeatedMeshProjectionTests/testStopKeepsOwnerUntilNativeAndHeldRendererBothDrain', 'SeatedMeshProjectionTests/testMainDeliveryCannotReleaseOwnerBeforeWorkerClosureReturns', 'SeatedMeshProjectionTests/testDeclaredFootUsesActualStrictQueryAndHistoricalDisplayWithoutFrameRebinding', 'SeatedMeshProjectionTests/testHeldControllerResultCannotPublishAfterExplicitReplacementOrSourceChange', 'SeatedMeshProjectionTests/testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld', 'SeatedMeshProjectionTests/testActualAuditRetirementAndDisposalAfterRealOracleProgress', 'SeatedMeshProjectionTests/testMappedDestinationFeedsActualStrictQueryAndCollisionReceipt', 'SeatedMeshProjectionTests/testMappedDestinationRefusesMissingWrongStaleAndCrossFloorAssociation', 'SeatedMeshProjectionTests/testMappedDestinationRetiresHeldResultsOnRestartMapGoalAndSourceChanges']

COLLISION_EXPECTED=['SeatedCollisionBridgeTests/testCrossingTableAndClearRouteUseRealOracleWithMixedRoleIdentity', 'SeatedCollisionBridgeTests/testMarginIsSeparateAndRequestedGoalConnectorRetainsContact', 'SeatedCollisionBridgeTests/testUnknownRoleNoDeletionAndZeroLengthHeightAssociation', 'SeatedCollisionBridgeTests/testRetiredOrOverBudgetNeverProducesEmptyClearResult']
NORMAL_OWNER_EXPECTED=['NormalOwnerMeshConnectionTests/testIncompleteInventoryAndAggregateBoundsNeverBecomeEmptyClearSource', 'NormalOwnerMeshConnectionTests/testReorderedFutureWrongSessionAndExpiredFrameCannotIssueQuery', 'NormalOwnerMeshConnectionTests/testActualFullSourceStrictQueryAndAuditKeepFrozenRequestAcrossOrdinaryFrames', 'NormalOwnerMeshConnectionTests/testThirtyTwoSequentialAnchorCopiesPreserveHistoricalAgeAndFreshFrameLease', 'NormalOwnerMeshConnectionTests/testActualAuditGoalRetirementAndStopWaitForOperationDisposal']
EXPECTED=PROJECTION_EXPECTED+COLLISION_EXPECTED+NORMAL_OWNER_EXPECTED

def require(value,message):
    if not value:raise ValueError(message)

def verify_fixture_source(source, expected, class_name):
    names=re.findall(r'^\s*(?:@MainActor\s+)?func\s+(test\w+)\s*\(',source,re.M)
    require([class_name+'/'+n for n in names]==expected,'exact reviewed fixture source required for '+class_name)
    require(re.findall(r'^\s*(?:final\s+)?class\s+(\w+)\s*:\s*XCTestCase\s*\{',source,re.M)==[class_name],'exact hosted XCTest class required')
    require(source.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n'),'fixture must remain flag-only')

def console_evidence(log):
    """Secondary transport evidence, never a replacement for xcresult cases.

    Missing/partial stdout is not a failed test. Recognized contradictions still
    fail closed. Emit only allowlisted identities and closed scalar categories.
    """
    raw=log.encode()
    require(len(raw)<=64*1024*1024,'bounded test log required')
    events={};violations={}
    def violation(reason):violations[reason]=violations.get(reason,0)+1
    pattern=r"Test Case '-\[(?:BlindAssistTests\.)?(SeatedMeshProjectionTests|SeatedCollisionBridgeTests|NormalOwnerMeshConnectionTests) (test\w+)\]' (started|passed|failed|skipped)(?:\.| \([0-9]+(?:\.[0-9]+)? seconds\)\.)"
    for line in log.splitlines():
        if not line.startswith('Test Case '):continue
        if len(line.encode())>4096:
            violation('oversize_case_record');continue
        match=re.fullmatch(pattern,line)
        if match is None:
            violation('unrecognized_case_record');continue
        class_name,name,status=match.groups();identity=class_name+'/'+name
        if identity not in EXPECTED:
            violation('unexpected_case_identity');continue
        history=events.setdefault(identity,[])
        if len(history)<3:history.append(status)
        else:violation('excess_case_records')
    for history in events.values():
        if 'failed' in history or 'skipped' in history:violation('failed_or_skipped_case')
        if history not in [['started'],['passed'],['started','passed']]:violation('duplicate_or_contradictory_sequence')
    missing=[name for name in EXPECTED if name not in events]
    partial=[name for name in EXPECTED if name in events and events[name]!=['started','passed']]
    status='contradictory' if violations else 'not_observed' if not events else 'incomplete' if missing or partial else 'complete'
    return {'status':status,'authority':'secondary_console_diagnostic','logBytes':len(raw),
            'logSHA256':hashlib.sha256(raw).hexdigest(),'events':events,'missing':missing,
            'partial':partial,'violations':violations}


def collect(cases,summary,log,command,source,collision_source,normal_source):
    verify_fixture_source(source,PROJECTION_EXPECTED,'SeatedMeshProjectionTests')
    verify_fixture_source(collision_source,COLLISION_EXPECTED,'SeatedCollisionBridgeTests')
    verify_fixture_source(normal_source,NORMAL_OWNER_EXPECTED,'NormalOwnerMeshConnectionTests')
    require(type(command.get('exit_code')) is int and command['exit_code']==0,'focused native command failed or unavailable')
    counts=native.reconcile(cases,summary)
    require(len(cases)==26 and {x['identifier'].removesuffix('()') for x in cases}==set(EXPECTED),'missing/extra/duplicate focused identities')
    require(all(x['result']=='Passed' for x in cases),'failed/skipped focused fixture')
    # Counts and the summary's overall outcome must agree. No outcome inference
    # from console visibility, a zero Swift Testing suite, or collector success.
    require(summary.get('result')=='Passed','focused xcresult summary must report Passed')
    require('testFailures' not in summary or summary['testFailures']==[], 'xcresult summary contains failure records')
    console=console_evidence(log)
    require(not console['violations'],'contradictory or unsupported console case evidence')
    return {'status':'passed','scope':'26 flag-only synthetic hosted fixtures (original21 plus5 normal-owner full-source cases); no live sensing or physical authority','executed':26,'counts':counts,'cases':cases,
            'evidenceAuthority':'exact-source-xcresult-tests-and-summary-with-command-exit',
            'logWitnesses':console['events'],'consoleEvidence':console,'commandExit':0}

def main():
    out=Path(sys.argv[1]);result={'status':'unavailable','complete':False,'source_verified':False,'expected_commit':os.environ.get('GITHUB_SHA')}
    try:
        before=native.provenance(ROOT,os.environ.get('GITHUB_SHA'))
        bundle=out/'diagnostics-unit.xcresult';raw=native.query(['xcrun','xcresulttool','get','test-results','tests','--path',str(bundle),'--compact']);cases=native.cases_from(json.loads(raw))
        summary_raw=native.query(['xcrun','xcresulttool','get','test-results','summary','--path',str(bundle),'--compact']);summary=json.loads(summary_raw)
        log=out/'diagnostics-unit.log';require(log.stat().st_size<=64*1024*1024,'log exceeds64MiB');command=json.loads((out/'diagnostics-unit-exit.json').read_text())
        source=ROOT/'ios/BlindAssistTests/SeatedMeshProjectionTests.swift'
        collision_source=ROOT/'ios/BlindAssistTests/SeatedCollisionBridgeTests.swift'
        normal_source=ROOT/'ios/BlindAssistTests/NormalOwnerMeshConnectionTests.swift'
        log_text=log.read_text(errors='replace')
        result['consoleEvidence']=console_evidence(log_text)
        result.update(collect(cases,summary,log_text,command,source.read_text(),collision_source.read_text(),normal_source.read_text()))
        after=native.provenance(ROOT,os.environ.get('GITHUB_SHA'));require(before==after,'source identity changed during collection')
        result.update(complete=True,source_verified=True,source_commit=before['actual_head'],provenance=before,querySHA256=hashlib.sha256(raw).hexdigest(),summarySHA256=hashlib.sha256(summary_raw).hexdigest(),fixtureSHA256=hashlib.sha256(source.read_bytes()).hexdigest(),collisionFixtureSHA256=hashlib.sha256(collision_source.read_bytes()).hexdigest(),normalOwnerFixtureSHA256=hashlib.sha256(normal_source.read_bytes()).hexdigest())
    except (OSError,ValueError,KeyError,TypeError,RecursionError, __import__('subprocess').SubprocessError) as error:
        result.update(status='unavailable',complete=False,source_verified=False,error_type=type(error).__name__,error=str(error)[:256])
    (out/'seated-projection-results.json').write_text(json.dumps(result,indent=2)+'\n');print('SEATED_PROJECTION_RESULTS='+json.dumps(result,separators=(',',':')))
    return 0 if result['complete'] else 1
if __name__=='__main__':raise SystemExit(main())

#!/usr/bin/env python3
"""Portable source/CI invariants only; no Apple execution or runtime safety claim."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import sys

H = Path(__file__).resolve().parent
R = H.parents[2]
checks = []
def check(name, value):
    assert value, name
    checks.append(name)
def j01_portable_failure(script, result):
    """Closed metadata from fixed synthetic test stderr, never raw text/environment."""
    if result.returncode == 0:
        return True
    raw = result.stderr or b''
    if isinstance(raw, bytes):
        raw = raw[-16384:].decode('utf-8', 'replace')
    records = []
    for line in raw[-16384:].splitlines()[-96:]:
        test = re.match(r'^(ERROR|FAIL): (test_[A-Za-z0-9_]{1,120})(?: |$)', line)
        if test:
            records.append({'kind': test[1], 'test': test[2]})
        else:
            error = re.match(r'^(ValueError|AssertionError|FileNotFoundError|PermissionError|OSError|RuntimeError|TypeError|KeyError):(?: |$)', line)
            if error:
                record = {'errorType': error[1]}
                if line == 'ValueError: symlink component refused':
                    record['reason'] = 'symlink_component_refused'
                records.append(record)
        if len(records) == 24:
            break
    print('J01_PORTABLE_FAILURE=' + json.dumps({'script': script, 'returncode': result.returncode, 'stderrTailBytesExamined': min(len(raw.encode('utf-8')), 16384), 'records': records}, separators=(',', ':')))
    return False

manifest = json.loads((H / 'SOURCE_PINS.json').read_text())
for name, digest in manifest['integrated'].items():
    check('integrated pin ' + name, hashlib.sha256((R / name).read_bytes()).hexdigest() == digest)
# Fresh-frame failed delivery retries retain actual current anchor installation.
# Historical source and all older reversal proofs remain immutable.
pre_normal_delivery_source={}
with tempfile.TemporaryDirectory(prefix='stage85-normal-delivery-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeNormalOwnerDeliveryRetry'])+manifest['normalOwnerDeliveryRetryNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(R/name,target)
    subprocess.run(['git','apply','-R',str(H/'normal-owner-delivery-retry-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeNormalOwnerDeliveryRetry'].items():
        value=(root/name).read_bytes()
        check('exact source before normal-owner delivery retry '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_normal_delivery_source[name]=value
    for name in manifest['normalOwnerDeliveryRetryNewFiles']:
        check('new delivery retry file absent before repair '+name,not (root/name).exists())
delivery_current=(R/'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift').read_text()
check('readonly delivery getter preserves all prior runtime bytes '+'research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift',delivery_current.count('    /// Read-only latest-revision delivery metadata from the existing runtime.\n    /// The owner lock keeps reset/stop from mixing epochs; no geometry is exposed.\n    public var anchorDeliveryReceipts: [MeshAnchorDeliveryReceipt] {\n        locked { stopped ? [] : runtime.anchorDeliveryReceipts }\n    }\n')==1 and delivery_current.replace('    /// Read-only latest-revision delivery metadata from the existing runtime.\n    /// The owner lock keeps reset/stop from mixing epochs; no geometry is exposed.\n    public var anchorDeliveryReceipts: [MeshAnchorDeliveryReceipt] {\n        locked { stopped ? [] : runtime.anchorDeliveryReceipts }\n    }\n','',1).encode()==pre_normal_delivery_source['research/mesh-candidate-ingress-83/Sources/MeshCandidateIngress.swift'])
delivery_current=(R/'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift').read_text()
check('readonly delivery getter preserves all prior runtime bytes '+'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift',delivery_current.count(' }\n /// Bounded copied delivery bookkeeping only. No geometry, capture freshness,\n /// footprint support or route authority. A pending copy is not an installed copy.\n public var anchorDeliveryReceipts: [MeshAnchorDeliveryReceipt] {\n  locked {\n   guard !stopped,deliveryPolicy == .latestValidatedAnchorRevision else{return []}\n   return deliveryView().receipts\n  }\n')==1 and delivery_current.replace(' }\n /// Bounded copied delivery bookkeeping only. No geometry, capture freshness,\n /// footprint support or route authority. A pending copy is not an installed copy.\n public var anchorDeliveryReceipts: [MeshAnchorDeliveryReceipt] {\n  locked {\n   guard !stopped,deliveryPolicy == .latestValidatedAnchorRevision else{return []}\n   return deliveryView().receipts\n  }\n','',1).encode()==pre_normal_delivery_source['research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift'])

# Fixed dependency resolution precedes strict build begin; all checks remain.
# Historical source and all older reversal proofs remain immutable.
pre_j01_resolution_source=dict(pre_normal_delivery_source)
with tempfile.TemporaryDirectory(prefix='stage85-j01-resolution-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeJ01ResolutionPreparation'])+manifest['j01ResolutionPreparationNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_normal_delivery_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'j01-resolution-preparation-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeJ01ResolutionPreparation'].items():
        value=(root/name).read_bytes()
        check('exact source before J01 resolution preparation '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_j01_resolution_source[name]=value
    for name in manifest['j01ResolutionPreparationNewFiles']:
        check('new J01 resolution file absent before repair '+name,not (root/name).exists())
resolution_runner=(R/'tools/ci/j01-actual-model.py').read_text()
resolution_sites=[('', "def resolve_argv(folder):\n # Same fixed project/scheme and owned DerivedData; no caller-supplied package input.\n return build_argv(folder)[:-1]+['-resolvePackageDependencies']\n"), ("FAILURE_STAGES=frozenset(('checkout_before_build', 'attestation_begin', 'build_command', 'descriptor_selection', 'checkout_after_build', 'attestation_finish', 'receipt_write', 'receipt_digest', 'attestation_verify', 'script_selection', 'script_observations'))\n", "FAILURE_STAGES=frozenset(('dependency_preflight','dependency_resolution','checkout_before_build', 'attestation_begin', 'build_command', 'descriptor_selection', 'checkout_after_build', 'attestation_finish', 'receipt_write', 'receipt_digest', 'attestation_verify', 'script_selection', 'script_observations'))\n"), ('', "  stage='dependency_preflight'\n  attestation.source_provenance(R,ctx['GITHUB_SHA']) # Strict source and exact-lock validation before resolution.\n  stage='dependency_resolution'\n  resolution=command(resolve_argv(out),out/'resolve.log',180,16*1024*1024)\n  report['resolutionCommandExit']=resolution['exit_code'];report['resolutionCommandReason']=resolution['reason']\n  require(good(resolution),'fixed package resolution failed')\n  # The first resolution may create the two already-allowlisted exact public\n  # locks. Freeze only AFTER resolution; actual build equality remains strict.\n")]
for old,new in reversed(resolution_sites):
    check('exact current bounded resolution site '+str(len(old)),resolution_runner.count(new)==1)
    resolution_runner=resolution_runner.replace(new,old,1)
check('all other J01 runner semantics preserved around resolution',resolution_runner.encode()==pre_j01_resolution_source['tools/ci/j01-actual-model.py'])

# Closed J01 failure stage diagnostics preserve strict acceptance and privacy.
# Original runner semantics and all older reversal proofs remain immutable.
pre_j01_closed_source=dict(pre_j01_resolution_source)
with tempfile.TemporaryDirectory(prefix='stage85-j01-closed-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeJ01ClosedFailureDiagnostics'])+manifest['j01ClosedFailureDiagnosticsNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_j01_resolution_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'j01-closed-failure-diagnostics-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeJ01ClosedFailureDiagnostics'].items():
        value=(root/name).read_bytes()
        check('exact source before J01 closed diagnostics '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_j01_closed_source[name]=value
    for name in manifest['j01ClosedFailureDiagnosticsNewFiles']:
        check('new J01 closed diagnostics file absent before repair '+name,not (root/name).exists())
import ast
j01_runner_path='tools/ci/j01-actual-model.py'
class Strip(ast.NodeTransformer):
 def visit_FunctionDef(self,node):
  if node.name=='safe_failure':return None
  return self.generic_visit(node)
 def visit_Assign(self,node):
  if len(node.targets)==1 and isinstance(node.targets[0],ast.Name) and node.targets[0].id in ('stage','FAILURE_STAGES','ATTESTATION_FAILURE_CODES'):return None
  return node
 def visit_Expr(self,node):
  if isinstance(node.value,ast.Call) and isinstance(node.value.func,ast.Attribute) and isinstance(node.value.func.value,ast.Name) and node.value.func.value.id=='report' and node.value.func.attr=='update' and len(node.value.args)==1 and isinstance(node.value.args[0],ast.Call) and isinstance(node.value.args[0].func,ast.Name) and node.value.args[0].func.id=='safe_failure':return None
  return node
check('current J01 runner original semantics unchanged after diagnostics',ast.dump(Strip().visit(ast.parse(pre_j01_resolution_source[j01_runner_path].decode())),include_attributes=False)==ast.dump(ast.parse(pre_j01_closed_source[j01_runner_path].decode()),include_attributes=False))

# Compose current reviewed contact diagnostics into the strict historical EDT view.
# Historical source and all older reversal proofs remain immutable.
pre_edt_contact_source=dict(pre_j01_closed_source)
with tempfile.TemporaryDirectory(prefix='stage85-edt-contact-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeEDTViewContactComposition'])+manifest['edtViewContactCompositionNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_j01_closed_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'edt-view-contact-composition-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeEDTViewContactComposition'].items():
        value=(root/name).read_bytes()
        check('exact source before EDT contact composition '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_edt_contact_source[name]=value
    for name in manifest['edtViewContactCompositionNewFiles']:
        check('new EDT contact file absent before repair '+name,not (root/name).exists())

# Six XCTest required-goal UUID unwraps repair the recorded933 compile error.
# Current source is checked mechanically; reversal preserves all prior evidence.
pre_journey_goal_source=dict(pre_edt_contact_source)
with tempfile.TemporaryDirectory(prefix='stage85-journey-goal-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeJourneyRequiredGoalUnwrap'])+manifest['journeyRequiredGoalUnwrapNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_edt_contact_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'journey-required-goal-unwrap-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeJourneyRequiredGoalUnwrap'].items():
        value=(root/name).read_bytes()
        check('exact source before required goal unwrap '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_journey_goal_source[name]=value
    for name in manifest['journeyRequiredGoalUnwrapNewFiles']:
        check('new goal unwrap file absent before repair '+name,not (root/name).exists())
goal_test_path='ios/BlindAssistTests/ConnectedJourneyRuntimeTests.swift'
goal_test=(R/goal_test_path).read_text()
goal_old='goalRevision: context.goalRevision))'
goal_new='goalRevision: try XCTUnwrap(context.goalRevision)))'
check('six required goal unwraps fail nil without fabricated identity',goal_test.count(goal_new)==6 and goal_old not in goal_test)
check('all other journey test bytes preserved',goal_test.replace(goal_new,goal_old).encode()==pre_journey_goal_source[goal_test_path])
check('all27 original journey native methods retained',len(re.findall(r'func (test\w+)',goal_test))==27)

# Authored collision-contact addendum and strict optional evidence collector.
# Current checks inspect final R; exact reversal is historical provenance only.
pre_collision_contact_source=dict(pre_journey_goal_source)
with tempfile.TemporaryDirectory(prefix='stage85-collision-contact-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeCollisionContactPhase'])+manifest['collisionContactPhaseNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_journey_goal_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'collision-contact-phase-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeCollisionContactPhase'].items():
        value=(root/name).read_bytes()
        check('exact source before collision contact addendum '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_collision_contact_source[name]=value
    for name in manifest['collisionContactPhaseNewFiles']:
        check('new collision contact file absent before addendum '+name,not (root/name).exists())
check('current contact source original cases cleanup retention bounds and negative mutations',subprocess.run([sys.executable,'-B',str(R/'tools/test/collision-contact-addendum.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)
check('current strict contact evidence collector all original and additive controls',subprocess.run([sys.executable,'-B',str(R/'tools/ci/test-native-route-diagnostic-evidence.py')],cwd=R,capture_output=True,timeout=30).returncode==0)

# Two classification families share one exact acknowledged test owner.
# Reverse only for historical proofs; current controls inspect actual final R.
pre_classification_family_source=dict(pre_collision_contact_source)
with tempfile.TemporaryDirectory(prefix='stage85-classification-family-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeClassificationCrossFamilyDrain'])+manifest['classificationCrossFamilyDrainNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_collision_contact_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'classification-cross-family-drain-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeClassificationCrossFamilyDrain'].items():
        value=(root/name).read_bytes()
        check('exact source before classification cross-family drain '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_classification_family_source[name]=value
    for name in manifest['classificationCrossFamilyDrainNewFiles']:
        check('new cross-family file absent from preceding source '+name,not (root/name).exists())
check('current cross-family exact native ownership identities assertions budgets and negative controls',subprocess.run([sys.executable,'-B',str(R/'tools/test/classification-fixture-drain.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)

# Raw-depth accounting is a separate additive input-integrity layer.
# Reverse only for historical proofs; current controls always inspect actual R.
pre_depth_raster_source=dict(pre_classification_family_source)
with tempfile.TemporaryDirectory(prefix='stage85-depth-raster-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeDepthRasterIntegrity'])+manifest['depthRasterIntegrityNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_classification_family_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'depth-raster-integrity-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeDepthRasterIntegrity'].items():
        value=(root/name).read_bytes()
        check('exact source before depth raster integrity '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_depth_raster_source[name]=value
    for name in manifest['depthRasterIntegrityNewFiles']:
        check('new depth integrity file absent from preceding source '+name,not (root/name).exists())
check('current raw depth integrity source and arithmetic controls',subprocess.run([sys.executable,'-B',str(R/'research/depth-raster-integrity-20261030/source_check.py'),str(R)],cwd=R,capture_output=True,timeout=15).returncode==0)
depth_expected_methods=['testUnknownEvidenceDoesNotDiscardObservedGeometry', 'testOpticalConventionsCannotSilentlyMix', 'testFullRotationAndInversePreserveTiltAndTranslation', 'testScaleShearReflectionAndNonfinitePoseRejected', 'testIntrinsicsScaleUsesImageAndDepthResolution', 'testLowAndMissingConfidenceRemainHistoryNotUncertainty', 'testMissingDepthAndTrackingLossStillRetainAttributedPoseHistory', 'testStaleFutureOrMissingNativeReceiptRejected', 'testRecordedClockNeverBecomesDeviceUptime', 'testMapTargetDoesNotReframeCoordinatesOrProvideFloor', 'testPlaneFloorClassificationIsNotFloorIdentityOrSupportPermit', 'testBadMeshIndicesAndUndeclaredTruncationRejected', 'testBadDepthPixelsAndDuplicatePixelsRejected', 'testHistorySurvivesRestartWithoutRestoringAuthority', 'testCachedRecordSizeAndBytesDoNotChangeOnLaterAppend', 'testDuplicateAndOutOfOrderCallbacksCannotRewriteHistory', 'testHistoryBoundEvictionIsExplicitNotCompleteInventory', 'testMalformedArchiveAndSchemaRejected', 'testMalformedEvictionCounterRejectedWithoutOverflowTrap', 'testDepthAccountingRejectsHugeInvalidCountWithoutOverflow', 'testDepthAccountingRejectsImpossibleInvalidRasterCoverage', 'testDepthAccountingUsesCeilingStrideCapacityAndAllowsSparseSubsets', 'testDepthAccountingRejectsNegativeAndOverBudgetCounts']
check('current depth native exact19 retained plus4 unrun identities',re.findall(r'func\s+(test\w+)\s*\(', (R/'BlindCore/Tests/BlindCoreTests/NativeObservationTests.swift').read_text())==depth_expected_methods)

# UI contrast source and test-only J01 root identity form an additive outer layer.
# Current controls inspect final R; only historical provenance uses the reversal.
pre_ui_j01_source=dict(pre_depth_raster_source)
with tempfile.TemporaryDirectory(prefix='stage85-ui-j01-fixture-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeRepeatAnswerJ01Fixture'])+manifest['repeatAnswerJ01FixtureNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_depth_raster_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'repeat-answer-j01-fixture-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeRepeatAnswerJ01Fixture'].items():
        value=(root/name).read_bytes()
        check('exact before UI contrast and J01 fixture '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_ui_j01_source[name]=value
    for name in manifest['repeatAnswerJ01FixtureNewFiles']:
        check('new UI or J01 fixture file absent before outer layer '+name,not (root/name).exists())
check('current Repeat answer unchanged action disabled gate audit and negative controls',subprocess.run([sys.executable,'-B',str(R/'tools/test/repeat-answer-contrast.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)
check('current adjacent accessible Ask and voice continuity contracts',subprocess.run([sys.executable,'-B',str(R/'tools/test/accessibility-voice-continuity.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)
ui_expected_methods=['testMainScreenContainsOnlyReplyAndTabButtons', 'testReadingAndConversationControlsAreReachableInSettings', 'testQuietDescriptionsCanResumeWithoutStartingMicrophoneOrCamera', 'testAskControlsAndUnavailableReasonRemainReachableWithoutCamera', 'testRoomsShowSavedRoomsAndExplicitStartScan', 'testWritingIsAvailableWithoutMicrophoneCapture', 'testAssistantPreferencesAndConversationMemoryRemainReachable', 'testPhotoExplorerCanBeDismissedWithoutStartingCamera', 'testSettingsAndWearableSetupAreReachable', 'testPracticeNavigationRemainsReachable', 'testPracticeIsAnnouncedAndCanStop', 'testAccessibleMainModesAndOfflineDefault', 'testDescribeFocusAndStopControl', 'testPracticeLayoutAtDefaultSize', 'testPracticeLayoutAtLargestAccessibilitySize', 'testAccessibilityAuditOfMainScreen', 'testAccessibilityAuditOfCameraAndAsk', 'testOfflineCommunityLibraryKeepsLocalImportAvailable', 'testEmptyInterestDoesNotBecomeStoredPreference']
check('current UI exact original nineteen method identities retained',re.findall(r'\bfunc\s+(test\w+)\s*\(', (R/'ios/BlindAssistUITests/LaunchTests.swift').read_text())==ui_expected_methods)
check('J01 production attestation unchanged by fixture repair',hashlib.sha256((R/'research/j01-hosted-app-adapter-20261030/build_attestation.py').read_bytes()).hexdigest()=='9aa53907c305bbb0472bdf773c0110f8a5b77801994300333980056ea7c3f3ff')
check('J01 production runner unchanged by fixture repair',hashlib.sha256(pre_j01_closed_source['tools/ci/j01-actual-model.py']).hexdigest()=='c595872182c53fc7ce27de4bc6e77d15228148300120913c3ad4cd4b390ff11f')


# Seated same-family fixture ownership and the floor audit are an additive layer.
# Reverse only in a temporary tree; current owner controls below inspect final R.
pre_owned_drain_source=dict(pre_ui_j01_source)
with tempfile.TemporaryDirectory(prefix='stage85-seated-owned-drain-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeSeatedOwnedDrainFloorAudit'])+manifest['seatedOwnedDrainFloorAuditNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_ui_j01_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-owned-drain-floor-audit-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSeatedOwnedDrainFloorAudit'].items():
        value=(root/name).read_bytes()
        check('exact source37 before seated fixture drain '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_owned_drain_source[name]=value
    for name in manifest['seatedOwnedDrainFloorAuditNewFiles']:
        check('new seated or research file absent from source37 '+name,not (root/name).exists())
check('current real full-controller seated fixture drain and negative controls',subprocess.run([sys.executable,'-B',str(R/'tools/test/seated-fixture-drain.test.py')],cwd=R,capture_output=True,timeout=15).returncode==0)
seated_owner_pins=json.loads((R/'research/seated-fixture-owned-drain-20261030/SOURCE_PINS.json').read_text())
for family in ['source','unchangedDependencies']:
    for name,digest in seated_owner_pins[family].items():
        check('seated ownership baseline '+family+' pin '+name,hashlib.sha256(pre_normal_delivery_source.get(name,(R/name).read_bytes())).hexdigest()==digest)
# Reuse the existing strict collector's exact original17+collision4+normal-owner5
# source identities. This is NOT an xcresult or a new native execution receipt.
import importlib.util
collector_spec=importlib.util.spec_from_file_location('seated_current_collector',R/'tools/ci/collect-seated-projection.py')
collector=importlib.util.module_from_spec(collector_spec);collector_spec.loader.exec_module(collector)
for cls,names in [('SeatedMeshProjectionTests',collector.PROJECTION_EXPECTED),('SeatedCollisionBridgeTests',collector.COLLISION_EXPECTED),('NormalOwnerMeshConnectionTests',collector.NORMAL_OWNER_EXPECTED)]:
    collector.verify_fixture_source((R/('ios/BlindAssistTests/'+cls+'.swift')).read_text(),names,cls)
    check('current strict focused class identity '+cls,True)
check('current focused source remains17plus4plus5 no new methods',[len(collector.PROJECTION_EXPECTED),len(collector.COLLISION_EXPECTED),len(collector.NORMAL_OWNER_EXPECTED)]==[17,4,5])
floor_audit=subprocess.run([sys.executable,'-B',str(R/'research/live-floor-support-gap-20261030/audit.py'),'--repo',str(R)],cwd=R,capture_output=True,text=True,timeout=15)
check('current floor support research exact source audit',floor_audit.returncode==0)
check('floor source audit reproduces immutable research-only result',json.loads(floor_audit.stdout)==json.loads((R/'research/live-floor-support-gap-20261030/RESULTS.json').read_text()))

# Restore exact reviewed86 bytes only for historical provenance. Current source
# gates below still read R and cannot pass against this recovered historical tree.
pre_local_map_source=dict(pre_owned_drain_source)
with tempfile.TemporaryDirectory(prefix='stage85-local-map-pipeline-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeLocalMapPipeline'])+manifest['localMapPipelineNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_owned_drain_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'local-map-pipeline-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeLocalMapPipeline'].items():
        value=(root/name).read_bytes()
        check('exact reviewed86 before local-map pipeline '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_local_map_source[name]=value
    for name in manifest['localMapPipelineNewFiles']:
        check('local-map continuation new file absent from reviewed86 '+name,not (root/name).exists())
check('current local-map pipeline source and exact authored identities',subprocess.run([sys.executable,'-B',str(R/'tools/test/local-map-pipeline-current.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)
check('current interrupted-portal producer consumer contracts',subprocess.run([sys.executable,'-B',str(R/'tools/test/connected-portal-recovery.test.py'),'--root',str(R)],cwd=R,capture_output=True,timeout=15).returncode==0)
check('current exact ARSession and normal-camera ownership guards',subprocess.run(['node','--test','--test-concurrency=1',str(R/'tools/test/saved-frame-camera-association.test.mjs')],cwd=R,capture_output=True,timeout=15).returncode==0)

# Carry only the published Boolean repair over the exact frozen future layers.
# This temporary reversal is historical provenance, never current behavior.
pre_beacon_carry_source=dict(pre_local_map_source)
with tempfile.TemporaryDirectory(prefix='stage85-published-beacon-carry-') as temp:
    root=Path(temp)
    for name in manifest['beforePublishedBeaconRepairCarry']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_local_map_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'published-beacon-repair-carry.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforePublishedBeaconRepairCarry'].items():
        value=(root/name).read_bytes();check('exact frozen83 before published Boolean carry '+name,hashlib.sha256(value).hexdigest()==digest);pre_beacon_carry_source[name]=value
check('current beacon Boolean contract and negative controls',subprocess.run([sys.executable,'-B',str(R/'tools/test/connected-beacon-bool.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)

# Third source integration restores exact reviewed J0117 before old layers.
# Current production contracts continue to read R, never these restored bytes.
pre_third_source=dict(pre_beacon_carry_source)
with tempfile.TemporaryDirectory(prefix='stage85-third-tracker-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeThirdTrackerImplementation'])+manifest['thirdTrackerImplementationNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_beacon_carry_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'tracker-third-implementation-batch.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeThirdTrackerImplementation'].items():
        value=(root/name).read_bytes()
        check('exact pre-third-batch input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_third_source[name]=value
    for name in manifest['thirdTrackerImplementationNewFiles']:
        check('new third-batch input absent from parent '+name,not (root/name).exists())

# Explicit J01 lane restores exact NEXT40 before any historical reversal.
# Its current portable controls below still read the actual current checkout R.
pre_j01_source=dict(pre_third_source)
with tempfile.TemporaryDirectory(prefix='stage85-j01-lane-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeJ01SameJobObservation'])+manifest['j01SameJobObservationNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_third_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'j01-same-job-observation-layer.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeJ01SameJobObservation'].items():
        value=(root/name).read_bytes()
        check('exact pre-J01-lane input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_j01_source[name]=value
    for name in manifest['j01SameJobObservationNewFiles']:
        check('new J01-lane input absent from NEXT40 '+name,not (root/name).exists())

# Second implementation batch restores the exact frozen first-batch inputs.
# Current contracts still read R; restored bytes are only historical provenance.
pre_second_tracker_source=dict(pre_j01_source)
with tempfile.TemporaryDirectory(prefix='stage85-second-tracker-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeSecondTrackerImplementationBatch'])+manifest['secondTrackerImplementationBatchNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_j01_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'tracker-second-implementation-batch.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSecondTrackerImplementationBatch'].items():
        value=(root/name).read_bytes()
        check('exact first-batch input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_second_tracker_source[name]=value
    for name in manifest['secondTrackerImplementationBatchNewFiles']:
        check('new second-batch input absent from first batch '+name,not (root/name).exists())

# Independently reproduce the exact published ff0 repair from recovered failed119.
# Its immutable original patch/checkpoint stay unchanged. This side proof then
# reverses back to failed119, leaving the main frozen historical chain untouched.
published_repair=manifest['publishedBeaconBoolRepair']
repair_checkpoint_bytes=(R/published_repair['checkpoint']).read_bytes()
check('published repair checkpoint bytes unchanged',hashlib.sha256(repair_checkpoint_bytes).hexdigest()==published_repair['checkpointSHA256'])
repair_checkpoint=json.loads(repair_checkpoint_bytes)
repair_rows={row['path']:row for row in repair_checkpoint['files']}
repair_patch=H/'beacon-bool-compile-repair.patch'
check('published repair original patch unchanged',hashlib.sha256(repair_patch.read_bytes()).hexdigest()==published_repair['originalPatchSHA256'])
with tempfile.TemporaryDirectory(prefix='stage85-published-ff0-proof-') as temp:
    root=Path(temp)
    for name,digest in manifest['beforeBeaconBoolCompileRepair'].items():
        value=pre_second_tracker_source[name]
        check('failed119 published-repair preimage '+name,hashlib.sha256(value).hexdigest()==digest and repair_rows[name]['beforeSHA256']==digest)
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(value)
    for name in manifest['beaconBoolCompileRepairNewFiles']:
        check('published repair new control was absent in failed119 '+name,repair_rows[name]['beforeSHA256'] is None and not (root/name).exists())
    subprocess.run(['git','apply',str(repair_patch)],cwd=root,check=True,timeout=15,capture_output=True)
    for name in list(manifest['beforeBeaconBoolCompileRepair'])+manifest['beaconBoolCompileRepairNewFiles']:
        value=(root/name).read_bytes()
        check('exact published ff0 repair identity '+name,len(value)==repair_rows[name]['bytes'] and hashlib.sha256(value).hexdigest()==repair_rows[name]['sha256'])
    subprocess.run(['git','apply','-R',str(repair_patch)],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeBeaconBoolCompileRepair'].items():
        check('published repair proof restored failed119 '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
    for name in manifest['beaconBoolCompileRepairNewFiles']:
        check('published repair proof removed later control '+name,not (root/name).exists())

# Restore the exact post-map source before historical assertions. This layer
# intentionally changes current production behavior; no earlier pass is relabelled.
pre_tracker_implementation_source=dict(pre_second_tracker_source)
with tempfile.TemporaryDirectory(prefix='stage85-tracker-implementation-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeTrackerImplementationBatch'])+manifest['trackerImplementationBatchNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_second_tracker_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'tracker-implementation-batch.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeTrackerImplementationBatch'].items():
        value=(root/name).read_bytes()
        check('exact pre-tracker-implementation input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_tracker_implementation_source[name]=value
    for name in manifest['trackerImplementationBatchNewFiles']:
        check('new tracker implementation input absent from prior layer '+name,not (root/name).exists())

# Mapped-destination consumer retains the exact reviewed QoS/exporter base.
pre_mapped_destination_source=dict(pre_tracker_implementation_source)
with tempfile.TemporaryDirectory(prefix='stage85-mapped-destination-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeMappedDestination'])+manifest['mappedDestinationNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_tracker_implementation_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-mapped-destination-layer.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeMappedDestination'].items():
        value=(root/name).read_bytes()
        check('exact pre-mapped-destination input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_mapped_destination_source[name]=value
    for name in manifest['mappedDestinationNewFiles']:
        check('new mapped destination input absent from prior layer '+name,not (root/name).exists())

# Restore normal scheduling source before checking earlier acceptance evidence.
pre_qos_comparison_source=dict(pre_mapped_destination_source)
with tempfile.TemporaryDirectory(prefix='stage85-qos-comparison-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeQoSComparison'])+manifest['qosComparisonNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_mapped_destination_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'native-qos-comparison-layer.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeQoSComparison'].items():
        value=(root/name).read_bytes()
        check('exact pre-QoS-comparison input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_qos_comparison_source[name]=value
    for name in manifest['qosComparisonNewFiles']:
        check('new QoS comparison input absent from prior layer '+name,not (root/name).exists())

# Preserve actual e418 harness and runtime failures before repairing expectation ownership.
pre_expectation_owner_source=dict(pre_qos_comparison_source)
with tempfile.TemporaryDirectory(prefix='stage85-expectation-owner-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeExpectationOwnershipRepair'])+manifest['expectationOwnershipRepairNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_qos_comparison_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-expectation-ownership-repair.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeExpectationOwnershipRepair'].items():
        value=(root/name).read_bytes()
        check('exact e418 expectation input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_expectation_owner_source[name]=value
    for name in manifest['expectationOwnershipRepairNewFiles']:
        check('new expectation input absent from earlier layer '+name,not (root/name).exists())

# Preserve the failed 7bb preflight and historical-source boundary explicitly.
pre_apple_preflight_source=dict(pre_expectation_owner_source)
with tempfile.TemporaryDirectory(prefix='stage85-apple-preflight-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeApplePreflightEDTRepair'])+manifest['applePreflightEDTRepairNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_expectation_owner_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'apple-preflight-historical-edt-repair.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeApplePreflightEDTRepair'].items():
        value=(root/name).read_bytes()
        check('exact failed preflight input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_apple_preflight_source[name]=value
    for name in manifest['applePreflightEDTRepairNewFiles']:
        check('new preflight input absent from earlier layer '+name,not (root/name).exists())

# Isolated collision-adapter adoption retains every earlier source/evidence layer.
pre_collision_bridge_source=dict(pre_apple_preflight_source)
with tempfile.TemporaryDirectory(prefix='stage85-independent-collision-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeIndependentCollisionBridge'])+manifest['independentCollisionBridgeNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_apple_preflight_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-independent-collision-bridge.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeIndependentCollisionBridge'].items():
        value=(root/name).read_bytes()
        check('exact pre-independent-collision input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_collision_bridge_source[name]=value
    for name in manifest['independentCollisionBridgeNewFiles']:
        check('new collision adapter absent from earlier layer '+name,not (root/name).exists())

# Preserve the published readiness fixture while fixing XCTest single-wait ownership.
pre_single_wait_source=dict(pre_collision_bridge_source)
with tempfile.TemporaryDirectory(prefix='stage85-single-wait-') as temp:
    root=Path(temp)
    for name in manifest['beforeSingleWaitFixtureRepair']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_collision_bridge_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-single-wait-fixture-repair.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSingleWaitFixtureRepair'].items():
        value=(root/name).read_bytes()
        check('exact pre-single-wait fixture input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_single_wait_source[name]=value

# Source-readiness correction preserves every earlier source/visual-failure layer.
pre_readiness_source=dict(pre_single_wait_source)
with tempfile.TemporaryDirectory(prefix='stage85-source-readiness-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeSourceReadinessSplit'])+manifest['sourceReadinessSplitNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_single_wait_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-source-readiness-split.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSourceReadinessSplit'].items():
        value=(root/name).read_bytes()
        check('exact pre-source-readiness input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_readiness_source[name]=value
    for name in manifest['sourceReadinessSplitNewFiles']:
        check('new readiness source absent from earlier layer '+name,not (root/name).exists())

# Room-mesh defaults to log receipts without remote artifact storage.
pre_roommesh_storage_source = dict(pre_readiness_source)
with tempfile.TemporaryDirectory(prefix='stage85-roommesh-storage-') as temp:
    root=Path(temp)
    for name in manifest['beforeRoommeshNoArtifact']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_readiness_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'roommesh-no-artifact-layer.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeRoommeshNoArtifact'].items():
        value=(root/name).read_bytes()
        check('exact pre-roommesh-storage source '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_roommesh_storage_source[name]=value

# Preserve the second Apple failure while layering synthetic source-delivery clocks.
pre_source_delivery_source = dict(pre_roommesh_storage_source)
with tempfile.TemporaryDirectory(prefix='stage85-source-delivery-metadata-') as temp:
    root = Path(temp)
    for name in manifest['beforeSourceDeliveryDiagnostics']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(pre_roommesh_storage_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-source-delivery-diagnostics.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSourceDeliveryDiagnostics'].items():
        value=(root/name).read_bytes()
        check('exact pre-source-delivery input '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_source_delivery_source[name]=value

# The first Apple run exposed a fixture setup failure, not a production defect.
# Restore its published failing inputs before reversing the original candidate layer.
pre_fixture_repair_source = dict(pre_source_delivery_source)
with tempfile.TemporaryDirectory(prefix='stage85-source-fixture-repair-') as temp:
    root = Path(temp)
    for name in list(manifest['beforeExpectedSourceFixtureRepair']) + manifest['expectedSourceFixtureRepairNewFiles']:
        target = root/name; target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(pre_source_delivery_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-expected-source-fixture-repair.patch')],cwd=root,
                   check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeExpectedSourceFixtureRepair'].items():
        value = (root/name).read_bytes()
        check('exact failing fixture source recovered '+name,hashlib.sha256(value).hexdigest()==digest)
        pre_fixture_repair_source[name] = value
    for name in manifest['expectedSourceFixtureRepairNewFiles']:
        check('new fixture metadata extractor absent in historical layer '+name,not (root/name).exists())

# Restore the exact prior source before checking historical layers. This new
# candidate/CI layer is reversible provenance, not execution or safety evidence.
pre_candidate_source = dict(pre_fixture_repair_source)
with tempfile.TemporaryDirectory(prefix='stage85-body-foot-source-') as temp:
    root = Path(temp)
    for name in list(manifest['beforeBodyFootCandidate']) + manifest['bodyFootCandidateNewFiles']:
        target = root / name; target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(pre_fixture_repair_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'seated-body-foot-candidate-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name,digest in manifest['beforeBodyFootCandidate'].items():
        value = (root/name).read_bytes()
        check('exact pre-body-foot source recovered '+name, hashlib.sha256(value).hexdigest()==digest)
        pre_candidate_source[name] = value
    for name in manifest['bodyFootCandidateNewFiles']:
        check('new body-foot source absent in historical layer '+name, not (root/name).exists())

# Recover the exact pre-diagnostics source in scratch before every historical layer.
pre_diagnostics_source=dict(pre_candidate_source)
with tempfile.TemporaryDirectory(prefix='stage85-diagnostics-source-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeSyntheticDiagnostics'])+manifest['syntheticDiagnosticsNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_candidate_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'synthetic-diagnostics-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSyntheticDiagnostics'].items():
        check('exact pre-synthetic-diagnostics source recovered '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
        pre_diagnostics_source[name]=(root/name).read_bytes()
    for name in manifest['syntheticDiagnosticsNewFiles']:
        check('new synthetic diagnostics helper absent in historical layer '+name,not (root/name).exists())

# New optional envelope/source-test layer reverses exactly before historical policy checks.
pre_envelope_source={}
with tempfile.TemporaryDirectory(prefix='stage85-envelope-source-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeEnvelopeSource'])+manifest['envelopeSourceNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_diagnostics_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'envelope-source-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeEnvelopeSource'].items():
        check('exact pre-envelope source recovered '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
        pre_envelope_source[name]=(root/name).read_bytes()
    for name in manifest['envelopeSourceNewFiles']:
        check('new envelope dependency absent from historical source '+name,not (root/name).exists())

# Recover the exact prior ingress/collector bytes in scratch only; historical layers remain intact.
with tempfile.TemporaryDirectory(prefix='stage85-snapshot-') as temp:
    root = Path(temp)
    for name in manifest['beforeImmutableSnapshot']:
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(pre_candidate_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git', 'apply', '-R', str(H / 'seated-viewer-collector-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSeatedViewerCollector'].items():
        check('exact pre-seated-viewer collector recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'anchor-delivery-recovery-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeAnchorDeliveryRecovery'].items():
        check('exact pre-anchor-delivery-recovery source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'immutable-snapshot-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeImmutableSnapshot'].items():
        check('exact pre-immutable-snapshot source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)

# Optional exact-seed-radius policy is a new reversible layer, not a historical pin bypass.
with tempfile.TemporaryDirectory(prefix='stage85-exact-seed-policy-') as temp:
    root=Path(temp)
    for name in list(manifest['beforeExactSeedRadiusPolicy'])+manifest['exactSeedRadiusPolicyNewFiles']:
        target=root/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(pre_envelope_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'exact-seed-radius-policy-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeExactSeedRadiusPolicy'].items():
        check('exact pre-seed-radius policy recovered '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
    for name in manifest['exactSeedRadiusPolicyNewFiles']:
        check('new seed-radius private helper absent in historical layer '+name,not (root/name).exists())

# The authorized CI metadata extraction is a separate reversible helper layer.
# Recover the exact prior helper before assessing unchanged build-mode contracts.
with tempfile.TemporaryDirectory(prefix='stage85-ci-helper-') as temp:
    root = Path(temp)
    for name in dict.fromkeys(list(manifest['beforeSceneTimingHelper']) + list(manifest['beforeSeatedViewerCI']) + manifest['seatedViewerCINewFiles'] + list(manifest['beforeExactSeedRadiusCI']) + manifest['exactSeedRadiusCINewFiles'] + manifest['seedRadiusFocusedEvidenceNewFiles'] + list(manifest['beforeEnvelopeCI'])):
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(pre_diagnostics_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git','apply','-R',str(H/'envelope-ci-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    pre_envelope_ci={}
    for name,digest in manifest['beforeEnvelopeCI'].items():
        check('exact pre-envelope CI recovered '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
        pre_envelope_ci[name]=(root/name).read_text()
    subprocess.run(['git','apply','-R',str(H/'seed-radius-focused-evidence-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeSeedRadiusFocusedEvidence'].items():
        check('exact pre-focused-evidence source recovered '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
    for name in manifest['seedRadiusFocusedEvidenceNewFiles']:
        check('new focused evidence helper absent in historical layer '+name,not (root/name).exists())
    subprocess.run(['git','apply','-R',str(H/'exact-seed-radius-ci-layer.patch')],cwd=root,check=True,timeout=15,capture_output=True)
    for name,digest in manifest['beforeExactSeedRadiusCI'].items():
        check('exact pre-seed-radius CI recovered '+name,hashlib.sha256((root/name).read_bytes()).hexdigest()==digest)
    for name in manifest['exactSeedRadiusCINewFiles']:
        check('new seed-radius collector absent in historical layer '+name,not (root/name).exists())
    subprocess.run(['git', 'apply', '-R', str(H / 'seated-viewer-ci-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSeatedViewerCI'].items():
        check('exact pre-seated-viewer CI recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    for name in manifest['seatedViewerCINewFiles']:
        check('new seated-viewer CI absent in historical layer ' + name, not (root / name).exists())
    pre_seated_helper = (root / 'tools/ci/native-apple.sh').read_text()
    pre_seated_workflow = (root / '.github/workflows/native-apple.yml').read_text()
    subprocess.run(['git', 'apply', '-R', str(H / 'model-authority-core-identity-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeModelAuthorityCoreIdentityHelper'].items():
        check('exact pre-model-authority-core-identity helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'worker-cpu-ci-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeWorkerCPUHelper'].items():
        check('exact pre-worker-CPU helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'ingress-timing-ci-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeIngressTimingHelper'].items():
        check('exact pre-ingress-timing CI helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'classified-timing-ci-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeClassifiedTimingHelper'].items():
        check('exact pre-classified-timing CI helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'recorder-timing-ci-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeRecorderTimingHelper'].items():
        check('exact pre-recorder-timing CI helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'scene-timing-ci-helper.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSceneTimingHelper'].items():
        check('exact pre-scene-timing CI helper recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
# Reverse canonical project serialization, practice presentation, then both mesh layers in a disposable THREE-FILE copy only.
# Preserve the original stage85 patch and verify its published intermediate bytes.
with tempfile.TemporaryDirectory(prefix='stage85-integrated-') as temp:
    root = Path(temp)
    for name in dict.fromkeys(manifest['appFiles'] + list(manifest['beforeGuidanceAuthority']) + manifest['guidanceAuthorityNewFiles'] + list(manifest['beforeSeatedViewerApp']) + manifest['seatedViewerAppNewFiles']):
        target = root / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(pre_candidate_source.get(name,(R/name).read_bytes()))
    subprocess.run(['git', 'apply', '-R', str(H / 'seated-viewer-app-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSeatedViewerApp'].items():
        check('exact pre-seated-viewer app source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    for name in manifest['seatedViewerAppNewFiles']:
        check('new seated-viewer app source absent in historical layer ' + name, not (root / name).exists())
    pre_seated_nav = (root / 'ios/BlindAssist/NavigationModel.swift').read_text()
    pre_seated_project = (root / 'ios/BlindAssist.xcodeproj/project.pbxproj').read_text()
    subprocess.run(['git', 'apply', '-R', str(H / 'guidance-authority-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeGuidanceAuthority'].items():
        check('exact pre-guidance-authority source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    for name in manifest['guidanceAuthorityNewFiles']:
        check('new guidance-authority source absent in historical layer ' + name, not (root / name).exists())
    subprocess.run(['git', 'apply', '-R', str(H / 'conversation-runtime-failure-layer.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeConversationRuntimeFailure'].items():
        check('exact pre-conversation-runtime source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'strict-endpoint-test-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeStrictEndpointTestMembership'].items():
        check('exact pre-strict-endpoint test project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'practice-runtime-diagnostic.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforePracticeRuntimeDiagnostic'].items():
        check('exact pre-practice-runtime source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'hosted-decoder-link-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeHostedDecoderLinkMembership'].items():
        check('exact pre-hosted-decoder-link project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'classification-ingress-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeClassificationIngressMembership'].items():
        check('exact pre-classification-ingress project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'apple-room-route-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeAppleRoomRouteMembership'].items():
        check('exact pre-Apple-room-route project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'apple-roomplan-fixture-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeAppleRoomPlanFixtures'].items():
        check('exact pre-Apple-fixture project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'saved-room-geometry-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSavedRoomGeometry'].items():
        check('exact pre-saved-room-geometry source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'saved-frame-camera-association.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeSavedFrameCameraAssociation'].items():
        check('exact pre-saved-frame-association source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'navigation-test-recording.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeNavigationTestRecording'].items():
        check('exact pre-navigation-test-recording source recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'connected-bench-preview-membership.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeConnectedBenchPreviewMembership'].items():
        check('exact pre-connected-bench-preview project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'project-canonicalization.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeProjectCanonicalization'].items():
        check('exact pre-canonical project recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H / 'practice-publication.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforePracticePublication'].items():
        check('exact pre-practice integration recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    pre_practice_nav = (root / 'ios/BlindAssist/NavigationModel.swift').read_text()
    subprocess.run(['git', 'apply', '-R', str(H / 'critical-order.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['beforeCriticalOrder'].items():
        check('exact published stage85 recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    subprocess.run(['git', 'apply', '-R', str(H.parent / 'app-integration.patch')], cwd=root,
                   check=True, timeout=15, capture_output=True)
    for name, digest in manifest['originalApp'].items():
        check('exact original recovered ' + name, hashlib.sha256((root / name).read_bytes()).hexdigest() == digest)
    check('bridge absent in original', not (root / 'ios/BlindAssist/MeshCandidateDiagnostics.swift').exists())
    original_nav = (root / 'ios/BlindAssist/NavigationModel.swift').read_text()
historical_bridge = pre_third_source['ios/BlindAssist/MeshCandidateDiagnostics.swift'].decode()
bridge = historical_bridge
current_bridge = (R / 'ios/BlindAssist/MeshCandidateDiagnostics.swift').read_text()
# Historical critical-order contracts below run on exact recovered pre-viewer bytes.
# Current default behavior and new diagnostic ownership are checked separately below.
current_nav = (R / 'ios/BlindAssist/NavigationModel.swift').read_text()
# These new contracts inspect actual production source/project and all original
# fixture identities. Native compile, model and physical acceptance remain open.
for script in ['tools/test/normal-owner-mesh-current.test.py',
               'tools/test/local-email-draft-companion.test.py',
               'tools/ci/test_normal_owner_project.py']:
    check('current third-batch portable contract '+script,subprocess.run([sys.executable,'-B',str(R/script)],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=20).returncode==0)
check('current SC53 thirty source contracts',subprocess.run([sys.executable,'-B',str(R/'tools/test/sc53-current-source.py'),'--root',str(R)],cwd=R,capture_output=True,timeout=20).returncode==0)
check('current bounded familiar-photo import contracts',subprocess.run(['node','--test','--test-concurrency=1',str(R/'tools/test/familiar-photo-import-bounds.test.mjs'),str(R/'tools/test/familiar-people.test.mjs')],cwd=R,capture_output=True,timeout=20).returncode==0)
check('current normal-owner remains compile-gated and default off',current_bridge.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n') and 'private(set) var enabled = false' in current_bridge and 'UserDefaults' not in current_bridge)

# Same-job provenance/metadata controls are portable synthetic tests, not an
# Apple build or an observed actual-model run. Only explicit workflow executes.
for script in ['research/j01-hosted-app-adapter-20261030/test_build_attestation.py',
               'tools/ci/test_j01_actual_model.py',
               'tools/ci/test_collect_j01_metadata.py',
               'tools/ci/test_j01_portable_failure_diagnostic.py']:
    check('current J01 same-job portable contract '+script,j01_portable_failure(script,subprocess.run([sys.executable,'-B',str(R/script)],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R),'BLIND_SOURCE_REPO':str(R)},capture_output=True,timeout=20)))

# Additional actual-current source contracts; opt-in real-model execution is not
# invoked by these portable controls or by ordinary hosted fixture selection.
for script in ['tools/test/classified-hit-current.test.py',
               'tools/test/classification-fixture-drain.test.py',
               'tools/test/conversation-failure-diagnostics.test.py',
               'tools/test/local-recipe-companion.test.py',
               'research/j01-hosted-app-adapter-20261030/test_adapter.py',
               'tools/ci/test_j01_project_membership.py']:
    check('current second-batch portable contract '+script,subprocess.run([sys.executable,'-B',str(R/script)],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=20).returncode==0)
check('current bounded room-photo import contracts',subprocess.run(['node','--test','--test-concurrency=1',str(R/'tools/test/room-photo-import-bounds.test.mjs')],cwd=R,capture_output=True,timeout=15).returncode==0)

# Implementation contracts below read actual current production bytes, never the
# recovered historical view. They are portable source checks, not native passes.
check('current navigation seventy implementation contracts',subprocess.run([sys.executable,str(R/'tools/test/navigation-integration-current.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)
check('current voice continuity contracts and negative mutations',subprocess.run([sys.executable,str(R/'tools/test/accessibility-voice-continuity.test.py')],cwd=R,env={**__import__('os').environ,'BLIND_SOURCE_ROOT':str(R)},capture_output=True,timeout=15).returncode==0)
check('current captured-photo frame and absence contracts',subprocess.run(['node','--test',str(R/'tools/test/captured-photo-retention.test.mjs'),str(R/'tools/test/scene-frame-provenance.test.mjs'),str(R/'tools/test/visual-absence-contract.test.mjs')],cwd=R,capture_output=True,timeout=15).returncode==0)

nav = pre_seated_nav
project = pre_seated_project
check('historical counters-only bridge exact reviewed proposal', bridge == (H.parent / 'proposal/MeshCandidateDiagnostics.swift').read_text())
check('historical counters-only bridge compile fence', bridge.startswith('#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n') and bridge.endswith('#endif\n'))
check('historical counters-only default off and not persisted', 'private(set) var enabled = false' in bridge and 'UserDefaults' not in bridge)
check('historical counters-only no copy or geometry ingest', not any(x in bridge for x in ['.ingest(', '.copy(', '.geometry', 'ARMeshAnchor', 'MTLBuffer']))
check('historical counters-only terminal discard', 'terminal = true; enabled = false' in bridge and 'guard !terminal' in bridge)
check('historical counters-only no geometry output or guidance', not any(x in bridge for x in ['route(', 'speak(', 'guidance', 'ARSession()']))
check('existing main callback ownership', 'session.delegateQueue = .main' in nav)
check('flag not in default project settings', 'BLIND_MESH_CANDIDATE_DIAGNOSTICS' not in project)
production = '\n'.join(p.read_text() for p in (R / 'ios/BlindAssist').glob('*.swift'))
check('current exact explicit normal-owner enable seam', len(re.findall(r'\bsetMeshCandidateDiagnosticsEnabled\s*\(', production)) == 2 and 'set: { model.setMeshCandidateDiagnosticsEnabled($0) }' in (R/'ios/BlindAssist/DashboardView.swift').read_text())
check('historical counters-only enable declaration', sum(len(re.findall(r'\bsetMeshCandidateDiagnosticsEnabled\s*\(', pre_third_source.get(str(p.relative_to(R)),p.read_bytes()).decode())) for p in (R/'ios/BlindAssist').glob('*.swift')) == 1)
# These blocks contain no nested compiler directives. Removing only this exact
# feature fence from the recovered pre-practice layer must recover the entire
# historical default NavigationModel. The separate exact patch binds later changes.
without_mesh = re.sub(r'(?m)^[ \t]*#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\n(?:(?!^[ \t]*#(?:if|endif)\b)[\s\S])*?^[ \t]*#endif\n', '', pre_practice_nav)
check('flag absent pre-practice navigation exactly preserves original', without_mesh == original_nav)
def body(signature):
    start = nav.index(signature)
    opening = nav.index('{', start + len(signature))
    depth = 0
    for index in range(opening, len(nav)):
        depth += (nav[index] == '{') - (nav[index] == '}')
        if depth == 0:
            return nav[opening + 1:index]
    raise AssertionError('Unclosed declaration: ' + signature)
normalize = lambda value: re.sub(r'\s+', ' ', value).strip()
hook = '#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS\nmeshCandidateDiagnostics.stop()\n#endif'
for label, signature, prefix in [
    ('camera stop', 'private func stopCameraMonitoring()', 'nativeObservations.stop()\nvoiceRoomScan.cancel()\nretireBodyWarning(publishChange: false)\nwithObservedScene { $0.stop() }'),
    ('session interruption', 'func sessionWasInterrupted(_ session: ARSession)', 'guard session === self.session else { return }\nplaces.invalidateWorldMapRecovery()\nretireBodyWarning(publishChange: false)\nnativeObservations.stop()\nwithObservedScene { $0.stop() }')]:
    check(label + ' critical retirement precedes optional diagnostics and pause',
          normalize(body(signature)).startswith(normalize(prefix + '\n' + hook + '\ncameraRecovery.pause()')))
failure = normalize(body('func session(_ session: ARSession, didFailWithError error: Error)'))
check('failure retires authority before optional diagnostics and recovery',
      failure.startswith(normalize('guard session === self.session else { return }\nplaces.invalidateWorldMapRecovery()\nretireBodyWarning(publishChange: false)\nnativeObservations.stop()\nwithObservedScene { $0.stop() }')) and
      failure.endswith(normalize('indoor.invalidatePosition()\npublish()\n' + hook + '\nrequestCameraRecovery(now: ProcessInfo.processInfo.systemUptime)')))
frame = body('func session(_ session: ARSession, didUpdate frame: ARFrame)')
check('frame exact ARSession guard precedes all work', normalize(frame).startswith('guard session === self.session else { return }'))
check('pre-throttle tracking association hook precedes existing evidence retirement',
      frame.index('places.observeWorldMapTrackingInterruption(') < frame.index('invalidateNativeLocalization(.trackingUnavailable)'))
retire_end = 'if readingTool != nil && !usesCapturedText { stopReadingTool(announce: false) }'
mesh_stop = 'if case .normal = frame.camera.trackingState {} else { meshCandidateDiagnostics.stop() }'
throttle = 'guard running, !simulation, !places.scanning, frame.timestamp - lastProcessed >= 1.0 / 15 else { return }'
check('tracking retirement precedes optional stop before frame throttle',
      frame.index('invalidateNativeLocalization(.trackingUnavailable)') < frame.index(retire_end) < frame.index(mesh_stop) < frame.index(throttle))
helper = pre_seated_helper
mode = helper.split('  diagnostics-build)\n', 1)[1].split('    ;;', 1)[0]
check('flag mode build only', "'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) DEBUG BLIND_MESH_CANDIDATE_DIAGNOSTICS' build" in mode and 'run_logged diagnostics-build xcodebuild "${base[@]}"' in mode)
check('default build unchanged', 'run_logged build xcodebuild "${base[@]}" -destination \'generic/platform=iOS Simulator\' build' in helper)
check('no custom limits added', 'ulimit' not in mode and 'SDKROOT' not in mode)
workflow = pre_seated_workflow
job = workflow.split('  mesh-diagnostics-compile:\n', 1)[1]
check('compile isolated job', 'runs-on: xcode-27' in job and 'timeout-minutes: 25' in job)
check('no diagnostic runtime steps', 'native-apple.sh diagnostics-build' in job and not re.search(r'native-apple.sh (unit|ui)\b', job))
retired = (R / '.github/workflows/native-candidate-app-integration.yml').read_text()
check('custom experiment retired', '  push:' not in retired and 'if: ${{ false }}' in retired)
# The new default camera fences are unconditional true when the experimental flag is absent.
# Prove exact whitespace-normalized default-source equivalence after removing only those no-op predicates.
def without_mesh_flag(text, label):
    output=[]; stack=[]
    for line in text.splitlines(True):
        stripped=line.strip()
        if stripped.startswith('#if '):
            target=stripped=='#if DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS'
            stack.append([target,False if target else True])
            if not target and all(x[1] for x in stack):output.append(line)
        elif stripped=='#else' and stack and stack[-1][0]:stack[-1][1]=not stack[-1][1]
        elif stripped=='#endif' and stack:
            target=stack[-1][0];active=all(x[1] for x in stack);stack.pop()
            if not target and active:output.append(line)
        elif all(x[1] for x in stack):output.append(line)
    check('seated default source preprocessor balanced '+label, not stack)
    return ''.join(output)
def default_camera_source(text, current=False):
    value=without_mesh_flag(text, "current" if current else "historical")
    if current:
        for name in ['normalCameraSessionAllowed','normalCameraCallbackAllowed']:
            value,count=re.subn(r'    private var '+name+r': Bool \{\s*return true\s*\}\n', '',value)
            check('seated default predicate is exact side-effect-free true '+name,count==1)
        value=value.replace('    // A camera owner fence, not a guidance/readiness permission. Release stays unchanged.\n','')
        value=value.replace('guard normalCameraSessionAllowed else { return }','').replace(', self.normalCameraSessionAllowed','').replace(', normalCameraCallbackAllowed','')
    return re.sub(r'\s+','',value)
check('historical pre-tracker seated flag-absent navigation exact after constant-true fence elimination', default_camera_source(pre_tracker_implementation_source['ios/BlindAssist/NavigationModel.swift'].decode(),True)==default_camera_source(pre_seated_nav))
check('seated current callbacks retain exact session identity before owner fence',current_nav.count('guard session === self.session, normalCameraCallbackAllowed else { return }')==7)
current_helper=(R/'tools/ci/native-apple.sh').read_text()
focused=current_helper.split('  diagnostics-unit)\n',1)[1].split('    ;;',1)[0]
check('seated focused class only with explicit flag and no retries', "'-only-testing:BlindAssistTests/SeatedMeshProjectionTests'" in focused and 'BLIND_MESH_CANDIDATE_DIAGNOSTICS' in focused and '-parallel-testing-enabled NO' in focused and 'retry' not in focused)
check('seated focused test exit preserved', 'test || status=$?' in focused and 'exit "$status"' in focused and 'diagnostics-unit-exit.json' in focused)
current_workflow=(R/'.github/workflows/native-apple.yml').read_text()
check('seated existing runner and overall job cap retained', current_workflow.count('runs-on: xcode-27')==pre_seated_workflow.count('runs-on: xcode-27') and current_workflow.count('timeout-minutes: 25')==pre_seated_workflow.count('timeout-minutes: 25'))
check('seated focused bounded step and fail-closed collector', 'timeout-minutes: 10\n        run: bash tools/ci/native-apple.sh diagnostics-unit' in current_workflow and 'run: python3 tools/ci/collect-seated-projection.py' in current_workflow)

check('classified stdout isolated from SwiftPM stderr', '--xunit-output "$out/tests.xml" 2> "$out/swift-test.stderr.log" | tee "$out/swift-test.log"' in current_workflow)
check('classified stderr retained separately after both pipeline exits captured', current_workflow.index('statuses=("${PIPESTATUS[@]}")') < current_workflow.index('cat "$out/swift-test.stderr.log" >&2') and 'test "${statuses[0]}" -eq 0' in current_workflow and 'test "${statuses[1]}" -eq 0' in current_workflow)
check('actual session initializer label source regressions', subprocess.run([sys.executable, str(R/'tools/ci/test_live_mesh_session_initializer.py')], cwd=R, capture_output=True, timeout=15).returncode == 0)
seed_mode=pre_envelope_ci['tools/ci/native-apple.sh'].split('  seed-radius-unit)\n',1)[1].split('    ;;',1)[0]
check('seed-radius two exact classes only and original modes preserved', seed_mode.count('-only-testing:')==2 and "'-only-testing:BlindAssistTests/SavedRoomStrictEndpointTests'" in seed_mode and "'-only-testing:BlindAssistTests/SeedRadiusVetoAppleTests'" in seed_mode)
check('seed-radius default compile flags no retry or parallel testing', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS' not in seed_mode and '-parallel-testing-enabled NO' in seed_mode and 'retry' not in seed_mode)
check('seed-radius exit and separate xcresult preserved', 'seed-radius-unit.xcresult' in seed_mode and 'test || status=$?' in seed_mode and 'seed-radius-unit-exit.json' in seed_mode and 'exit "$status"' in seed_mode)
check('seed-radius focused step bounded and collector always present', 'timeout-minutes: 10\n        run: bash tools/ci/native-apple.sh seed-radius-unit' in current_workflow and 'run: python3 tools/ci/collect-seed-radius.py' in current_workflow)
check('seed-radius strict collector negative fixtures',subprocess.run([sys.executable,str(R/'tools/ci/test-collect-seed-radius.py')],cwd=R,capture_output=True,timeout=15).returncode==0)
native_job=current_workflow.split('  native:',1)[1].split('  mesh-diagnostics-compile:',1)[0]
diagnostics_job=current_workflow.split('  mesh-diagnostics-compile:',1)[1].split('  classified-mesh-bench:',1)[0]
check('focused8 moved to default job after hosted step only',native_job.index('run: bash tools/ci/native-apple.sh unit')<native_job.index('run: bash tools/ci/native-apple.sh seed-radius-unit')<native_job.index('run: bash tools/ci/native-apple.sh ui') and 'seed-radius-unit' not in diagnostics_job)
check('focused8 default build guard survives hosted failure',"id: seed-radius\n        if: ${{ !cancelled() && steps.build.outcome == 'success' }}" in native_job)
check('focused diagnostic export precedes strict collector',native_job.index('run: python3 tools/ci/export-seed-radius-diagnostics.py')<native_job.index('run: python3 tools/ci/collect-seed-radius.py') and 'seed-radius-diagnostics.json' in native_job)
check('focused evidence portable negative fixtures',subprocess.run([sys.executable,str(R/'tools/ci/test-export-seed-radius-diagnostics.py')],cwd=R,capture_output=True,timeout=15).returncode==0)
envelope_mode=current_helper.split('  seed-radius-unit)\n',1)[1].split('    ;;',1)[0]
check('envelope focused original two classes plus new third only',envelope_mode.count('-only-testing:')==3 and all("'-only-testing:BlindAssistTests/"+name+"'" in envelope_mode for name in ['SavedRoomStrictEndpointTests','SeedRadiusVetoAppleTests','SeedRadiusEnvelopeAppleTests']))
check('envelope focus retains default flags serial execution original deadline', 'SWIFT_ACTIVE_COMPILATION_CONDITIONS' not in envelope_mode and '-parallel-testing-enabled NO' in envelope_mode and '-destination-timeout 120' in envelope_mode and 'retry' not in envelope_mode)
check('envelope original eight fixture bytes exact prefix', (R/'ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift').read_bytes().startswith(pre_envelope_source['ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift']))
fixture=(R/'ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift').read_bytes()[len(pre_envelope_source['ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift'])+1:]
check('envelope six authored fixture bytes exact',hashlib.sha256(fixture).hexdigest()=='828bf475024ea1a93267dcd2580cd2fc4fde0047c4bf4f6d8bbb58940079a713')
check('envelope fourteen collector strict source inventory',"'executed':14" in (R/'tools/ci/collect-seed-radius.py').read_text() and 'SeedRadiusEnvelopeAppleTests' in (R/'tools/ci/collect-seed-radius.py').read_text())
check('envelope original disk helper unchanged',hashlib.sha256((R/'research/room-mesh-package-75/BlindRoomMesh/Sources/CDetour/exact_seed_radius_veto.h').read_bytes()).hexdigest()==manifest['envelopeIntegration']['oldDiskHelperSHA256'])
check('envelope old stock remains Swift default', 'seedRadiusPolicy:MeshSeedRadiusPolicy = .stock' in re.sub(r'\s+',' ',(R/'research/room-mesh-package-75/BlindRoomMesh/Sources/BlindRoomMesh/RoomMeshCandidate.swift').read_text()).replace('seedRadiusPolicy: ', 'seedRadiusPolicy:'))
check('envelope strict collector original regressions retained',subprocess.run([sys.executable,str(R/'tools/ci/test-collect-seed-radius.py')],cwd=R,capture_output=True,timeout=15).returncode==0)
check('envelope public diagnostic export regressions retained',subprocess.run([sys.executable,str(R/'tools/ci/test-export-seed-radius-diagnostics.py')],cwd=R,capture_output=True,timeout=15).returncode==0)
print(json.dumps(dict(sourceChecksPassed=len(checks), checks=checks, appPatchApplied=True, criticalOrderPatchApplied=True, practicePublicationPatchApplied=True, projectCanonicalizationPatchApplied=True, connectedBenchPreviewMembershipApplied=True, navigationTestRecordingApplied=True, savedFrameCameraAssociationApplied=True, sceneTimingCIHelperApplied=True, recorderTimingCIHelperApplied=True, savedRoomGeometryMembershipApplied=True, appleRoomPlanFixtureMembershipApplied=True, appleRoomRouteMembershipApplied=True, classificationIngressMembershipApplied=True, hostedDecoderLinkMembershipApplied=True,
    appleBuild='pending', normalOwnerDeliveryRetrySourceApplied=True, normalOwnerDeliveryRetryNativeExecuted=False, j01ResolutionPreparationSourceApplied=True, j01ResolutionPreparationNativeExecuted=False, j01ClosedFailureDiagnosticsSourceApplied=True, j01ClosedFailureDiagnosticsNativeExecuted=False, edtViewContactCompositionSourceApplied=True, edtViewContactCompositionNativeExecuted=False, journeyRequiredGoalUnwrapSourceApplied=True, journeyRequiredGoalUnwrapNativeExecuted=False, collisionContactPhaseSourceApplied=True, collisionContactPhaseNativeExecuted=False, classificationCrossFamilyDrainSourceApplied=True, classificationCrossFamilyDrainNativeExecuted=False, depthRasterIntegritySourceApplied=True, depthRasterIntegrityNativeExecuted=False, repeatAnswerContrastSourceApplied=True, repeatAnswerRenderedContrastVerified=False, j01TemporaryRootFixtureRepairApplied=True, j01ProductionAttestationPolicyChanged=False, seatedFixtureOwnedAdmissionSourceApplied=True, seatedFixtureOwnedAdmissionNativeExecuted=False, floorSupportResearchOnly=True, floorSupportImplementationChanged=False, localMapPipelineSourceApplied=True, localMapPipelineNativeExecuted=False, beaconBoolCompileRepairApplied=True, publishedFF0RepairReproducedExactly=True, failed119BuildPreserved=True, historicalLayersReversedExactly=True, defaultMeshDiagnosticActivation=False, trackerImplementationBatchApplied=True, secondImplementationBatchApplied=True, j01RealExecutionDefaultEnabled=False, j01SourceAttestationVerified=False, j01SameJobObservationLaneAvailable=True, j01ActualModelRunObserved=False, thirdImplementationBatchApplied=True, j01SelectedScriptCount=3, j01SupportedScriptCount=6, currentProductionBehaviorChanged=True, wholeDefaultNavigationEqualityScope='exact recovered pre-tracker source only', meshDiagnosticRuntimeOptIn='diagnostic flag plus explicit normal-owner enable or separately confirmed seated capture', meshDiagnosticGeometryCopyEnabled='opt-in normal-owner whole anchors after urgent work, or separately admitted seated owner; no physical authority',
    physicalAuthority=False, experimental128MiBCapCompliance='not claimed'), indent=2))

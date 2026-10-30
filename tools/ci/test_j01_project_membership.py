"""Portable target/opt-in controls only: no xcodebuild, simulator or model run."""
import hashlib,json,re,subprocess,unittest
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TARGET='HostedNonvisualJourneyTests.swift'
CASE='BlindAssistTests/HostedNonvisualJourneyTests/testExplicitHostedJSONLJourney'
ORIGINAL_TEST_FILES=['SpatialIntegrationFixture.swift','RegisteredIndoorNavigationTests.swift','SpatialRouteOutputControllerTests.swift','SpatialMapIOTests.swift','IndoorNavigatorAsyncTests.swift','ConnectedJourneyFixture.swift','ConnectedJourneyRuntimeTests.swift','ObservedSceneRuntimeTests.swift','SelectedDocumentPDFTests.swift','KoivuSourceAnchorBenchFixture.swift','ConnectedNavigationBenchIntegrationTests.swift','RecordedRouteStoreTests.swift','SavedRoomDiagnosticGeometryProviderTests.swift','SavedRoomDiagnosticGeometryAppleFixtureTests.swift','ClassifiedRoomMeshTests.swift','ClassificationIngressTests.swift','SavedRoomRouteMeshAppleFixtureTests.swift','SavedRoomRouteCollisionOracle.swift','SavedRoomRouteCollisionOracleTests.swift','SavedRoomRouteDiagnosticAppleTests.swift','SavedRoomRouteJourneyAppleTests.swift','SavedRoomStrictEndpointTests.swift','ConversationRuntimeFailureTests.swift','SeatedMeshProjectionTests.swift','SeatedCollisionBridgeTests.swift','NormalOwnerMeshConnectionTests.swift','NativeQoSComparisonTests.swift']
def validate(project,generator,source,wrapper,helper):
 inventory=re.search(r'const spatialTestFiles = (\[[^;]+\]);',generator)
 assert inventory is not None
 names=json.loads(inventory[1].replace("'",'"'))
 assert names.count(TARGET)==1 and [n for n in names if n!=TARGET]==ORIGINAL_TEST_FILES
 # This is deliberately a closed parser for this generated one-object-per-line
 # format, not a substitute for Apple's plutil ownership guard during preflight.
 objects=dict(re.findall(r'^([A-F0-9]{24}) = \{ (.+) \};$',project,re.M))
 refs=[k for k,v in objects.items() if 'isa = PBXFileReference;' in v and f'path = "BlindAssistTests/{TARGET}";' in v]
 assert len(refs)==1
 builds=[k for k,v in objects.items() if 'isa = PBXBuildFile;' in v and f'fileRef = {refs[0]};' in v]
 assert len(builds)==1
 owners=[]
 for key,value in objects.items():
  if 'isa = PBXNativeTarget;' not in value:continue
  name=re.search(r'name = (\w+);',value)[1]
  phases=re.search(r'buildPhases = \(([^)]*)\)',value)[1].split(',')
  for phase in filter(None,phases):
   body=objects[phase]
   if 'isa = PBXSourcesBuildPhase;' in body:
    files=re.search(r'files = \(([^)]*)\)',body)[1].split(',')
    if builds[0] in files:owners.append(name)
 assert owners==['BlindAssistTests'],'hosted test must never enter app/UI source phases'
 assert 'BLIND_J01' not in project and 'BLIND_FOUNDATION_MODELS_V2' not in project
 assert source.startswith('#if DEBUG\n')
 assert re.findall(r'    func (test\w+)\(',source)==['testAcceptedDisplayRequiresExactCurrentSettledReceipt','testExplicitHostedJSONLJourney','testActualNarrationHoldResumeKeepsMuteAndEndedAuthority']
 actual=source.split('    func testExplicitHostedJSONLJourney()',1)[1]
 assert 'env["BLIND_J01_HOSTED"]=="1",env["BLIND_J01_EPHEMERAL_SIMULATOR"]=="1"' in actual
 assert 'throw XCTSkip("Explicit isolated simulator adapter only")' in actual
 assert actual.index('throw XCTSkip(')<actual.index('let model=NavigationModel(')
 assert "CASE='"+CASE+"'" in wrapper
 assert "require(os.environ.get('BLIND_J01_EXECUTE_PREBUILT')=='1'" in wrapper
 assert "require(sys.platform=='darwin'" in wrapper
 assert "'-only-testing:'+CASE" in wrapper and "'-parallel-testing-enabled','NO'" in wrapper
 assert "time.monotonic()+55" in wrapper and '8*1024*1024' in wrapper
 assert "sourceAttestation',{}).get('verified') is False" in wrapper
 assert 'BLIND_J01_HOSTED' not in helper and 'BLIND_J01_EXECUTE_PREBUILT' not in helper
 return builds[0]
class MembershipTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.args=[(ROOT/p).read_text() for p in ['ios/BlindAssist.xcodeproj/project.pbxproj','tools/generate-xcode-project.mjs','ios/BlindAssistTests/'+TARGET,'research/j01-hosted-app-adapter-20261030/app_adapter.py','tools/ci/native-apple.sh']]
 def test_actual_unit_target_only_and_explicit_unattested_opt_in(self):validate(*self.args)
 def reject(self,index,old,new):
  args=list(self.args);self.assertIn(old,args[index]);args[index]=args[index].replace(old,new,1)
  with self.assertRaises((AssertionError,KeyError,IndexError,TypeError)):validate(*args)
 def test_generator_cannot_drop_prior_test(self):self.reject(1,"'ClassificationIngressTests.swift', ",'')
 def test_generator_cannot_drop_j01(self):self.reject(1,"'"+TARGET+"', ",'')
 def test_default_project_cannot_enable_j01(self):self.reject(0,'SWIFT_VERSION = 5.0;','SWIFT_VERSION = 5.0; BLIND_J01 = 1;')
 def test_default_project_cannot_enable_v2(self):self.reject(0,'SWIFT_VERSION = 5.0;','SWIFT_VERSION = 5.0; BLIND_FOUNDATION_MODELS_V2 = 1;')
 def test_runtime_ephemeral_opt_in_cannot_be_removed(self):self.reject(2,'env["BLIND_J01_EPHEMERAL_SIMULATOR"]=="1"','true')
 def test_source_claim_cannot_be_promoted_to_attestation(self):self.reject(3,"sourceAttestation',{}).get('verified') is False","sourceAttestation',{}).get('verified') is True")
 def test_exact_test_selection_cannot_broaden(self):self.reject(3,"'-only-testing:'+CASE","'-only-testing:BlindAssistTests'")
 def test_prebuilt_execution_cannot_be_default_on(self):self.reject(3,"require(os.environ.get('BLIND_J01_EXECUTE_PREBUILT')=='1'","require(True")
 def test_native_normal_helper_cannot_silently_enable_real_journey(self):
  args=list(self.args);args[4]+='\nexport BLIND_J01_HOSTED=1\n'
  with self.assertRaises(AssertionError):validate(*args)
 def test_generated_project_remains_exact_canonical_default(self):
  code="import {generateProject} from './tools/generate-xcode-project.mjs';import {readdirSync} from 'node:fs';process.stdout.write(generateProject(readdirSync('ios/BlindAssist').filter(x=>x.endsWith('.swift')).sort()));"
  result=subprocess.run(['node','--input-type=module','-e',code],cwd=ROOT,capture_output=True,text=True,timeout=15,check=True)
  self.assertEqual(result.stdout,self.args[0])
 def test_wrong_target_membership_is_rejected(self):
  project=self.args[0];bid=validate(*self.args)
  # Swap target names, keeping every reference/build ID unchanged.
  args=list(self.args);args[0]=project.replace('name = BlindAssistTests; productName = BlindAssistTests;','name = BlindAssist; productName = BlindAssistTests;')
  with self.assertRaises(AssertionError):validate(*args)
if __name__=='__main__':unittest.main()

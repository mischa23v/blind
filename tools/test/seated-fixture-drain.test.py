"""Bounded source and negative-mutation controls; no Swift/native execution."""
from pathlib import Path
import hashlib,re,unittest
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'ios/BlindAssistTests/SeatedMeshProjectionTests.swift'
def digest(s):return hashlib.sha256(s.encode()).hexdigest()
def block(s,needle):
 start=s.index(needle);opening=s.index('{',start);depth=0
 for i in range(opening,len(s)):
  depth+=(s[i]=='{')-(s[i]=='}')
  if depth==0:return s[start:i+1]
 raise ValueError('unclosed block')
# Filled from the exact ff0 fixture, not guessed test outcomes.
ORIGINAL_METHODS={'testIdentityKeepsRawARKitAxesAndMetres': '56b924a1926a36377ed4513f352e59faf40de58dc29427448a9ae315f40e319a', 'testColumnMajorRotationTranslationAppliedExactlyOnce': '223924868728bd124129625a5dfd86ebb627f531ef5ab9c5f7c397c6781cff5b', 'testEachAnchorUsesItsOwnTransformWithoutFrameSubstitution': '45c263d2d20462c0730e18816810747b79144becc9709c80f15f2d2e4ba8df0e', 'testMalformedNonfiniteAndPerspectiveInputRejectWholeProjection': '190902dc08cbfaa99a0b6f6a0ca5a3237aabd27d1503d821f5397fbd304aff9b', 'testWholeProjectionRejectsVertexBudgetAndFloatOverflow': '84e2d1ffa07f7025c553bfc610300d96c4b7ed7a7429db963e03c64a34f241a6', 'testDoubleLocalValuesCanCancelBeforeBoundedFloatProjection': 'a3399348847cd4701299817bae955561c25dd26723b4a294c3c88e353d70b458', 'testRouteMustMatchExactCurrentSourceSessionGenerationAndRevision': 'da524e3e44fc1a2a480f042cb718b0c3b468453368e2ff63f27aa1200abb7028', 'testConfirmationIsExactSingleUseAndRetiresOnStopOrViewReplacement': '302dde0351a0ae727e9d47f4ab3c3d794f64fcb082ddc71b33da480fa6bad19a', 'testStopKeepsOwnerUntilNativeAndHeldRendererBothDrain': 'b3f94418f74c5754ee1f5794911632e42edc3dd6d3c534230f6d746a0380d8f3', 'testMainDeliveryCannotReleaseOwnerBeforeWorkerClosureReturns': '8d02e178b86b1032caa24a78f162f8f7e45a025bc387a3c64f5922bb50594d34', 'testDeclaredFootUsesActualStrictQueryAndHistoricalDisplayWithoutFrameRebinding': '0581a0b9f53fde9e2a7abd45d706a8b8c7a2eff4d1d3a3fb3a252276a5452aeb', 'testHeldControllerResultCannotPublishAfterExplicitReplacementOrSourceChange': '37c57ff4cc2a8006e1cd637b4ed88b69747c37d715fba284318bf8f46aa54594', 'testActualSourceAndStrictQueryCompleteWhileOptionalRenderIsHeld': '84240c0543c15872f3ac3ae0b22968ebbe8a2d6f2b7dbb96ea073df69650c4e4', 'testActualAuditRetirementAndDisposalAfterRealOracleProgress': '1980e8952b8a0725e19a4f3ac095bce61b62b43ae001fa4fd565b50e6a5c052a', 'testMappedDestinationFeedsActualStrictQueryAndCollisionReceipt': '5d17f2bac505ac71aa6f775474590c76a58f9853db34672529601a2d2ca62ecc', 'testMappedDestinationRefusesMissingWrongStaleAndCrossFloorAssociation': '4383e6cdd8cb46ea57067e30691cf8233cedbe93ae01d72667e538e19a31b62c', 'testMappedDestinationRetiresHeldResultsOnRestartMapGoalAndSourceChanges': 'e3914a1eb49c8861a93352af841cc1ad8a4f5190e935b83aa3e13a96374f68ae'}
UNCHANGED_BACKEND={'    func stopAndDrain(': '276f509f13b2ee6cae682c7b42ed7a585e90994a732490bf90342fcfb15b7a43', '    func requestSourceSnapshot(': 'f5bd56c86add6d3188fa2286c5e5056fe967b451c03e46ef2ceadb5e3b3d3b70', '    func requestPreview(': '87e030c011c123c02cd6aff8b8624ce200135a5a20577d3fdc238acd9c4a5e4b', '    func printTiming(': '43aeefc664c40a8afbadadec3e79cfb37d23257ab66db1c2273607d55a509412', '    private static func printWorkerTiming(': '7e9f5ec975f5c61fe8cf8aad3cf89bd8947491878e7a5d466dd24983313c934a', '    func sourcePhaseRecorder(': '6afad9d28ed3e606004f58c96b4f5da6a558a1dbb30d1791e149222cef5a5b5c'}
def normalize_method(s):
 s=s.replace('        try checkFixtureAdmissionTokens()\n','')
 s=s.replace('try makeSessionController(session:session, expectedDelegate:original)', 'try SeatedMeshDiagnosticController(session:session, expectedDelegate:original)')
 s=s.replace('        try await assertLaterFixtureRefusedWhileControllerHeld()\n','')
 s=s.replace('        let reopened=try SeatedFixtureDrainGate.shared.reserve()\n        SeatedFixtureDrainGate.shared.acknowledge(reopened)\n','')
 return s.replace('backend.acknowledgeControllerDrain();','')
def contracts(s):
 checks=0
 def check(condition,label):
  nonlocal checks
  assert condition,label
  checks+=1
 names=re.findall(r'^\s*(?:@MainActor\s+)?func\s+(test\w+)\s*\(',s,re.M)
 check(names==list(ORIGINAL_METHODS),'all17 original projection identities, no additions/skips')
 for name,want in ORIGINAL_METHODS.items():
  check(digest(normalize_method(block(s,'func '+name+'(')))==want,'unchanged original assertions/deadlines '+name)
 for needle,want in UNCHANGED_BACKEND.items():
  check(digest(block(s,needle))==want,'unchanged backend '+needle)
 gate=block(s,'private final class SeatedFixtureDrainGate:')
 check('static let shared=SeatedFixtureDrainGate()' in gate,'shared across testcase instances')
 check(gate.count('lock.lock();defer {lock.unlock()}')==2,'both transitions locked')
 check('guard current == nil else {throw Failure.previousControllerNotDrained}' in gate,'busy throws failure notskip')
 check('let token=UUID();current=token;return token' in gate,'fresh exact lease')
 check('guard current == token else {return}' in gate,'foreign/late token cannot release')
 check('timeout' not in gate and 'DispatchQueue' not in gate,'no timeout/scheduler release')
 backend=block(s,'private final class SeatedCandidateFixtureBackend:')
 init=block(backend,'    init(savedFrame:')
 check(init.index('token=try gate.reserve()')<init.index('try LiveMeshBenchIngress(')<init.index('ingress.observe('),'reserve before construction and work')
 check('fixtureGate=gate;fixtureToken=token' in init,'same exact lease retained')
 check(init.count('gate.acknowledge(token)')==2,'only constructor throw/failed-admission cleanup release')
 check('} catch {\n            gate.acknowledge(token)' in init,'no-work constructor failure releases')
 failed=block(init,'        guard accepted else')
 check('ingress.stopAndDiscard {gate.acknowledge(token)}' in failed,'real ingress failure awaits native fence')
 check('func acknowledgeControllerDrain() {fixtureGate.acknowledge(fixtureToken)}' in backend,'controller acknowledgment retains exact token')
 session=block(s,'    @MainActor private func makeSessionController(')
 check(session.index('token=try gate.reserve()')<session.index('try SeatedMeshDiagnosticController('),'session reserve before real owner')
 check('gate.acknowledge(token) // Actual full-controller' in session,'real session full-drain callback only')
 check('drained.assertForOverFulfill=true' in session,'overfulfill detected')
 check('addTeardownBlock {' in session and 'await MainActor.run {controller.stop()}' in session,'failure cleanup registered')
 check('await self.fulfillment(of:[drained],timeout:10)' in session,'cleanup original10s bound')
 check(session.index('addTeardownBlock {')<session.index('return controller'),'cleanup before fixture escape')
 check(s.count('onStopped:{backend.acknowledgeControllerDrain();')==6,'all six backend/controller construction sites')
 check(s.count('try makeSessionController(session:session, expectedDelegate:original)')==2,'both session lifecycle cases covered')
 check('acknowledgeControllerDrain' not in block(backend,'    func stopAndDrain('),'native-only acknowledgment cannot release full controller')
 held=block(s,'func testStopKeepsOwnerUntilNativeAndHeldRendererBothDrain(')
 check(held.index('await fulfillment(of:[native],timeout:10)')<held.index('try await assertLaterFixtureRefusedWhileControllerHeld()')<held.index('        hold.signal()'),'held renderer regression runs after native acknowledgment before release')
 check(held.index('await fulfillment(of:[done],timeout:10)')<held.index('shared.reserve()'),'admission reopens after full controller ack')
 later=block(s,'    @MainActor private func assertLaterFixtureRefusedWhileControllerHeld(')
 check('let unexpected=try SeatedCandidateFixtureBackend()' in later,'attempt actual later backend constructor')
 check('catch SeatedFixtureDrainGate.Failure.previousControllerNotDrained' in later,'expected exact admission failure')
 check('XCTFail("A later fixture was admitted before full controller drain")' in later,'accidental admission fails')
 check('await fulfillment(of:[drained],timeout:10)' in later,'unexpected owner cleanup awaited without widened deadline')
 tokens=block(s,'    private func checkFixtureAdmissionTokens(')
 check('gate.acknowledge(UUID())' in tokens and 'gate.acknowledge(first);XCTAssertThrowsError(try gate.reserve())' in tokens,'foreign duplicate and old tokens tested')
 check('XCTSkip' not in s and 'continueAfterFailure' not in s,'no case suppression')
 return checks
class SourceTests(unittest.TestCase):
 def test_exact_fixture_contracts(self):self.assertGreaterEqual(contracts(SOURCE.read_text()),50)
 def test_negative_mutations_fail_closed(self):
  s=SOURCE.read_text()
  mutations=[
   ('shared gate','static let shared=SeatedFixtureDrainGate()','let shared=SeatedFixtureDrainGate()'),
   ('busy owner','guard current == nil else {throw Failure.previousControllerNotDrained}','// accepts another owner'),
   ('identity','guard current == token else {return}','// accepts any token'),
   ('locking','lock.lock();defer {lock.unlock()}','defer {}'),
   ('backend reservation','fixtureGate=gate;fixtureToken=token','fixtureGate=gate;fixtureToken=UUID()'),
   ('failed constructor real drain','ingress.stopAndDiscard {gate.acknowledge(token)}','gate.acknowledge(token)'),
   ('full controller binding','onStopped:{backend.acknowledgeControllerDrain();ownerDrained.fulfill()}','onStopped:{ownerDrained.fulfill()}'),
   ('session callback','gate.acknowledge(token) // Actual full-controller','_ = token // Actual full-controller'),
   ('async teardown','addTeardownBlock {\n            await MainActor.run {controller.stop()}','Task {\n            await MainActor.run {controller.stop()}'),
   ('overfulfill','drained.assertForOverFulfill=true','drained.assertForOverFulfill=false'),
   ('query deadline','await fulfillment(of:[ready],timeout:10)','await fulfillment(of:[ready],timeout:20)'),
   ('native control','try await assertLaterFixtureRefusedWhileControllerHeld()','// removed later-admission control'),
   ('cleanup deadline','await self.fulfillment(of:[drained],timeout:10)','await self.fulfillment(of:[drained],timeout:20)'),
   ('original assertion','XCTAssertTrue(finished); XCTAssertNil(released)','XCTAssertTrue(true)'),
  ]
  for name,a,b in mutations:
   with self.subTest(name=name):
    self.assertIn(a,s)
    with self.assertRaises((AssertionError,ValueError)):contracts(s.replace(a,b,1))
if __name__=='__main__':unittest.main()

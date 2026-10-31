"""Bounded source/negative controls only. Never runs Swift/native work."""
from pathlib import Path
import hashlib,json,re,unittest
ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'ios/BlindAssistTests/ClassificationIngressTests.swift'
ORIGINAL_METHODS={'testActualDecoderPreservesKnownLabelsAndDoesNotGuessMissingOrUnsupported': '1b7e4d9a59d64aca7d144c35b3d53fd4ba333ae13664e8c09c7f198ea2bd4565', 'testClassifiedFloorUsesRealRuntimeAndTransformOnceWithoutPhysicalAuthority': '0555c0313c2d79a2ff6b6f1b81f0b9bee107a9b58154108094aa47b0f9280bd9', 'testDefaultLegacyPolicyKeepsExistingUnclassifiedDiagnosticBehavior': '780287db30d49bf827520cef85a7e13c0283e7ec4024163b802730346fef588d', 'testKnownNonFloorMissingNoneAndUnsupportedNeverPromoteUpwardPlanes': 'd27a141f27fcb9ba71d84c48fa08dcee34c15e26f5d95f81f917fea7936a512c', 'testKnownTableGeometryRemainsObstacleAndRemovalCanRestoreFloorCandidate': 'caa17ff5d48687a58826d92e78dad82e1db52d65e43b9619bee0da554c4d36d3', 'testMissingReplacementRemovesPriorFloorAndValidRevisionRecoversButGapStays': '2fe59f1c111725fc83eca6a473379b3f2810b59f2cfaea0746537a79c15866ae', 'testUnknownCompanionFacesKeepExistingFloorRouteButNeverCompleteCoverage': '54170b36c27a89f6993f8d196490a1f2f288c8219613dfd536e697689f8dac95', 'testMalformedDecodedLabelsReplaceFloorWhileRejectedDescriptorKeepsExplicitGap': '72cd5c9a2c270973bed8d24290f0c39088476bfe97aa8c349cffabc93fb4e7d1', 'testPortableLabelContractAgreesWithNativeARKitSDK': 'acdba5efd62ec0a995b7b8ee0fd1332781e84158d56c01bb8d7cb2e4e14477f3'}
QUERY_SHA256='bc892c1dd0f1c7dd500a4668e11bd7f203de95f95d6344b3f72f70a45fec9dd3'
NEW_METHOD='testFixtureAdmissionRemainsClosedUntilExactOwnerDiscardAcknowledges'
def block(s,needle):
 start=s.index(needle);opening=s.index('{',start);depth=0
 for i in range(opening,len(s)):
  depth+=(s[i]=='{')-(s[i]=='}')
  if depth==0:return s[start:i+1]
 raise ValueError('unclosed source block')
def digest(s):return hashlib.sha256(s.encode()).hexdigest()
def contracts(s):
 names=re.findall(r'^    func (test\w+)\(',s,re.M)
 assert names==[NEW_METHOD]+list(ORIGINAL_METHODS),'exact original identities plus one gate control'
 assert all(digest(block(s,'    func '+n+'('))==h for n,h in ORIGINAL_METHODS.items()),'original test bodies unchanged'
 assert digest(block(s,'    private func query('))==QUERY_SHA256,'original query10s callback and failure unchanged'
 gate=block(s,'    final class FixtureDrainGate:')
 assert gate.count('lock.lock(); defer { lock.unlock() }')==2,'both gate transitions locked'
 assert 'guard current == nil else { return nil }' in gate,'no admission while owner retained'
 assert 'let token = UUID(); current = token; return token' in gate,'fresh identity each owner'
 assert 'guard current == token else { return }' in gate,'foreign and stale acknowledgment rejected'
 assert 'static let fixtureDrainGate = FixtureDrainGate()' in s,'gate survives test-case instance boundary'
 make=block(s,'    private func makeOwner(')
 assert make.index('Self.fixtureDrainGate.reserve()')<make.index('try MeshCandidateIngress83('),'reserve before owner construction'
 refusal=make.split('guard let token = Self.fixtureDrainGate.reserve() else {',1)[1].split('}',1)[0]
 assert 'XCTFail(' in refusal and 'throw MeshCandidateIngress83.Failure.unavailable' in refusal,'failed admission stays failed'
 assert 'discardAcknowledgements[ObjectIdentifier(owner)] = (Box<Bool>(), token)' in make,'exact owner receipt'
 assert 'addTeardownBlock { [self, owner] in' in make and 'await discard(owner)' in make,'async teardown owns failed bodies'
 assert make.index('addTeardownBlock')<make.index('return owner'),'registered before fixture escape'
 assert make.count('fixtureDrainGate.acknowledge(token)')==1 and '} catch {' in make,'only constructor failure releases before admission'
 discard=block(s,'    private func discard(')
 assert 'guard let receipt = discardAcknowledgements[ObjectIdentifier(owner)]' in discard,'exact owner lookup'
 assert 'guard receipt.acknowledged.get() != true else { return }' in discard,'only real acknowledgment skips wait'
 assert 'let done = XCTestExpectation(description: "acknowledged owned/native discard")' in discard,'fresh standalone cleanup expectation'
 assert 'done.assertForOverFulfill = true' in discard,'duplicate completion is not suppressed'
 callback=block(discard,'        owner.stopAndDiscard')
 assert callback.index('receipt.acknowledged.put(true)')<callback.index('Self.fixtureDrainGate.acknowledge(receipt.token)')<callback.index('done.fulfill()'),'release only in actual discard callback'
 assert s.count('receipt.acknowledged.put(true)')==1,'no synthetic drain acknowledgment'
 assert 'await fulfillment(of: [done], timeout: 10)' in discard,'original discard10s bound'
 assert 'wait(for:' not in discard and 'Semaphore' not in discard,'no blocking actor wait introduced'
 assert 'XCTSkip' not in make+discard and 'continueAfterFailure' not in s,'no failure or case suppression'
 assert make.count('try MeshCandidateIngress83(')==2,'same DEBUG and release constructors only'
 test=block(s,'    func '+NEW_METHOD+'(')
 assert 'gate.acknowledge(UUID())' in test and 'gate.acknowledge(first) // A duplicate/late old acknowledgment' in test,'authored held wrong and old token controls'
 return 25
class SourceTests(unittest.TestCase):
 def test_current_exact_contracts(self):self.assertEqual(contracts(SOURCE.read_text()),25)
 def test_negative_source_mutations_fail_closed(self):
  s=SOURCE.read_text()
  mutations=[
   ('gate lock','lock.lock(); defer { lock.unlock() }\n            guard current == nil','defer {}\n            guard current == nil'),
   ('busy admission','guard current == nil else { return nil }','// allow another owner'),
   ('exact token','guard current == token else { return }','// accept any token'),
   ('shared owner gate','static let fixtureDrainGate','let fixtureDrainGate'),
   ('teardown registration','addTeardownBlock { [self, owner] in','Task { [self, owner] in'),
   ('await cleanup','await discard(owner)','_ = owner'),
   ('standalone expectation','let done = XCTestExpectation(description: "acknowledged owned/native discard")','let done = expectation(description: "acknowledged owned/native discard")'),
   ('overfulfill','done.assertForOverFulfill = true','done.assertForOverFulfill = false'),
   ('ack gate','guard receipt.acknowledged.get() != true else { return }','return'),
   ('callback release','Self.fixtureDrainGate.acknowledge(receipt.token)','_ = receipt.token'),
   ('deadline','timeout: 10','timeout: 20'),
   ('original assertion','XCTAssertTrue(candidate.route.complete); XCTAssertTrue(candidate.route.sourceDeliveryComplete)','XCTAssertTrue(true)'),
  ]
  for name,a,b in mutations:
   with self.subTest(name=name):
    self.assertIn(a,s)
    with self.assertRaises((AssertionError,ValueError)):contracts(s.replace(a,b,1))

ROOM_SOURCE=ROOT/'ios/BlindAssistTests/ClassifiedRoomMeshTests.swift'
ROOM_ORIGINAL_METHODS={'testClassifiedFloorRoutesWithoutGrantingPhysicalAuthority': '6aa6f39436c9d533ca2999bdb0411c8199a0f5777f4dbd25987738cd2e387cff', 'testIdenticalUpwardObstaclePlaneIsNotPromotedToFloor': '4f7f19a898bcde8178de355f354e484eb7769692c2ad5b5a22ede1c78bf871d9', 'testMissingAndMismatchedSupportAreRejectedAtIngress': '6218de10257e9a1a962823681e321cde8ef7dc73d63a2b5e5bffeb71417f861a', 'testLegacyUnclassifiedAPIStillRoutesAndDoesNotIgnoreExplicitLabels': 'fd7b1c3057fa726daa7e3553665c4e80838f623ee541c3f88b22f65178d59111', 'testFloorTouchingBedAndLowObjectNeverGainSupportUnderTriangleOrderPermutations': 'c53477e5f2b20dd22d6099386d99560170f2164d6cc71f1c669b12f54b2695d4'}
ROOM_QUERY_SHA256='fe502c46d206d4fad5e0d25d654d9483ee38a2a55a4db2c2a8509632e0b1caee'

def cross_contracts(ingress, room):
 assert '    final class FixtureDrainGate:' in ingress and '    private final class FixtureDrainGate:' not in ingress, 'shared gate type accessible'
 assert '    static let fixtureDrainGate = FixtureDrainGate()' in ingress, 'ingress owns single process gate'
 assert 'static let fixtureDrainGate = ClassificationIngressTests.fixtureDrainGate' in room, 'both families share exact gate'
 assert 'XCTAssertTrue(Self.fixtureDrainGate === ClassifiedRoomMeshTests.fixtureDrainGate)' in ingress, 'native authored identity witness'
 assert re.findall(r'^    func (test\w+)\(',room,re.M)==list(ROOM_ORIGINAL_METHODS),'all five original runtime cases retained'
 assert all(digest(block(room,'    func '+n+'('))==h for n,h in ROOM_ORIGINAL_METHODS.items()),'original runtime assertions unchanged'
 assert digest(block(room,'    private func query('))==ROOM_QUERY_SHA256,'runtime query timeout and failure unchanged'
 make=block(room,'    private func makeRuntime(')
 assert make.index('Self.fixtureDrainGate.reserve()')<make.index('try RoomMeshCandidateRuntime('),'reserve before native construction'
 refusal=make.split('guard let token = Self.fixtureDrainGate.reserve() else {',1)[1].split('}',1)[0]
 assert 'XCTFail(' in refusal and 'throw MeshCandidateError.unavailable' in refusal,'refused admission is failure not pass'
 assert make.count('try RoomMeshCandidateRuntime(')==2,'original two conditional constructors'
 assert 'discardAcknowledgements[ObjectIdentifier(runtime)] = (Acknowledgement(), token)' in make,'exact runtime cleanup receipt'
 assert 'addTeardownBlock { [self, runtime] in' in make and 'await discard(runtime)' in make,'thrown case gets owned teardown'
 assert make.index('addTeardownBlock')<make.index('return runtime'),'teardown before escape'
 assert make.count('fixtureDrainGate.acknowledge(token)')==1 and '} catch {' in make,'construction failure only early release'
 discard=block(room,'    private func discard(')
 assert 'guard let receipt = discardAcknowledgements[ObjectIdentifier(runtime)]' in discard,'exact owner lookup'
 assert 'guard !receipt.acknowledged.get() else { return }' in discard,'real completion only skips cleanup'
 assert 'let done = XCTestExpectation(description: "terminal geometry release")' in discard,'standalone expectation across teardown retry'
 assert 'done.assertForOverFulfill = true' in discard,'duplicate callback remains failure'
 callback=block(discard,'        runtime.stopAndDiscard')
 assert callback.index('receipt.acknowledged.mark()')<callback.index('Self.fixtureDrainGate.acknowledge(receipt.token)')<callback.index('done.fulfill()'),'actual callback alone releases gate'
 assert room.count('receipt.acknowledged.mark()')==1,'no invented acknowledgment'
 assert 'await fulfillment(of: [done], timeout: 10)' in discard,'unchanged cleanup deadline'
 assert 'Semaphore' not in make+discard and 'wait(for:' not in make+discard,'no blocking wait'
 assert 'XCTSkip' not in make+discard and 'continueAfterFailure' not in room,'failures remain failures'
 return 23

class CrossFamilyTests(unittest.TestCase):
 def test_current_cross_family_contracts(self):
  self.assertEqual(cross_contracts(SOURCE.read_text(),ROOM_SOURCE.read_text()),23)
 def test_mutations_reject_contamination_or_false_pass(self):
  i=SOURCE.read_text();r=ROOM_SOURCE.read_text()
  mutations=[
   ('shared alias','ClassificationIngressTests.fixtureDrainGate','ClassificationIngressTests.FixtureDrainGate()'),
   ('admission','guard let token = Self.fixtureDrainGate.reserve() else {','guard let token = Optional(UUID()) else {'),
   ('failure','XCTFail("Previous classification fixture native owner has not acknowledged discard")','print("refused")'),
   ('teardown','addTeardownBlock { [self, runtime] in','Task { [self, runtime] in'),
   ('owned cleanup','await discard(runtime)','_ = runtime'),
   ('exact ack','Self.fixtureDrainGate.acknowledge(receipt.token)','Self.fixtureDrainGate.acknowledge(UUID())'),
   ('fresh expectation','let done = XCTestExpectation(description: "terminal geometry release")','let done = expectation(description: "terminal geometry release")'),
   ('overfulfill','done.assertForOverFulfill = true','done.assertForOverFulfill = false'),
   ('deadline','timeout: 10','timeout: 20'),
   ('original assertion','XCTAssertTrue(route.complete)','XCTAssertTrue(true)'),
  ]
  for name,a,b in mutations:
   with self.subTest(name=name):
    self.assertIn(a,r)
    with self.assertRaises((AssertionError,ValueError)):cross_contracts(i,r.replace(a,b,1))

if __name__=='__main__':unittest.main()

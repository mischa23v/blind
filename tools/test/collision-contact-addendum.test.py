#!/usr/bin/env python3
"""Current source contracts only; no Swift/SceneKit or physical acceptance."""
from pathlib import Path
import hashlib,json,os,re,unittest
ROOT=Path(os.environ.get('BLIND_SOURCE_ROOT',Path(__file__).resolve().parents[2]))
TEST='ios/BlindAssistTests/SavedRoomRouteDiagnosticAppleTests.swift'
ORACLE='ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift'
FIXTURE='ios/BlindAssistTests/Fixtures/RoomRouteDiagnostic/VALID_START_PHASE_ADDENDUM.json'
PREFIX_SHA256='7f432a653d23814f26883b90b0948e80a24178b2a2674fb896c0260277ce4326'
FIXTURE_SHA256='a8d4cc19bf25292b52d7d3282229d52177c920c39795badda413f82377475663'
def contracts(s,o,f):
 marker='    /// Additive historical-model diagnostic.'
 prefix,new=s.split(marker,1)
 assert hashlib.sha256(prefix.rstrip().encode()).hexdigest()==PREFIX_SHA256,'original three native methods and helpers unchanged'
 assert len(re.findall(r'func test\w+\(',s))==4,'original3 plus additive1'
 assert 'await fulfillment(of: [done], timeout: 15)' in new,'cleanup original15s'
 assert 'owner.stopAndDiscard { flag.set(); done.fulfill() }' in new and new.count('flag.set()')==1 and 'return flag.get()' in new,'callback-only acknowledgment'
 assert new.index('if previousOwnerUndrained')<new.index('let snapshot = try await mesh')<new.index('let owner = try RoomMeshCandidateRuntime'),'gate before admission'
 assert 'if !drained { previousOwnerUndrained = true; failed += 1 }' in new and '"not-run-after-undrained-owner"; failed += 1' in new,'undrained remains failure'
 assert all(f'try store("{k}", phases({k}), in: &row)' in new for k in ['startRaw','startMargin','goalRaw','goalMargin']),'individual endpoint receipts'
 assert new.index('"receiptState": "raw-recorded"')<new.index('let margin = try oracle.sweep') and new.index('try store("segments", records, in: &row)')<new.index('let margin = try oracle.sweep'),'raw retained before margin'
 assert 'records[records.count - 1]["receiptState"] = "complete"\n                        try store("segments", records, in: &row)' in new,'complete margin retained'
 assert 'guard try JSONSerialization.data(withJSONObject: retained).count <= 900_000' in new and new.index('throw DetailFailure.budgetExceeded')<new.index('row = candidate'),'transactional bound'
 assert '"diagnostic-budget-exceeded"' in new and '"contact-detail-budget-exceeded"' in new and 'row["detailsComplete"] = false; failed += 1' in new,'explicit failed incomplete prefix'
 assert 'guard geometry.count < 128' in new and 'guard route.points.count <= 128' in new,'geometry route caps'
 assert '"APPLE_VALID_START_CONTACT_PHASES.json"' in new and 'XCTAssertEqual(failed, 0' in new,'fixed artifact and failed result'
 assert 'XCTSkip' not in new and '\\(error)' not in new,'no skips or raw errors'
 assert 'recordDetails: Bool = false' in o and 'if recordDetails && raw.count > 32 { throw' in o,'opt-in bounded details'
 assert '(point + normal + [penetration]).allSatisfy(\\.isFinite)' in o,'finite native details'
 assert 'let geometry = SCNCylinder(radius: CGFloat(radius), height: CGFloat(height))' in o and 'options: [.collisionMargin: 0.0]' in o,'unchanged cylinder'
 assert hashlib.sha256(f).hexdigest()==FIXTURE_SHA256 and FIXTURE_SHA256 in new,'fixed authored fixture'
 return 18
class Tests(unittest.TestCase):
 def test_current_contracts(self):
  self.assertEqual(contracts((ROOT/TEST).read_text(),(ROOT/ORACLE).read_text(),(ROOT/FIXTURE).read_bytes()),18)
 def test_admission_retention_and_failure_mutations(self):
  s=(ROOT/TEST).read_text();o=(ROOT/ORACLE).read_text();f=(ROOT/FIXTURE).read_bytes()
  changes=[('await fulfillment(of: [done], timeout: 15)','await fulfillment(of: [done], timeout: 30)'),('owner.stopAndDiscard { flag.set(); done.fulfill() }','owner.stopAndDiscard { done.fulfill() }'),('if previousOwnerUndrained','if false'),('previousOwnerUndrained = true','previousOwnerUndrained = false'),('try store("startRaw", phases(startRaw), in: &row)','row["startRaw"] = phases(startRaw)'),('"receiptState": "raw-recorded"','"receiptState": "dropped"'),('<= 900_000','<= 9_000_000'),('"diagnostic-budget-exceeded"','"success"'),('guard geometry.count < 128','guard geometry.count < 10000'),('XCTAssertEqual(failed, 0','XCTAssertEqual(0, 0')]
  for a,b in changes:
   with self.subTest(a=a):
    self.assertIn(a,s)
    # Restrict mutation to additive method so original-prefix check cannot mask its contract.
    prefix,new=s.split('    /// Additive historical-model diagnostic.',1)
    with self.assertRaises((AssertionError,ValueError)):contracts(prefix+'    /// Additive historical-model diagnostic.'+new.replace(a,b,1),o,f)
 def test_oracle_and_fixture_mutations(self):
  s=(ROOT/TEST).read_text();o=(ROOT/ORACLE).read_text();f=(ROOT/FIXTURE).read_bytes()
  for a,b in [('recordDetails: Bool = false','recordDetails: Bool = true'),('raw.count > 32','raw.count > 3200'),('(point + normal + [penetration]).allSatisfy(\\.isFinite)','true')]:
   with self.subTest(a=a),self.assertRaises(AssertionError):contracts(s,o.replace(a,b),f)
  with self.assertRaises(AssertionError):contracts(s,o,f+b' ')
if __name__=='__main__':unittest.main()

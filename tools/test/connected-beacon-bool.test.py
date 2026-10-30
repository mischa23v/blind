"""Portable actual-source return/permission controls; not a Swift compile or audio test."""
import os,re,unittest
from pathlib import Path
ROOT=Path(os.environ.get('BLIND_SOURCE_ROOT',Path(__file__).resolve().parents[2]))
NAV='ios/BlindAssist/NavigationModel.swift'
CONTROLLER='ios/BlindAssist/SpatialRouteOutputController.swift'
FEEDBACK='ios/BlindAssist/Feedback.swift'
GUARD='guard self.revalidateCurrentNavigationHazards(now: ProcessInfo.processInfo.systemUptime) else { return false }'
SINK='return self.feedback.spatialRouteBeacon(sector: cue.sector, distance: min(10, cue.distance), id: id)'
def validate(nav,controller,feedback):
 start=nav.index('private func connectedJourneyBeacon(automatic: Bool)')
 end=nav.index('\n    func stopReturn()',start);method=nav[start:end]
 match=re.search(r'\}, beacon: \{ id in\n([\s\S]*?)\n        \}\) \{',method)
 assert match is not None,'exact existing beacon callback required'
 body=match[1];normalize=lambda s:re.sub(r'\s+',' ',s).strip()
 assert normalize(body)==normalize(GUARD+'\n'+SINK),'Bool guard and actual sink result must be explicit'
 assert method.count('self.feedback.spatialRouteBeacon(')==1,'one sink attempt only'
 assert method.index('guard revalidateCurrentNavigationHazards(now: now) else { return }')<method.index('try $0.next(now: now)'),'pre-query hazard fence retained'
 speech=method.split('speech: { id, text in',1)[1].split('}, beacon:',1)[0]
 assert GUARD in speech and 'return self.deliverCandidate(candidate, speechID: id, spatialRouteID: id)' in speech,'speech Boolean and hazard fence unchanged'
 assert 'speech: (UUID, String) -> Bool, beacon: (UUID) -> Bool) -> Bool' in controller,'actual callback contract remains Bool'
 assert '_ = beacon(attempt.id)' in controller,'existing optional-beacon policy is not changed by this compile repair'
 assert '@discardableResult func spatialRouteBeacon(sector: Int, distance: Double, id: UUID) -> Bool' in feedback,'actual sink result contract'
 assert 'guard spatialRoutePermission?(id) == true else { return false }' in feedback,'sink permission still rechecks'
 assert 'return playBeacon(sector: sector, distance: distance, routeID: id)' in feedback,'actual playback admission result, not fabricated success'
 return 9
class Tests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.values=[(ROOT/p).read_text() for p in [NAV,CONTROLLER,FEEDBACK]]
 def test_current_boolean_contract_and_permission_fences(self):self.assertEqual(validate(*self.values),9)
 def test_actual119_bare_return_is_rejected(self):
  bad=self.values[0].replace(GUARD+'\n            '+SINK,GUARD.replace('return false','return')+'\n            '+SINK.removeprefix('return '),1)
  self.assertNotEqual(bad,self.values[0])
  with self.assertRaises(AssertionError):validate(bad,*self.values[1:])
 def test_mutations_cannot_promote_or_bypass_beacon_admission(self):
  for old,new in [(GUARD,GUARD.replace('return false','return true')),(GUARD,''),(SINK,SINK.removeprefix('return ')),(SINK,'return true'),(SINK,'return false'),(SINK,SINK.replace('id: id','id: UUID()')),(GUARD+'\n            '+SINK,SINK+'\n            '+GUARD)]:
   with self.subTest(change=new):
    mutated=self.values[0].replace('}, beacon: { id in\n            '+GUARD+'\n            '+SINK,'}, beacon: { id in\n            '+(GUARD+'\n            '+SINK).replace(old,new,1),1)
    self.assertNotEqual(mutated,self.values[0])
    with self.assertRaises(AssertionError):validate(mutated,*self.values[1:])
if __name__=='__main__':unittest.main()

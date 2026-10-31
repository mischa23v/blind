"""Stdlib source/buffer contracts, not controller tests."""
import hashlib,json,math,pathlib,struct,unittest
H=pathlib.Path(__file__).resolve().parent;W=H.parents[2];D=W/'rapier-real-room-inputs-001'
class SourceTests(unittest.TestCase):
 def setUp(self):self.m=json.loads((D/'MATERIALIZATION.json').read_text());self.p={s:json.loads((D/(s+'.probes.json')).read_text())for s in ['coffee','conference']}
 def test_hashes(self):
  for n,r in self.m['files'].items():b=(D/n).read_bytes();self.assertEqual(len(b),r['bytes']);self.assertEqual(hashlib.sha256(b).hexdigest(),r['sha256'])
 def test_inventory(self):
  p=sum(self.p.values(),[]);self.assertEqual(len(p),51);self.assertEqual(len({r['id']for r in p}),51);self.assertEqual(sum(r['kind']=='turn'for r in p),10);self.assertEqual((len(p)-10)*8,328)
 def test_no_excess_delta(self):
  for p in sum(self.p.values(),[]):self.assertLessEqual(math.sqrt(sum(x*x for x in p['desiredDelta'])),.025+1e-12);self.assertTrue(p['inputAdmissible'])
 def test_fixed_selection(self):
  self.assertEqual([p['sourceEvent']for p in self.p['coffee'][:7]],[0,1,2,10,630,1642,1643]);self.assertEqual(len(self.p['conference']),42)
 def test_buffer_indices(self):
  for s in self.p:
   f=list(struct.iter_unpack('<I',(D/(s+'.indices.u32')).read_bytes()));self.assertEqual(len(f),self.m['scenes'][s]['triangles']*3);self.assertTrue(all(0<=x[0]<self.m['scenes'][s]['vertices']for x in f))
 def test_ground_saved_state(self):
  z,t=self.p['coffee'][-2:];self.assertEqual(z['foot'],t['foot']);self.assertEqual(z['yawRadians'],t['yawRadians']);self.assertEqual(z['desiredDelta'],[0,0,0]);self.assertEqual(t['kind'],'turn');self.assertEqual(z['foot'],z['independentEvidence']['savedStateSourcePosition'])
 def test_evidence_and_authority(self):
  for p in sum(self.p.values(),[]):self.assertFalse(p['physicalAuthority']);self.assertIn('sourceLogSHA256',p['independentEvidence']);self.assertIn('unknown',p['independentEvidence']['coverage'])
 def test_conference_identity(self):
  self.assertEqual(self.m['scenes']['conference']['vertexBytesSHA256'],'50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb');self.assertEqual(self.m['scenes']['conference']['indexBytesSHA256'],'2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324')
if __name__=='__main__':unittest.main()

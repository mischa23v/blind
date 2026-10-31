#!/usr/bin/env python3
"""Stdlib-only source contract tests: no JS, WASM, VTK or NumPy import."""
import ast,hashlib,json,pathlib,unittest
H=pathlib.Path(__file__).resolve().parent;W=H.parents[2]
class SourceTests(unittest.TestCase):
 def test_all_python_parse(self):
  for p in H.glob('*.py'):ast.parse(p.read_text())
 def test_unchanged_rapier_adapter(self):
  old=H.parent/'rapier-real-room-source-20261030'
  for n in ['comparator.mjs','loader.mjs','guard_helpers.py','LICENSE.rapier-0.21.0']:self.assertEqual((H/n).read_bytes(),(old/n).read_bytes())
 def test_exact_probe_binding(self):
  ds=json.loads((W/'rapier-support-datum-inputs-001/CANDIDATE_DATUMS.json').read_text())['results'];entries=json.loads((H/'PROBES.json').read_text());self.assertEqual(len(entries),24);k=0
  for d in ds:
   p=d['originalProbe']
   for arm in ['original','candidate']:
    for intent in ['zero','original_xyz']:
     e=entries[k];k+=1;q=e['probe'];self.assertEqual(e['scene'],d['scene']);self.assertEqual(q['id'],p['id']+'|'+arm+'|'+intent);self.assertEqual(q['foot'],p['foot'] if arm=='original' else d['candidateFoot']);self.assertEqual(q['yawRadians'],p['yawRadians']);self.assertEqual(q['desiredDelta'],[0,0,0] if intent=='zero' else p['desiredDelta']);self.assertFalse(q['independentEvidence']['movementEligible']);self.assertFalse(d['supportEstablished']);self.assertTrue(all(c['extrapolated'] for c in d['nominalCornerCoverage']))
 def test_node_bounds(self):
  s=(H/'room_worker.mjs').read_text();self.assertIn('budget.count<=48',s);self.assertIn('budget.count===48',s);self.assertIn("arm='raw_trimesh'",s);self.assertNotIn("for(const arm",s)
 def test_guard_serial(self):
  s=(H/'run_aggregate.py').read_text();self.assertIn('for label,args in commands:',s);self.assertIn("'vtkEnvelopeBandQueries':96",s);self.assertIn("'controllerCalls':48",s);self.assertIn("'--permission'",s);self.assertNotIn('unshare',s);self.assertNotIn('RLIMIT_AS,',s)
 def test_vtk_original_kernel(self):
  s=(H/'vtk_worker.py').read_text();self.assertIn('from oriented_ground_container import GroundedReferenceContainer',s);self.assertIn('result=super().is_ground(cell_id)',s);self.assertIn('scorer.contact_corners(corners)',s);self.assertIn('for trim in [0,.002]',s);self.assertIn('count!=96',s)
if __name__=='__main__':unittest.main()

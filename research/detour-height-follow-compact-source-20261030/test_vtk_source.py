#!/usr/bin/env python3
"""Stdlib source/schedule tests only; no VTK, NumPy or Detour load."""
import ast,importlib.util,pathlib,sys,unittest
H=pathlib.Path(__file__).resolve().parent;sys.path.insert(0,str(H))
from schedule_contract import load_schedules
class VTKSourceTests(unittest.TestCase):
 def test_parse(self):
  for n in ('vtk_worker.py','vtk_contract.py'):ast.parse((H/n).read_text())
 def test_exact_inventory(self):
  routes=load_schedules(H.parents[1]);self.assertEqual([len(r['events'])for r in routes],[2052,1644]);self.assertEqual(sum(len(r['events'])for r in routes)*8,29568)
 def test_import_is_source_only(self):
  for name in ('vtk_worker','vtk_contract'):
   spec=importlib.util.spec_from_file_location(name,H/(name+'.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
  self.assertNotIn('vtk',sys.modules);self.assertNotIn('numpy',sys.modules)
 def test_all_hit_hook(self):
  s=(H/'vtk_worker.py').read_text();self.assertIn('result=super().is_ground(cell_id)',s);self.assertIn("need(not result,'ground exemption forbidden')",s);self.assertIn('scorer.contact_corners(corners)',s);self.assertIn('len(set(current_hits))==len(current_hits)',s);self.assertIn("contactIDs=list(current_hits)",s)
 def test_invalid_native_retained(self):
  s=(H/'vtk_worker.py').read_text();self.assertIn("status='unavailable_native_height',queryExecuted=False,contactIDs=None",s);self.assertIn("h['originalEvent']==e",s);self.assertIn("nativeHeightQueryEvidenceKey",s)
 def test_swept_rotation_preserved(self):
  s=(H/'vtk_worker.py').read_text();self.assertIn("sweep_enclosure(start,end,e['yaw'],e['dyaw']",s);self.assertIn("for trim in (0.,.002)",s)
 def test_lower_bands_explicit(self):
  s=(H/'vtk_worker.py').read_text();self.assertIn('uncoveredLowerBand',s);self.assertIn('newlyCoveredLowerBand',s);self.assertIn('endpointBandsOnlyNotContinuousSupport',s)
if __name__=='__main__':unittest.main()

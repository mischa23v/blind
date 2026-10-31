"""Pure stdlib source tests only; do not import native bindings or decode meshes."""
import ast,copy,hashlib,json,pathlib,unittest
from schedule_contract import load_schedules,unchanged_metadata,XZ_TOLERANCE_METRES,BODY_FOOT_OFFSET_METRES
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1]
class Tests(unittest.TestCase):
 def test_schedules(self):
  rows=load_schedules(R);self.assertEqual([(x['scene'],x['name'],len(x['events']))for x in rows],[('conference','table_120_to_200',2052),('coffee','0_to_8',1644)])
  self.assertEqual(sum(len(x['events'])*8 for x in rows),29568)
 def test_native_source_byte_identity(self):
  old=R/'research/detour-height-follow-source-20261030'
  for n in ['height_adapter.cpp','native_height_worker.py','original_schedule.py','schedule_contract.py']:
   self.assertEqual((H/n).read_bytes(),(old/n).read_bytes())
 def test_old_scheduler_byte_identity(self):
  self.assertEqual((H/'original_schedule.py').read_bytes(),(R/'research/conference-body-source-20261029/schedule_source.py').read_bytes())
 def test_endpoint_reset_preserved_original(self):
  rows=load_schedules(R)
  self.assertAlmostEqual(rows[0]['chain'][-1][1]-rows[0]['chain'][-2][1],-.025951618371161223)
  self.assertAlmostEqual(rows[1]['chain'][-1][1]-rows[1]['chain'][-2][1],-.019057386255342923)
 def test_association_conventions_frozen(self):
  self.assertEqual(XZ_TOLERANCE_METRES,1e-6);self.assertEqual(BODY_FOOT_OFFSET_METRES,0.)
 def test_no_xz_or_heading_repair(self):
  e=load_schedules(R)[0]['events'][0];c={**copy.deepcopy(e),'valid':True};self.assertTrue(unchanged_metadata(e,c))
  c['a'][0]+=.001
  with self.assertRaises(ValueError):unchanged_metadata(e,c)
  c={**copy.deepcopy(e),'valid':True};c['yaw']+=.001
  with self.assertRaises(ValueError):unchanged_metadata(e,c)
 def test_ast_only(self):
  for p in H.glob('*.py'):ast.parse(p.read_text())
 def test_guard_serial_and_caps(self):
  s=(H/'run_aggregate.py').read_text();self.assertIn("['compile','height','vtk']",s);self.assertIn('CPU,WALL,RSS,OUTPUT=120,180,1024**3,64*1024**2',s)
  self.assertIn('64*1024**2',(H/'guard_helpers.py').read_text());self.assertIn('inputHashesAfter',s);self.assertIn('start_new_session=True',s);self.assertNotIn('unshare',s)
if __name__=='__main__':unittest.main()

import math,unittest
import numpy as np
from detour_engine import Engine,Config
from test_detour_engine import floor
class QuarterDecimetreTests(unittest.TestCase):
 def test_requested_quarter_decimetre_raster_routes(self):
  for r in [.225,.275,.15,.125]:
   with self.subTest(radius=r),Engine(*floor(0,8,0,4),Config(radius=r,height=1.75,cell_size=.025,max_climb=0))as e:
    self.assertTrue(e.route([1,0,2],[7,0,2]).complete)
 def test_below_new_floor_rejected(self):
  with self.assertRaisesRegex(ValueError,'invalid bounded configuration'):Engine(*floor(),Config(cell_size=.0249))
 def test_existing_grid_cap_not_increased(self):
  with self.assertRaisesRegex(ValueError,'grid cell cap'):Engine(*floor(0,20,0,20),Config(cell_size=.025))
 def test_float32_effective_radius_cell_counts(self):
  for r,n in [(.225,9),(.275,11),(.15,6),(.125,5)]:
   self.assertEqual(math.ceil(float(np.float32(r)/np.float32(.025))),n)
if __name__=='__main__':unittest.main(verbosity=2)

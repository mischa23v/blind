"""Frozen synthetic geometry fixtures, not observed room or independent safety scoring."""
import ctypes as C,json,unittest
from pathlib import Path
import numpy as np
from occupancy_engine import OccupancyEngine,Config,DT,lib
CFG=Config(radius=.24,height=1.2,cell_size=.04,cell_height=.02,max_climb=0.,max_slope=5.)
START=[.64,.02,1.6];GOAL=[4.16,.02,1.6]
RECEIPTS=[]
def leaf(q,size=.08,kind=1,occupied=1):
 # Independent inverse of native P->Q: P=(Qx,-Qz,Qy).
 return (q[0],-q[2],q[1],size,.8 if occupied else .2,kind,1,occupied)
def floor(gap=False,level=0):
 return [leaf(((i+.5)*.08,level-.04,(j+.5)*.08))for i in range(60)for j in range(40)if not(gap and 26<=i<34)]
def wall(height=.48,base=0,opening=None):
 return [leaf((2.4,base+.04+k*.08,(j+.5)*.08),kind=100)for k in range(round(height/.08))for j in range(40)if opening is None or not(opening[0]<(j+.5)*.08<opening[1])]
def arr(rows):return np.array(rows,dtype=DT)
def query(rows,config=CFG,start=START,goal=GOAL):
 with OccupancyEngine(arr(rows),config) as e:
  r=e.diagnostic(start,goal);RECEIPTS.append({'stats':e.stats,'result':r});return r,e.stats
class OccupancyTests(unittest.TestCase):
 def test_metric_basis_nonzero_and_variable_leaf_size(self):
  l=lib()
  for size in [.04,.08]:
   a=arr([leaf((1.25,-1.26,2.5),size=size)]);lo=np.zeros(3,np.float64);hi=lo.copy()
   self.assertEqual(l.bn_occupancy_leaf_bounds(a.ctypes.data,lo.ctypes.data_as(C.POINTER(C.c_double)),hi.ctypes.data_as(C.POINTER(C.c_double))),1)
   np.testing.assert_allclose((lo+hi)/2,[1.25,-1.26,2.5],atol=1e-7,rtol=0);np.testing.assert_allclose(hi-lo,size,atol=1e-8,rtol=0)
  b=np.array([[1,0,0],[0,0,1],[0,-1,0]]);self.assertEqual(np.linalg.det(b),1);p=np.array([1.25,-2.5,-1.26]);np.testing.assert_allclose(b.T@(b@p),p,rtol=0,atol=0)
 def test_flat_floor_candidate_is_never_evidence_qualified(self):
  r,s=query(floor());self.assertTrue(r['projectedCorridorComplete'],r);self.assertFalse(r['evidenceQualifiedTraversable']);self.assertFalse(r['physicalAuthority']);self.assertEqual(r['fullFootprintSupport'],'unverified');self.assertEqual(s['ground'],2400)
 def test_free_historical_obstacle_does_not_add_span(self):
  original,_=query(floor());extra=[leaf((2.4,0.6,1.6),kind=100,occupied=0),leaf((2.4,0.6,1.6),kind=1,occupied=0)]
  result,s=query(floor()+extra);self.assertEqual(result,original);self.assertEqual(s['free'],2)
 def test_unknown_floor_hole_not_filled(self):
  r,_=query(floor(gap=True));self.assertFalse(r['projectedCorridorComplete'],r)
 def test_floor_touching_low_obstacle_not_promoted(self):
  r,s=query(floor()+wall(height=.08));self.assertFalse(r['projectedCorridorComplete'],r);self.assertGreater(s['obstacleSpans'],0)
 def test_floor_obstacle_priority_is_order_independent(self):
  rows=floor()+wall(height=.08);a,sa=query(rows);b,sb=query(list(reversed(rows)));self.assertEqual(a,b);self.assertEqual(sa,sb)
 def test_obstacle_below_overlapping_ground_still_wins(self):
  # Deliberate contradictory overlapping input, both orders; never promote it.
  rows=floor()+[leaf((2.4,-.08,(j+.5)*.08),size=.16,kind=100)for j in range(40)]
  a,sa=query(rows);b,sb=query(list(reversed(rows)));self.assertEqual(a,b);self.assertEqual(sa,sb);self.assertFalse(a['projectedCorridorComplete'])
 def test_head_obstacle_blocks_without_floor_contact(self):
  r,_=query(floor()+wall(height=.08,base=.8));self.assertFalse(r['projectedCorridorComplete'],r)
 def test_narrow_opening_and_quantized_radius(self):
  rows=floor()+wall(height=1.6,opening=(1.28,1.92));r,_=query(rows);self.assertTrue(r['projectedCorridorComplete'],r)
  larger=Config(**{**CFG.__dict__,'radius':.4});r,_=query(rows,larger);self.assertFalse(r['projectedCorridorComplete'],r)
  self.assertEqual(int(np.ceil(np.float32(CFG.radius)/np.float32(CFG.cell_size))),6)
 def test_unknown_body_volume_is_not_clearance(self):
  missing,_=query(floor());seen,_=query(floor()+[leaf((1.2,.4,1.6),occupied=0,kind=0)])
  self.assertEqual(missing['path'],seen['path']);self.assertFalse(missing['evidenceQualifiedTraversable']);self.assertFalse(seen['evidenceQualifiedTraversable']);self.assertEqual(missing['fullBodyCoverage'],'unverified')
 def test_elevated_native_ground_remains_provisional(self):
  r,_=query(floor(level=1.6),start=[.64,1.62,1.6],goal=[4.16,1.62,1.6]);self.assertTrue(r['projectedCorridorComplete'],r);self.assertFalse(r['evidenceQualifiedTraversable'])
 def test_nonzero_translation_keeps_metric_route(self):
  a=arr(floor());a['x']+=8;a['y']-=4;a['z']+=2
  with OccupancyEngine(a,CFG)as e:
   r=e.diagnostic([8.64,2.02,5.6],[12.16,2.02,5.6]);self.assertTrue(r['projectedCorridorComplete'],r)
   self.assertAlmostEqual(r['projectedGoal'][0]-r['projectedStart'][0],3.52,places=5)
 def test_invalid_inputs_and_config_rejected(self):
  for key,value in [('size',0),('x',float('nan')),('probability',.1),('occupied',7),('type',3)]:
   a=arr(floor());a[0][key]=value
   with self.assertRaises(ValueError):OccupancyEngine(a,CFG)
  with self.assertRaises(ValueError):OccupancyEngine(arr(floor()),Config(**{**CFG.__dict__,'max_cells':1}))
  with self.assertRaises(ValueError):OccupancyEngine(arr([leaf((0,0,0),occupied=0)]),CFG)
 def test_projection_does_not_move_requested_state(self):
  a=np.array(START);before=a.copy()
  with OccupancyEngine(arr(floor()),CFG)as e:
   r=e.diagnostic(a,GOAL);np.testing.assert_array_equal(a,before);self.assertTrue(r['projectedCorridorComplete'])
   r=e.diagnostic([-100,0,0],GOAL);self.assertFalse(r['projectedCorridorComplete']);self.assertEqual(r['path'],())
 def test_near_wall_projection_is_not_a_requested_route(self):
  a=[.15,.02,1.6];r,_=query(floor(),start=a)
  self.assertTrue(r['projectedCorridorComplete']);self.assertGreater(r['startProjectionOffset']['horizontalMetres'],.10)
  self.assertEqual(r['requestedStart'],tuple(a));self.assertFalse(r['requestedRouteComplete']);self.assertFalse(r['requestedEndpointConnectionsVerified'])
 def test_vertical_projection_is_not_a_requested_route(self):
  r,_=query(floor(),start=[.64,.25,1.6]);self.assertTrue(r['projectedCorridorComplete'])
  self.assertGreater(r['startProjectionOffset']['threeDMetres'],.20);self.assertFalse(r['requestedRouteComplete'])
 def test_goal_projection_connection_is_unverified(self):
  r,_=query(floor(),goal=[4.65,.02,1.6]);self.assertTrue(r['projectedCorridorComplete'])
  self.assertGreater(r['goalProjectionOffset']['horizontalMetres'],.10);self.assertFalse(r['requestedRouteComplete'])
 def test_multilayer_nearest_poly_does_not_connect_requested_height(self):
  with OccupancyEngine(arr(floor()+floor(level=1.6)),CFG) as e:
   r=e.diagnostic([.64,.8,1.6],[4.16,.8,1.6],query_half_extents=(.2,1.,.2))
   self.assertTrue(r['projectedCorridorComplete']);self.assertGreater(r['startProjectionOffset']['threeDMetres'],.5)
   self.assertFalse(r['requestedRouteComplete']);self.assertFalse(r['requestedEndpointConnectionsVerified'])
 def test_mixed_four_eight_cm_leaf_topology(self):
  original=floor();mixed=[]
  for i,row in enumerate(original):
   if i%2:mixed.append(row);continue
   p=np.array(row[:3]);q=np.array([p[0],p[2],-p[1]])
   for x in [-.02,.02]:
    for y in [-.02,.02]:
     for z in [-.02,.02]:mixed.append(leaf(q+[x,y,z],size=.04))
  a,_=query(original);b,_=query(mixed);self.assertTrue(a['projectedCorridorComplete']);self.assertTrue(b['projectedCorridorComplete'])
  np.testing.assert_allclose(a['projectedStart'],b['projectedStart'],atol=.021,rtol=0)
  self.assertFalse(b['requestedRouteComplete']);self.assertFalse(b['evidenceQualifiedTraversable'])
 def test_subcell_unknown_gap_is_not_support_certification(self):
  a=arr(floor());a['x'][a['x']>2.4]+=.01
  left=a[a['x']<2.4];right=a[a['x']>2.4]
  gap=float(np.min(right['x']-right['size']/2)-np.max(left['x']+left['size']/2));self.assertGreater(gap,.009);self.assertLess(gap,CFG.cell_size)
  with OccupancyEngine(a,CFG) as e:
   r=e.diagnostic(START,GOAL)
   self.assertTrue(r['rasterMayBridgeSubcellUnknownGaps']);self.assertFalse(r['requestedRouteComplete']);self.assertFalse(r['evidenceQualifiedTraversable']);self.assertEqual(r['fullFootprintSupport'],'unverified')
   RECEIPTS.append({'subcellUnknownGapMetres':gap,'stats':e.stats,'result':r})
 def test_diagonal_bottleneck_remains_unqualified(self):
  second=wall(height=1.6,opening=(1.6,2.24));second=[(r[0]+.64,*r[1:])for r in second]
  r,_=query(floor()+wall(height=1.6,opening=(1.28,1.92))+second)
  self.assertIsInstance(r['projectedCorridorComplete'],bool);self.assertFalse(r['requestedRouteComplete']);self.assertFalse(r['evidenceQualifiedTraversable'])
 @classmethod
 def tearDownClass(cls):
  Path(__file__).with_name('FIXTURE_DIAGNOSTICS.json').write_text(json.dumps({'configuration':CFG.__dict__,'syntheticBody':True,'profileMeasured':False,'results':RECEIPTS,'recordedRoutesExecuted':0,'physicalAuthority':False},indent=2,allow_nan=False)+'\n')
if __name__=='__main__':unittest.main(verbosity=2)

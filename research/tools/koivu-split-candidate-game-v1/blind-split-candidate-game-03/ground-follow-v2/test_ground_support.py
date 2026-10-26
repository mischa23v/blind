import math,unittest
import numpy as np
from ground_support import GroundSupport,GroundSupportUnavailable

def classify(vertices,triangles,seeds=None):
 v=np.asarray(vertices,float);t=np.asarray(triangles,np.int64);p=v[t];normal=np.cross(p[:,1]-p[:,0],p[:,2]-p[:,0]);n=np.linalg.norm(normal,axis=1);ny=np.full(len(t),np.nan);good=n>0;ny[good]=np.abs(normal[good,1])/n[good]
 return GroundSupport.from_candidates(np.arange(len(t),dtype=np.int64),t,ny,np.ones(len(t),bool),[0]*9 if seeds is None else seeds)

class GroundTests(unittest.TestCase):
 def test_flat_shared_edge_and_reverse_winding(self):
  g=classify([[0,0,0],[1,0,0],[0,0,1],[1,0,1]],[[0,1,2],[2,3,1]])
  self.assertEqual(g.ground_cell_ids.tolist(),[0,1]);self.assertFalse(g.is_ground(2));self.assertFalse(g.is_ground(True))
 def test_smooth_three_degree_ramp_is_ground(self):
  y=math.tan(math.radians(3));g=classify([[0,0,0],[1,y,0],[0,0,1],[1,y,1]],[[0,1,2],[1,3,2]])
  self.assertEqual(g.ground_cell_ids.tolist(),[0,1])
 def test_one_cm_riser_and_top_remain_non_ground(self):
  # Vertical riser shares a floor edge; its top shares only the riser.
  v=[[0,0,0],[1,0,0],[0,0,1],[1,0,1],[1,.01,0],[1,.01,1],[2,.01,0],[2,.01,1]]
  t=[[0,1,2],[1,3,2],[1,4,3],[4,5,3],[4,6,5],[6,7,5]]
  g=classify(v,t);self.assertEqual(g.ground_cell_ids.tolist(),[0,1])
 def test_detached_one_cm_toy_top_not_ground(self):
  v=[[0,0,0],[1,0,0],[0,0,1],[.2,.01,.2],[.3,.01,.2],[.2,.01,.3]]
  g=classify(v,[[0,1,2],[3,4,5]]);self.assertFalse(g.is_ground(1))
 def test_point_only_connection_does_not_join(self):
  g=classify([[0,0,0],[1,0,0],[0,0,1],[-1,0,0],[0,0,-1]],[[0,1,2],[0,3,4]])
  self.assertEqual(g.ground_cell_ids.tolist(),[0])
 def test_drop_and_disconnected_support_seed_fail(self):
  v=[[0,0,0],[1,0,0],[0,0,1],[1,0,1],[1,-.01,0],[1,-.01,1],[2,-.01,0],[2,-.01,1]];t=[[0,1,2],[1,3,2],[1,4,3],[4,5,3],[4,6,5],[6,7,5]]
  g=classify(v,t);self.assertFalse(g.is_ground(4))
  with self.assertRaises(GroundSupportUnavailable):classify(v,t,[0]*8+[4])
 def test_steep_slope_seed_unknown(self):
  with self.assertRaises(GroundSupportUnavailable):classify([[0,0,0],[1,1,0],[0,0,1]],[[0,1,2]])
 def test_all_nine_seeds_required(self):
  with self.assertRaises(GroundSupportUnavailable):classify([[0,0,0],[1,0,0],[0,0,1]],[[0,1,2]],[0]*8)
 def test_original_ids_preserved_and_bounds_do_not_admit_by_height(self):
  g=GroundSupport.from_candidates(np.array([91,4]),np.array([[0,1,2],[1,3,2]]),np.ones(2),np.array([True,False]),[91]*9)
  self.assertEqual(g.ground_cell_ids.tolist(),[91]);self.assertFalse(g.is_ground(4))

class BoundFixtureTests(unittest.TestCase):
 def test_actual_vtk_patch_transform_and_owner_retirement(self):
  import vtk
  from types import SimpleNamespace
  vertices=np.array([[-1,0,-1],[1,0,-1],[-1,0,1],[1,0,1]],float)
  th=.2;c,s=math.cos(th),math.sin(th);transform=np.eye(4);transform[:3,:3]=1.02*np.array([[1,0,0],[0,c,-s],[0,s,c]]);transform[:3,3]=[4,-2,1]
  ref=vertices@transform[:3,:3].T+transform[:3,3]
  points=vtk.vtkPoints();points.SetDataTypeToDouble()
  for p in ref:points.InsertNextPoint(*p)
  cells=vtk.vtkCellArray()
  for row in [[0,1,2],[1,3,2]]:
   cells.InsertNextCell(3)
   for x in row:cells.InsertCellPoint(x)
  mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells);locator=vtk.vtkStaticCellLocator();locator.SetDataSet(mesh);locator.BuildLocator()
  surface=SimpleNamespace(mesh=mesh,locator=locator,errors=[])
  scorer=SimpleNamespace(surface=surface,mesh=mesh,transform=transform,inverse=np.linalg.inv(transform),check=lambda:None)
  g=GroundSupport.from_scorer(scorer,[[-.2,0,0],[.2,0,0]],[0]*8+[1])
  self.assertEqual(g.ground_cell_ids.tolist(),[0,1]);g.assert_matches(surface,transform)
  with self.assertRaises(GroundSupportUnavailable):g.assert_matches(SimpleNamespace(mesh=mesh,locator=locator))
  with self.assertRaises(GroundSupportUnavailable):g.assert_matches(surface,np.eye(4))
  mesh.Modified()
  with self.assertRaises(GroundSupportUnavailable):g.is_ground(0)

if __name__=='__main__':unittest.main()

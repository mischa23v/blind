import math,unittest
import numpy as np
from ground_support import GroundSupport,GroundSupportUnavailable

def classify(vertices,triangles,seeds=None):
 v=np.asarray(vertices,float);t=np.asarray(triangles,np.int64)
 return GroundSupport.from_geometry(np.arange(len(t),dtype=np.int64),t,np.arange(len(v),dtype=np.int64),v,np.ones(len(t),bool),[0]*9 if seeds is None else seeds)

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
  g=GroundSupport.from_geometry(np.array([91,4]),np.array([[0,1,2],[1,3,2]]),np.arange(4),np.array([[0,0,0],[1,0,0],[0,0,1],[1,0,1.]]),np.array([True,False]),[91]*9)
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
  with self.assertRaises(GroundSupportUnavailable):g.plane_height(0,0)

def grid(height,n=21,spacing=.01):
 v=np.array([[i*spacing,height(i*spacing,j*spacing),j*spacing] for i in range(n)for j in range(n)],float)
 t=[]
 for i in range(n-1):
  for j in range(n-1):
   a=i*n+j;t.extend([[a,a+n,a+1],[a+n,a+n+1,a+1]])
 return v,np.asarray(t,np.int64)

class PatchTests(unittest.TestCase):
 def test_noisy_microfacets_recovered_without_global_band(self):
  v,t=grid(lambda x,z:.0011 if abs(x-.10)<1e-9 and abs(z-.10)<1e-9 else 0.)
  g=classify(v,t)
  self.assertEqual(len(g.ground_cell_ids),len(t))
  self.assertGreater(g.receipt['newlyConnectedGroundFaces'],0)
  self.assertEqual(g.receipt['maximumLocalEveryVertexResidualMetres'],.002)
 def test_one_cm_bump_not_recovered(self):
  v,t=grid(lambda x,z:.01 if abs(x-.10)<1e-9 and abs(z-.10)<1e-9 else 0.)
  g=classify(v,t)
  elevated=np.flatnonzero(v[t,:,][...,1].max(axis=1)>.005)
  self.assertTrue(len(elevated)>0)
  self.assertTrue(all(not g.is_ground(int(x)) for x in elevated))
 def test_smooth_curvature_not_rejected_by_global_2mm_band(self):
  v,t=grid(lambda x,z:.04*x*x,n=31,spacing=.04)
  g=classify(v,t)
  self.assertEqual(len(g.ground_cell_ids),len(t))
  self.assertGreater(g.receipt['broadPlaneFit']['absoluteResidualQuantilesMetres']['p100'],.002)
  self.assertTrue(g.receipt['originalSeedComponentRetained'])
 def test_global_fit_is_frozen_not_recomputed_by_height_queries(self):
  v,t=grid(lambda x,z:.03*x+.01*z)
  g=classify(v,t);before=g.plane_coefficients.copy()
  self.assertAlmostEqual(g.plane_height(.1,.2),.005,places=10)
  np.testing.assert_array_equal(before,g.plane_coefficients)
  self.assertFalse(g.plane_coefficients.flags.writeable)

if __name__=='__main__':unittest.main(verbosity=2)

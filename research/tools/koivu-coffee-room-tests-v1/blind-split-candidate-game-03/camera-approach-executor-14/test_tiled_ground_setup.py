"""Authored same-candidate/same-classifier setup equivalence; no recorded mesh."""
from pathlib import Path
from types import SimpleNamespace
import unittest,numpy as np,vtk
import approach_episode
from ground_setup import shared_ground,GroundSupport,CANDIDATE_CAP
HERE=Path(__file__).resolve().parent

class SetupTests(unittest.TestCase):
    def test_classifier_diff_is_exactly_resource_cap(self):
        old=(HERE.parent/'ground-follow-v3/ground_support.py').read_text()
        new=(HERE/'ground_classifier_resource.py').read_text()
        self.assertEqual(new,old.replace('CANDIDATE_CAP = 2_000_000','CANDIDATE_CAP = 3_000_000'))
        self.assertEqual(CANDIDATE_CAP,3000000)
    def fixture(self,tilt=0.,float32=False):
        points=vtk.vtkPoints()
        if not float32:points.SetDataTypeToDouble()
        model=np.array([[-1,-tilt,-1],[1,tilt,-1],[-1,-tilt,1],[1,tilt,1],
            [.2,.05,.2],[.3,.05,.2],[.2,.05,.3],[0,0,0],[0,.1,0],[0,.1,.1]])
        theta=.2;c,s=np.cos(theta),np.sin(theta);T=np.eye(4);T[:3,:3]=1.02*np.array([[1,0,0],[0,c,-s],[0,s,c]]);T[:3,3]=[4,-2,1]
        for p in model@T[:3,:3].T+T[:3,3]:points.InsertNextPoint(*p)
        cells=vtk.vtkCellArray()
        for tri in ([0,1,2],[1,3,2],[4,5,6],[7,8,9]):
            cells.InsertNextCell(3)
            for i in tri:cells.InsertCellPoint(i)
        mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells)
        loc=vtk.vtkStaticCellLocator();loc.SetDataSet(mesh);loc.BuildLocator()
        surface=SimpleNamespace(mesh=mesh,locator=loc,errors=[])
        return SimpleNamespace(surface=surface,mesh=mesh,transform=T,inverse=np.linalg.inv(T),check=lambda:None)
    def equal(self,tilt,float32):
        scorer=self.fixture(tilt,float32);path=np.array([[-.2,0,0],[.2,0,0]]);seeds=[0]*8+[1];support=[[0,0,0]]*9;seen=[]
        old=approach_episode.GroundSupport.from_scorer(scorer,path,seeds,support)
        new=shared_ground(scorer,[path],seeds,support,seen.append)
        np.testing.assert_array_equal(old.ground_cell_ids,new.ground_cell_ids)
        np.testing.assert_array_equal(old.plane_coefficients,new.plane_coefficients)
        for key,value in old.receipt.items():
            if key!='candidateCap':self.assertEqual(new.receipt[key],value,key)
        self.assertEqual(len(seen),1);self.assertEqual(seen[0]['candidateCells'],old.receipt['candidateCells'])
        self.assertFalse(new.is_ground(2));self.assertFalse(new.is_ground(3))
        self.assertEqual(new.receipt['candidateCap'],3000000)
    def test_flat_exact_setup_equivalence(self):self.equal(0.,False)
    def test_tilted_original_float32_setup_equivalence(self):self.equal(.03,True)
    def test_resource_helper_owner(self):
        import sys
        self.assertEqual(Path(sys.modules[GroundSupport.__module__].__file__).resolve(),HERE/'ground_classifier_resource.py')
if __name__=='__main__':unittest.main(verbosity=2)

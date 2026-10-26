"""Authored equivalence only: identical v3 classification, old/new scorers."""
from pathlib import Path
import sys,math,unittest,ast
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'ground-follow-v3'))
from ground_support import GroundSupport
import numpy as np
import vtk
from oriented_ground_skip_container import GroundSkippingReferenceContainer
from oriented_ground_container import GroundedReferenceContainer
from oriented_container import OrientedReferenceContainer,GeometryFailure,sweep_enclosure
from reference_geometry import ReferenceSurface,serial_vtk

GROUND_FIELDS={'groundContactCount','groundContactEvent','groundContactFaceIDsFirst16',
 'groundContactFaceIDsTruncated','completeCandidateContactCounts'}

def scene(extras=(),ground_y=.01,transform=None):
    vertices=[[-3,ground_y,-3],[3,ground_y,-3],[3,ground_y,3],[-3,ground_y,3]]
    triangles=[[0,1,2],[0,2,3]]
    for points in extras:
        offset=len(vertices);vertices.extend(points);triangles.append([offset,offset+1,offset+2])
    transform=np.eye(4)if transform is None else transform
    p=vtk.vtkPoints();p.SetDataTypeToDouble()
    for v in vertices:p.InsertNextPoint(*(transform[:3,:3]@v+transform[:3,3]))
    cells=vtk.vtkCellArray()
    for t in triangles:
        cells.InsertNextCell(3)
        for i in t:cells.InsertCellPoint(i)
    mesh=vtk.vtkPolyData();mesh.SetPoints(p);mesh.SetPolys(cells)
    return ReferenceSurface(mesh)

def pair(surface,transform=None,cap=200000):
    transform=np.eye(4)if transform is None else transform
    raw=OrientedReferenceContainer(surface,transform)
    row=raw.support_probes([-1,0,0],0)
    ground=GroundSupport.from_scorer(raw,[[-1,0,0],[1,0,0]],
        [p['referenceCellID']for p in row['probes']])
    return (GroundedReferenceContainer(surface,transform,ground=ground,maximum_candidate_cells=cap),
            GroundSkippingReferenceContainer(surface,transform,ground=ground,maximum_candidate_cells=cap))

class EquivalenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):serial_vtk()
    def equal(self,old,new,start=(0,0,0),end=(0,0,0),yaw=0,delta=0):
        a=old.swept_contacts(start,end,yaw,delta);b=new.swept_contacts(start,end,yaw,delta)
        for key in a:
            if key not in ('actualBody','horizontalMargin'):self.assertEqual(a[key],b[key]);continue
            for field,value in a[key].items():
                if field not in GROUND_FIELDS:self.assertEqual(value,b[key][field],(key,field))
            for field in GROUND_FIELDS-{'completeCandidateContactCounts'}:self.assertIsNone(b[key][field])
            self.assertFalse(b[key]['completeCandidateContactCounts'])
            self.assertTrue(b[key]['completeNonGroundCandidateContactCounts'])
            self.assertFalse(b[key]['skippedGroundCandidatesAreContacts'])
            self.assertEqual(b[key]['candidateTriangles'],b[key]['skippedGroundCandidateCount']+b[key]['exactNonGroundTriangleTests'])
        return a,b
    def test_ground_only_overlap_unmeasured_not_zero(self):
        old,new=pair(scene());a,b=self.equal(old,new)
        self.assertGreater(a['actualBody']['groundContactCount'],0)
        self.assertGreater(b['actualBody']['skippedGroundCandidateCount'],0)
        self.assertEqual(new.triangle_queries,0);self.assertGreater(old.triangle_queries,0)
    def test_ground_broadphase_candidates_are_not_contacts(self):
        old,new=pair(scene(ground_y=0));a,b=self.equal(old,new)
        self.assertEqual(a['actualBody']['groundContactCount'],0)
        self.assertGreater(b['actualBody']['skippedGroundCandidateCount'],0)
    def test_detached_one_cm_top_remains_exact_contact(self):
        old,new=pair(scene([[[0,.02,0],[.01,.02,0],[0,.02,.01]]]))
        a,b=self.equal(old,new);self.assertTrue(b['actualBody']['contact']);self.assertEqual(b['actualBody']['nonGroundContactCount'],1)
    def test_thin_vertical_riser(self):
        old,new=pair(scene([[[0,.01,-.01],[0,.02,-.01],[0,.02,.01]]]))
        _,b=self.equal(old,new);self.assertTrue(b['actualBody']['contact'])
    def test_wall_crossing_sweep(self):
        old,new=pair(scene([[[0,.2,-1],[0,1.5,-1],[0,.2,1]]]))
        _,b=self.equal(old,new,(-.5,0,0),(.5,0,0));self.assertTrue(b['actualBody']['contact'])
    def test_wholly_contained_triangle(self):
        old,new=pair(scene([[[0,.5,0],[.01,.5,0],[0,.5,.01]]]))
        _,b=self.equal(old,new);self.assertEqual(b['actualBody']['reason'],'containedTriangleVertex')
    def test_head_contact(self):
        old,new=pair(scene([[[-.1,1.59,-.1],[.1,1.59,-.1],[0,1.59,.1]]]))
        _,b=self.equal(old,new);self.assertTrue(b['actualBody']['contact'])
    def test_margin_only_contact(self):
        old,new=pair(scene([[[.25,.5,-.01],[.25,.7,-.01],[.25,.5,.01]]]))
        _,b=self.equal(old,new);self.assertFalse(b['actualBody']['contact']);self.assertTrue(b['horizontalMargin']['contact'])
    def test_multiple_obstacles_first_id_order_and_complete_count(self):
        old,new=pair(scene([[[0,.5,0],[.01,.5,0],[0,.5,.01]],[[.02,.8,0],[.03,.8,0],[.02,.8,.01]]]))
        _,b=self.equal(old,new);self.assertEqual(b['actualBody']['nonGroundContactCount'],2)
    def test_yaw_and_translation_enclosure_unchanged(self):
        old,new=pair(scene([[[.18,.5,.18],[.19,.6,.18],[.18,.5,.19]]]))
        self.equal(old,new,(-.01,0,0),(.01,.001,.005),.3,math.radians(1))
    def test_positive_similarity(self):
        t=np.eye(4);c,s=math.cos(.2),math.sin(.2);t[:3,:3]=1.02*np.array([[c,-s,0],[s,c,0],[0,0,1]]);t[:3,3]=[4,-2,1]
        old,new=pair(scene([[[0,.5,0],[.01,.5,0],[0,.5,.01]]],transform=t),t)
        self.equal(old,new)
    def test_candidate_cap_includes_skipped_ground(self):
        old,new=pair(scene(),cap=1)
        for scorer in (old,new):
            with self.assertRaises(GeometryFailure):scorer.swept_contacts([0,0,0],[0,0,0],0,0)
    def test_owner_and_transform_guard(self):
        old,new=pair(scene())
        with self.assertRaises(RuntimeError):GroundSkippingReferenceContainer(scene(),np.eye(4),ground=new.ground)
        t=np.eye(4);t[0,3]=1
        with self.assertRaises(RuntimeError):GroundSkippingReferenceContainer(new.surface,t,ground=new.ground)
    def test_mesh_mutation_and_errors_retire(self):
        for mutation in ('mesh','errors'):
            old,new=pair(scene())
            if mutation=='mesh':new.mesh.Modified()
            else:new.surface.errors.append('authored error')
            for scorer in (old,new):
                with self.assertRaises(RuntimeError):scorer.swept_contacts([0,0,0],[0,0,0],0,0)
    def test_support_rays_unchanged(self):
        old,new=pair(scene());self.assertEqual(old.support_probes([0,0,0],.3),new.support_probes([0,0,0],.3))
    def test_invalid_box_rejected(self):
        old,new=pair(scene())
        for scorer in (old,new):
            with self.assertRaises(ValueError):scorer.contact_corners(np.zeros((8,3)))
    def test_skip_is_before_getcell_source_order(self):
        source=(Path(__file__).parent/'oriented_ground_skip_container.py').read_text()
        ast.parse(source)
        self.assertLess(source.index('if self._ground.is_ground(cell_id)'),source.index('self.mesh.GetCell(cell_id,self.cell)'))
        self.assertLess(source.index('count>self.maximum_candidate_cells'),source.index('if self._ground.is_ground(cell_id)'))

if __name__=='__main__':unittest.main(verbosity=2)

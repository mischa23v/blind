"""Authored v6 exact-collision equivalence and conservative bounds fixtures."""
from pathlib import Path
import sys,math,unittest,ast
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'ground-follow-v3'))
from ground_support import GroundSupport
import numpy as np
import vtk
from oriented_ground_obb_container import GroundOBBReferenceContainer as GroundSkippingReferenceContainer
from oriented_ground_vector_container import GroundVectorReferenceContainer
from vtk.util.numpy_support import vtk_to_numpy
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
            self.assertEqual(b[key]['candidateTriangles'],b[key]['skippedGroundCandidateCount']+b[key]['rejectedNonGroundBoundsCandidates']+b[key]['exactNonGroundTriangleTests'])
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
        source=(Path(__file__).parent/'oriented_ground_obb_container.py').read_text()
        ast.parse(source)
        self.assertLess(source.index('exact_ids,bounds_receipt=self._filter_box_bounds'),source.index('self.mesh.GetCell(cell_id,self.cell)'))
        self.assertLess(source.index('count>self.maximum_candidate_cells'),source.index('candidate_ids=np.fromiter'))



def box_corners(yaw=.6):
    return sweep_enclosure([0,0,0],[0,0,0],yaw,0,half_forward=.15,
        half_lateral=.225,height=1.6,floor_contact_exclusion=.002)[0]

def model_triangle(corners,axis,coordinate):
    edges=np.column_stack((corners[1]-corners[0],corners[3]-corners[0],corners[4]-corners[0]))
    p=np.full((3,3),.5);p[:,axis]=coordinate
    other=[i for i in range(3)if i!=axis]
    p[1,other[0]]+=.0005;p[2,other[1]]+=.0005
    return corners[0]+p@edges.T

def similarity():
    a=.3;b=.2;c,s=math.cos(a),math.sin(a);d,e=math.cos(b),math.sin(b)
    t=np.eye(4);t[:3,:3]=1.02*np.array([[c,-s,0],[s,c,0],[0,0,1]])@np.array([[1,0,0],[0,d,-e],[0,e,d]])
    t[:3,3]=[4,-2,1];return t

class BoundsTests(unittest.TestCase):
    def compare_box(self,vertices,corners,transform=None):
        _,fast=pair(scene([vertices],transform=transform),transform)
        old=GroundVectorReferenceContainer(fast.surface,fast.transform,ground=fast.ground)
        before=old.contact_corners(corners);after=fast.contact_corners(corners)
        for k in ('contact','candidateTriangles','firstReferenceCellID','reason','nonGroundContactCount','firstTriangleModelHeightRange'):
            self.assertEqual(before.get(k),after.get(k),k)
        return before,after,fast
    def test_tolerance_admitted_vertices_retained_on_all_six_faces(self):
        corners=box_corners();t=similarity()
        for axis in range(3):
            for coordinate in (-.5e-6,1+.5e-6):
                with self.subTest(axis=axis,coordinate=coordinate):
                    old,new,_=self.compare_box(model_triangle(corners,axis,coordinate),corners,t)
                    self.assertTrue(old['contact']);self.assertTrue(new['contact'])
                    self.assertEqual(new['rejectedNonGroundBoundsCandidates'],0)
    def test_closed_boundaries_retained_on_all_six_faces(self):
        corners=box_corners();t=similarity()
        for axis in range(3):
            for coordinate in (0.,1.):
                old,new,_=self.compare_box(model_triangle(corners,axis,coordinate),corners,t)
                self.assertTrue(old['contact']);self.assertTrue(new['contact'])
    def test_padding_retains_near_miss_for_exact_predicate(self):
        corners=box_corners();old,new,_=self.compare_box(model_triangle(corners,0,1+5e-6),corners,similarity())
        self.assertFalse(old['contact']);self.assertFalse(new['contact'])
        self.assertEqual(new['rejectedNonGroundBoundsCandidates'],0)
    def test_outside_rotated_box_but_inside_world_aabb_rejected(self):
        corners=box_corners();old,new,_=self.compare_box(model_triangle(corners,0,1.05),corners,similarity())
        self.assertFalse(new['contact']);self.assertGreater(old['exactNonGroundTriangleTests'],0)
        self.assertGreater(new['rejectedNonGroundBoundsCandidates'],0)
    def test_one_vertex_inside_prevents_rejection(self):
        corners=box_corners();v=model_triangle(corners,0,1.05)
        v[0]=(corners[0]+corners[6])*.5
        old,new,_=self.compare_box(v,corners,similarity())
        self.assertTrue(old['contact']);self.assertEqual(new['rejectedNonGroundBoundsCandidates'],0)
    def test_zero_copy_views_share_vtk_memory_and_are_readonly(self):
        _,fast=pair(scene())
        for view,native in zip((fast._points,fast._offsets,fast._connectivity),fast._vtk_arrays):
            self.assertTrue(np.shares_memory(view,vtk_to_numpy(native)));self.assertFalse(view.flags.owndata);self.assertFalse(view.flags.writeable)
    def test_array_revision_retires_scorer(self):
        for index in range(3):
            _,fast=pair(scene());fast._vtk_arrays[index].Modified()
            with self.assertRaises(GeometryFailure):fast.swept_contacts([0,0,0],[0,0,0],0,0)
    def test_filter_preserves_survivor_order_and_duplicates(self):
        corners=box_corners();extras=[model_triangle(corners,0,x)for x in (2.,.5,3.,.6)]
        _,fast=pair(scene(extras));q=corners@fast.transform[:3,:3].T+fast.transform[:3,3]
        kept,_=fast._filter_box_bounds(np.array([4,3,2,5,3]),q)
        self.assertEqual(kept.tolist(),[3,5,3])
    def test_empty_filter(self):
        _,fast=pair(scene());q=box_corners();kept,row=fast._filter_box_bounds(np.array([],dtype=np.int64),q)
        self.assertEqual(kept.tolist(),[]);self.assertFalse(row['fallbackAllExact'])
    def test_skinny_box_falls_back_to_all_exact(self):
        _,fast=pair(scene());q=box_corners();q[:,0]*=1e-8
        kept,row=fast._filter_box_bounds(np.array([0,1]),q)
        self.assertEqual(kept.tolist(),[0,1]);self.assertTrue(row['fallbackAllExact'])
    def test_large_reference_translation(self):
        corners=box_corners();t=similarity();t[:3,3]+=[1e6,-1e6,1e6]
        self.compare_box(model_triangle(corners,0,1+.5e-6),corners,t)
    def test_chunk_boundary_stable_order(self):
        _,fast=pair(scene([[[0,.5,0],[.01,.5,0],[0,.5,.01]]]))
        ids=np.full(32769,2,dtype=np.int64);q=box_corners()
        kept,_=fast._filter_box_bounds(ids,q);np.testing.assert_array_equal(kept,ids)
    def test_all_surviving_predicates_and_non_ground_count_retained(self):
        corners=box_corners();extras=[model_triangle(corners,0,x)for x in (2.,.5,3.,.6)]
        _,fast=pair(scene(extras));old=GroundVectorReferenceContainer(fast.surface,fast.transform,ground=fast.ground)
        a=old.contact_corners(corners);b=fast.contact_corners(corners)
        self.assertEqual(a['firstReferenceCellID'],b['firstReferenceCellID']);self.assertEqual(a['nonGroundContactCount'],2);self.assertEqual(a['nonGroundContactCount'],b['nonGroundContactCount'])
        self.assertLess(b['exactNonGroundTriangleTests'],a['exactNonGroundTriangleTests'])

if __name__=='__main__':unittest.main(verbosity=2)

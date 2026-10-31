"""Prepared synthetic VTK old-versus-recorded equality controls; NOT RUN."""
import importlib.util, pathlib, unittest
import numpy as np
from oriented_container import BodyGeometry
from oriented_ground_container import GroundedReferenceContainer as Original
from ground_support import GroundSupport
from reference_geometry import ReferenceSurface,serial_vtk
from test_oriented_container import mesh,floor
H=pathlib.Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('recorded_kernel',H/'oriented_ground_container_debug.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)

class AdditiveRecorderKernelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):serial_vtk()
    def compare(self,triangles,a,b,yaw,dyaw):
        surface=ReferenceSurface(mesh(triangles));identity=np.eye(4);identity.setflags(write=False)
        ids=np.array([],dtype=np.int64);ids.setflags(write=False)
        empty=GroundSupport(ids,{'classification':'unknown'},surface,surface.mesh,int(surface.mesh.GetMTime()),identity)
        hits=[];original=Original(surface,identity,ground=empty,body=BodyGeometry())
        recorded=module.GroundedReferenceContainer(surface,identity,ground=empty,body=BodyGeometry(),
            contact_recorder=lambda query,cell,reason:hits.append((query,cell,reason)))
        old=original.swept_contacts(a,b,yaw,dyaw);new=recorded.swept_contacts(a,b,yaw,dyaw)
        self.assertEqual(old,new)
        self.assertEqual((original.box_queries,original.triangle_queries),(recorded.box_queries,recorded.triangle_queries))
        for query,kind in enumerate(('actualBody','horizontalMargin'),1):
            selected=[cell for q,cell,_ in hits if q==query]
            self.assertEqual(len(selected),old[kind]['nonGroundContactCount'])
            if selected:self.assertEqual(selected[0],old[kind]['firstReferenceCellID'])
        return hits,new
    def test_all_floor_and_upper_ids_retained(self):
        hits,result=self.compare(floor(y=.01)+[[[-.01,.8,-.01],[.01,.8,-.01],[0,.9,.01]]],
                                 [0,0,0],[0,0,0],0,0)
        self.assertEqual({cell for q,cell,_ in hits if q==1},{0,1,2})
        self.assertEqual(result['actualBody']['nonGroundContactCount'],3)
    def test_margin_only_results_unchanged(self):
        hits,result=self.compare([[[.25,.5,-.01],[.25,.6,-.01],[.25,.5,.01]]],
                                 [0,0,0],[0,0,0],0,0)
        self.assertFalse(result['actualBody']['contact']);self.assertTrue(result['horizontalMargin']['contact'])
        self.assertEqual([q for q,_,_ in hits],[2])
    def test_translation_and_turn_enclosure_results_unchanged(self):
        self.compare(floor(y=.01)+[[[.1,.1,-.01],[.1,.5,-.01],[.1,.1,.01]]],
                     [0,0,0],[.025,0,0],.3,.017)

if __name__=='__main__':unittest.main(verbosity=2)

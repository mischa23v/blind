"""Prepared synthetic kernel controls; root executes only inside aggregate guard."""
import unittest
import numpy as np
from oriented_container import BodyGeometry
from oriented_ground_container import GroundedReferenceContainer
from ground_support import GroundSupport
from reference_geometry import ReferenceSurface,serial_vtk
from test_oriented_container import mesh,floor

class RawFloorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):serial_vtk()
    def scorer(self,triangles):
        surface=ReferenceSurface(mesh(triangles));identity=np.eye(4);identity.setflags(write=False)
        ids=np.array([],dtype=np.int64);ids.setflags(write=False)
        empty=GroundSupport(ids,{'classification':'unknown'},surface,surface.mesh,int(surface.mesh.GetMTime()),identity)
        return GroundedReferenceContainer(surface,identity,ground=empty,body=BodyGeometry(floor_contact_exclusion=.002))
    def test_inherited_2mm_trim_and_above_trim_raw_floor_contacts(self):
        below=self.scorer(floor(y=.001)).swept_contacts([0,0,0],[.025,0,0],0,0)
        for k in ('actualBody','horizontalMargin'):self.assertFalse(below[k]['contact'])
        s=self.scorer(floor(y=.01))
        r=s.swept_contacts([0,0,0],[.025,0,0],0,0)
        for k in ('actualBody','horizontalMargin'):
            self.assertTrue(r[k]['contact']);self.assertEqual(r[k]['groundContactCount'],0)
            self.assertEqual(r[k]['nonGroundContactCount'],2)
            self.assertEqual(r[k]['firstTriangleModelHeightRange'],[.01,.01])
            self.assertEqual(r[k]['sweep']['floorContactExclusionMetres'],.002)
    def test_all_hit_floor_does_not_short_circuit_upper_contact(self):
        s=self.scorer(floor(y=.01)+[[[-.01,.8,-.01],[.01,.8,-.01],[0,.9,.01]]])
        r=s.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertEqual(r['actualBody']['nonGroundContactCount'],3)
        self.assertEqual(r['horizontalMargin']['nonGroundContactCount'],3)
    def test_margin_is_separate_not_body_contact(self):
        s=self.scorer([[[.25,.5,-.01],[.25,.6,-.01],[.25,.5,.01]]])
        r=s.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertFalse(r['actualBody']['contact']);self.assertTrue(r['horizontalMargin']['contact'])
        self.assertFalse(r['marginExtendsVerticalHeight'])

if __name__=='__main__':unittest.main(verbosity=2)

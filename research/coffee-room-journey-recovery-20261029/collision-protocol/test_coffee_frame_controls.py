"""Authored coordinate/annotation controls. Source only, not run."""
import unittest
import numpy as np
from test_oriented_ground_container import scene
from oriented_container import OrientedReferenceContainer
from oriented_ground_container import GroundedReferenceContainer
from ground_support import GroundSupport
from reference_geometry import serial_vtk
class CoffeeFrameControls(unittest.TestCase):
 @classmethod
 def setUpClass(cls):serial_vtk()
 def test_shifted_ripple_ground_and_detached_low_top_both_retained(self):
  f=-1.6301633051396203
  # One common rigid translation, not source flattening. Floor at local +1cm.
  surface=scene([[0,f+.02,0],[.02,f+.02,0],[0,f+.02,.02]],[[0,1,2]],ground_y=f+.01)
  T=np.eye(4);T[1,3]=f;local=OrientedReferenceContainer(surface,T)
  probes=local.support_probes([-1,0,0],0)
  self.assertEqual(probes['hitCount'],9)
  g=GroundSupport.from_scorer(local,[[-1,0,0],[1,0,0]],[p['referenceCellID']for p in probes['probes']])
  labelled=GroundedReferenceContainer(surface,T,ground=g)
  ids=np.array([],dtype=np.int64);ids.setflags(write=False);I=np.eye(4);I.setflags(write=False)
  unknown=GroundSupport(ids,{'classification':'unknown'},surface,surface.mesh,int(surface.mesh.GetMTime()),I)
  raw=GroundedReferenceContainer(surface,I,ground=unknown)
  a=raw.swept_contacts([0,f,0],[0,f,0],0,0);b=labelled.swept_contacts([0,0,0],[0,0,0],0,0)
  for k in ('actualBody','horizontalMargin'):
   self.assertEqual(a[k]['groundContactCount']+a[k]['nonGroundContactCount'],b[k]['groundContactCount']+b[k]['nonGroundContactCount'])
   self.assertEqual(b[k]['groundContactCount'],2);self.assertEqual(b[k]['nonGroundContactCount'],1)
   self.assertTrue(b[k]['contact']);self.assertEqual(b[k]['firstReferenceCellID'],2)

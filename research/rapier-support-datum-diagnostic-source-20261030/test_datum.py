#!/usr/bin/env python3
"""Tiny analytic arithmetic tests only; no real geometry or native libraries."""
import math, unittest
from prepare_datum import hit, normal, sample_xz, inspect
class DatumTests(unittest.TestCase):
 def probe(self,y=0):return {'foot':[0,y,0],'yawRadians':0,'id':'synthetic','kind':'stationary','desiredDelta':[0,0,0]}
 def floor(self,y=0):return [(-1,y,-1),(-1,y,1),(1,y,-1),(1,y,1)],[(0,1,2),(2,1,3)]
 def test_flat_candidate_not_authority(self):
  v,t=self.floor();r=inspect(v,t,self.probe());self.assertAlmostEqual(r['candidateFoot'][1],.002);self.assertFalse(r['movementEligible']);self.assertFalse(r['supportEstablished']);self.assertEqual(r['missingRaySampleIndices'],[]);self.assertEqual(r['unoffsetPlaneMaxDatumY'],0);self.assertEqual(r['queryPlacementOffsetMetres'],.002);self.assertEqual(r['selectedTriangleAreaSquareMetres'],2);self.assertTrue(any(c['extrapolated'] for c in r['nominalCornerCoverage']))
 def test_missing_is_unresolved(self):
  v,t=self.floor();r=inspect(v,t,self.probe(1));self.assertEqual(r['status'],'unresolved');self.assertIsNone(r['candidateFoot'])
 def test_excluded_component(self):
  v,t=self.floor();self.assertEqual(inspect(v,t,self.probe(),set())['status'],'unresolved')
 def test_layers_not_deleted(self):
  v,t=self.floor();v2,t2=self.floor(.04);v+=v2;t+=[tuple(i+4 for i in x) for x in t2];r=inspect(v,t,self.probe());self.assertEqual({round(s['height'],4) for s in r['allSampleLayers'][4]},{0,.04});self.assertAlmostEqual(r['candidateFoot'][1],.002)
 def test_yaw_footprint(self):
  s=sample_xz([0,0,0],math.pi/2);self.assertAlmostEqual(s[0][0],.225);self.assertAlmostEqual(s[0][1],-.15)
 def test_vertical_or_reverse_not_floor(self):
  self.assertIsNone(hit(0,0,(0,0,0),(0,1,0),(0,0,1)))
  v,t=self.floor();t=[tuple(reversed(q)) for q in t];self.assertEqual(inspect(v,t,self.probe())['status'],'unresolved')
 def test_tilt_uses_corner_max(self):
  v,t=self.floor();v=[(x,.1*x,z) for x,y,z in v];r=inspect(v,t,self.probe());self.assertAlmostEqual(r['candidateFoot'][1],.017)
if __name__=='__main__':unittest.main()

"""Authored geometry tests only; no recorded mesh, motion episode or planner."""
from pathlib import Path
import math
import sys
import unittest
import numpy as np
import vtk
from oriented_container import BodyGeometry,OrientedReferenceContainer,sweep_enclosure,GeometryFailure
from reference_band_box import ReferenceBandBox
from reference_geometry import ReferenceSurface,serial_vtk


def mesh(triangles,transform=None):
    transform=np.eye(4)if transform is None else np.asarray(transform)
    points=vtk.vtkPoints();points.SetDataTypeToDouble();cells=vtk.vtkCellArray()
    for tri in triangles:
        cells.InsertNextCell(3)
        for p in tri:
            q=transform@[*p,1.];cells.InsertCellPoint(points.InsertNextPoint(*q[:3]))
    result=vtk.vtkPolyData();result.SetPoints(points);result.SetPolys(cells);return result


def floor(y=0.,half=3.):
    return [[[-half,y,-half],[half,y,-half],[half,y,half]],
            [[-half,y,-half],[half,y,half],[-half,y,half]]]


def enclosure(a,b,yaw,delta,pad=0.):
    body=BodyGeometry()
    return sweep_enclosure(a,b,yaw,delta,half_forward=body.depth*.5+pad,
        half_lateral=body.width*.5+pad,height=body.height,
        floor_contact_exclusion=body.floor_contact_exclusion)


class OrientedTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):serial_vtk()

    def scorer(self,triangles,transform=None,**kwargs):
        a=np.eye(4)if transform is None else transform
        return OrientedReferenceContainer(ReferenceSurface(mesh(triangles,a)),a,**kwargs)

    def test_fixed_actual_body_and_separate_margin(self):
        b=BodyGeometry();self.assertEqual((b.width,b.depth,b.height,b.horizontal_margin),(.45,.30,1.6,.15))
        s=self.scorer([[[.25,.5,-.01],[.25,.6,-.01],[.25,.5,.01]]])
        q=s.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertFalse(q['actualBody']['contact']);self.assertTrue(q['horizontalMargin']['contact'])
        self.assertFalse(q['marginExtendsVerticalHeight']);self.assertFalse(q['physicalAuthority'])

    def test_one_centimetre_thin_geometry_retained(self):
        s=self.scorer([[[-1,.01,-1],[1,.01,-1],[0,.01,1]]])
        q=s.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertTrue(q['actualBody']['contact'])
        np.testing.assert_allclose(q['actualBody']['firstTriangleHeightRelativeToStartFootRange'],[.01,.01])

    def test_contained_triangle_and_initial_overlap(self):
        s=self.scorer([[[0,.5,0],[.01,.5,0],[0,.51,.01]]])
        q=s.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertTrue(q['actualBody']['contact']);self.assertEqual(q['actualBody']['reason'],'containedTriangleVertex')

    def test_clear_endpoints_do_not_hide_crossed_wall(self):
        s=self.scorer([[[0,0,-2],[0,2,-2],[0,1,2]]])
        self.assertFalse(s.swept_contacts([-.5,0,0],[-.5,0,0],0,0)['actualBody']['contact'])
        self.assertFalse(s.swept_contacts([.5,0,0],[.5,0,0],0,0)['actualBody']['contact'])
        self.assertTrue(s.swept_contacts([-.5,0,0],[.5,0,0],0,0)['actualBody']['contact'])

    def test_turn_sweep_catches_geometry_missed_by_both_endpoint_rectangles(self):
        s=self.scorer([[[.25,.5,-.05],[.253,.5,-.05],[.25,.503,-.047]]])
        for yaw in (0,math.pi/2):
            self.assertFalse(s.swept_contacts([0,0,0],[0,0,0],yaw,0)['actualBody']['contact'])
        self.assertTrue(s.swept_contacts([0,0,0],[0,0,0],0,math.pi/2)['actualBody']['contact'])

    def test_wrong_actual_one_degree_increment_is_scored_not_nominal_command(self):
        s=self.scorer([[[.16,.5,.2278],[.175,.5,.2278],[.16,.6,.2278]]])
        nominal=s.swept_contacts([0,0,0],[.025,0,0],0,0)
        angle=math.radians(1)
        actual=s.swept_contacts([0,0,0],[.025*math.cos(angle),0,.025*math.sin(angle)],0,angle)
        self.assertFalse(nominal['actualBody']['contact']);self.assertTrue(actual['actualBody']['contact'])

    def test_head_height_and_complete_vertical_sweep(self):
        s=self.scorer(floor(1.62))
        self.assertFalse(s.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']['contact'])
        self.assertTrue(s.swept_contacts([0,0,0],[0,.03,0],0,0)['actualBody']['contact'])

    def test_vertical_descent_not_hidden_by_original_floor_plane(self):
        s=self.scorer(floor(-.02))
        self.assertFalse(s.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']['contact'])
        self.assertTrue(s.swept_contacts([0,0,0],[0,-.03,0],0,0)['actualBody']['contact'])

    def test_existing_two_mm_floor_exclusion_is_explicit_not_three_cm(self):
        s=self.scorer(floor())
        q=s.swept_contacts([0,0,0],[0,0,0],0,0)
        self.assertFalse(q['actualBody']['contact'])
        self.assertEqual(q['actualBody']['sweep']['floorContactExclusionMetres'],.002)

    def test_closed_endpoint_boundary_contact(self):
        s=self.scorer([[[.15,.5,-.01],[.15,.6,-.01],[.15,.5,.01]]])
        self.assertTrue(s.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']['contact'])

    def test_zero_yaw_translation_exactly_matches_frozen_axis_box_core(self):
        s=self.scorer(floor()+[[[.2,.5,-.2],[.2,.8,-.2],[.2,.5,.2]]])
        axis=ReferenceBandBox(s.surface,np.eye(4));b=BodyGeometry()
        for a,z in (([0,0,0],[0,0,0]),([0,0,0],[.1,0,0]),([-1,0,1],[-.5,0,1])):
            row=s.swept_contacts(a,z,0,0)
            for key,pad in (('actualBody',0),('horizontalMargin',.15)):
                lo=np.minimum(a,z)+[-b.depth*.5-pad,b.floor_contact_exclusion,-b.width*.5-pad]
                hi=np.maximum(a,z)+[b.depth*.5+pad,b.height,b.width*.5+pad]
                self.assertEqual(row[key]['contact'],axis.contact(lo,hi)['contact'])

    def test_yaw_convention_and_explicit_wrap_increment(self):
        corners,_=enclosure([0,0,0],[0,0,0],math.pi/2,0)
        forward_edge=corners[1]-corners[0]
        np.testing.assert_allclose(forward_edge,[0,0,.30],atol=1e-14)
        _,q=enclosure([0,0,0],[0,0,0],math.pi-.002,.004)
        self.assertAlmostEqual(q['midpointYawRadians'],math.pi)
        self.assertLess(q['rotationPaddingMetresPerHorizontalAxis'],.001)

    def test_supplied_full_turn_not_silently_reduced_to_zero(self):
        s=self.scorer([[[.25,.5,0],[.253,.5,0],[.25,.503,.003]]])
        self.assertFalse(s.swept_contacts([0,0,0],[0,0,0],0,0)['actualBody']['contact'])
        self.assertTrue(s.swept_contacts([0,0,0],[0,0,0],0,2*math.pi)['actualBody']['contact'])

    def test_continuous_enclosure_contains_authored_intermediate_corners(self):
        rng=np.random.default_rng(20261026)
        for pad in (0.,.15):
            for _ in range(12):
                a=np.array([0.,0.,0.]);z=rng.uniform(-.025,.025,3)
                yaw=rng.uniform(-math.pi,math.pi);delta=rng.uniform(-math.radians(1),math.radians(1))
                box,_=enclosure(a,z,yaw,delta,pad);base=box[0]
                edges=np.column_stack((box[1]-base,box[3]-base,box[4]-base));inv=np.linalg.inv(edges)
                for t in np.linspace(0,1,7):
                    centre=a+(z-a)*t
                    for u in np.linspace(0,1,7):
                        angle=yaw+u*delta;c,s=math.cos(angle),math.sin(angle)
                        for x in (-.15-pad,.15+pad):
                            for lateral in (-.225-pad,.225+pad):
                                for h in (.002,1.6):
                                    p=centre+np.array([x*c-lateral*s,h,x*s+lateral*c])
                                    normalized=inv@(p-base)
                                    self.assertTrue(np.all(normalized>=-1e-10)and np.all(normalized<=1+1e-10))

    def test_transformed_similarity_equivalence(self):
        theta=.31;T=np.eye(4)
        T[:3,:3]=1.02079084*np.array([[math.cos(theta),-math.sin(theta),0],
                                     [math.sin(theta),math.cos(theta),0],[0,0,1]])
        T[:3,3]=[2,-3,4]
        triangles=floor()+[[[.25,.5,-.05],[.253,.5,-.05],[.25,.503,-.047]]]
        a=self.scorer(triangles);b=self.scorer(triangles,T)
        for delta in (0,math.pi/2):
            aa=a.swept_contacts([0,0,0],[0,0,0],0,delta);bb=b.swept_contacts([0,0,0],[0,0,0],0,delta)
            for key in ('actualBody','horizontalMargin'):self.assertEqual(aa[key]['contact'],bb[key]['contact'])

    def test_invalid_delta_corners_cap_and_mutation_fail_not_clear(self):
        s=self.scorer(floor())
        for delta in (float('nan'),2*math.pi+.001):
            with self.assertRaises(ValueError):s.swept_contacts([0,0,0],[0,0,0],0,delta)
        corners,_=enclosure([0,0,0],[0,0,0],0,0);corners[6,0]+=.01
        with self.assertRaises(ValueError):s.contact_corners(corners)
        small=self.scorer(floor(.01),maximum_candidate_cells=1)
        with self.assertRaises(GeometryFailure):small.swept_contacts([0,0,0],[0,0,0],0,0)
        s.surface.mesh.Modified()
        with self.assertRaises(GeometryFailure):s.swept_contacts([0,0,0],[0,0,0],0,0)

    def test_latched_error_rejects_probes_and_contact(self):
        s=self.scorer(floor());s.box.InvokeEvent('ErrorEvent')
        with self.assertRaises(GeometryFailure):s.swept_contacts([0,0,0],[0,0,0],0,0)
        with self.assertRaises(GeometryFailure):s.support_probes([0,0,0],0)

    def test_nine_probes_include_corners_with_absolute_vertical_interval(self):
        s=self.scorer(floor(.02));q=s.support_probes([0,.5,0],math.pi/2)
        self.assertEqual((q['hitCount'],q['missingCount'],len(q['probes'])),(9,0,9))
        np.testing.assert_allclose([r['modelHeightY']for r in q['probes']],[.02]*9,atol=1e-12)
        self.assertEqual((q['rayTopModelY'],q['rayBottomModelY']),(.15,-.25))
        np.testing.assert_allclose(q['probes'][5]['modelXZ'],[.225,-.15],atol=1e-14)
        self.assertFalse(q['semanticFloorEstablished']);self.assertFalse(q['continuousSupportProven'])

    def test_missing_corner_probes_are_retained(self):
        s=self.scorer(floor(0.,half=.18));q=s.support_probes([0,0,0],0)
        self.assertEqual(q['missingCount'],4)
        self.assertTrue(all(r['modelHeightY']is None for r in q['probes'][5:]))

    def test_five_plus_four_hits_do_not_accept_or_follow_a_raised_surface(self):
        s=self.scorer(floor()+floor(.10));foot=np.array([0.,0.,0.]);q=s.support_probes(foot,0)
        np.testing.assert_allclose([r['modelHeightY']for r in q['probes']],[.10]*9)
        np.testing.assert_array_equal(foot,[0,0,0]);self.assertFalse(q['physicalClearanceEstablished'])
        self.assertNotIn('supported',q);self.assertFalse(q['physicalAuthority'])


if __name__=='__main__':unittest.main(verbosity=2)

import math, unittest
import numpy as np
from margin_variants import geometry, rectangle_module, base_module

class Tests(unittest.TestCase):
    def test_declared_profiles(self):
        for name, width, depth, radius in [("body45cmMargin0", .45, .30, .225),
            ("body45cmMargin5cm", .55, .40, .275), ("abstract28cmProfile", .28, .30, .15)]:
            g = geometry(name)
            self.assertAlmostEqual(g["horizontalEnvelopeWidth"], width)
            self.assertAlmostEqual(g["horizontalEnvelopeDepth"], depth)
            self.assertAlmostEqual(g["nativeRadiusIntended"], radius)
            self.assertEqual(g["nativeCellSize"], .025)
            self.assertEqual(g["height"], 1.60)
            self.assertEqual(g["nativeHeight"], 1.75)

    def test_rectangle_parameter_namespaces_do_not_mutate_original(self):
        cm = base_module(); original, _ = cm.modules(); before = original.RB.copy()
        first = rectangle_module("body45cmMargin0"); second = rectangle_module("body45cmMargin5cm")
        np.testing.assert_array_equal(original.RB, before)
        self.assertIsNot(first, second)
        self.assertAlmostEqual(first.RB[:, 1].max(), .225)
        self.assertAlmostEqual(second.RB[:, 1].max(), .275)

    def test_fifty_cm_corridor_accepts_fortyfive_not_fiftyfive(self):
        mask = np.ones((40, 10), bool); origin = (-1., -.25)
        self.assertTrue(rectangle_module("body45cmMargin0").rect_ok(mask, origin, 0., 0., 0.))
        self.assertFalse(rectangle_module("body45cmMargin5cm").rect_ok(mask, origin, 0., 0., 0.))

    def test_abstract_disc_is_not_full_rectangle_turn_clearance(self):
        mask = np.ones((40, 6), bool); origin = (-1., -.15)
        rr = rectangle_module("abstract28cmProfile")
        self.assertTrue(rr.rect_ok(mask, origin, 0., 0., 0.))
        self.assertFalse(rr.rect_ok(mask, origin, 0., 0., math.pi/4))

    def test_predeclared_fallback_changes_proposal_not_body(self):
        g = geometry("abstract28cmProfile", .125)
        self.assertEqual(g["width"], .28)
        self.assertEqual(g["depth"], .30)
        self.assertEqual(g["margin"], 0.)
        self.assertEqual(g["nativeProposalRadius"], .125)
        self.assertEqual(g["nativeWalkableRadiusCells"], 5)
        with self.assertRaises(ValueError): geometry("body45cmMargin0", .125)

class ExplicitEndpointsAndFallback(unittest.TestCase):
    def test_28cm_edges_and_corners_are_present(self):
        rr = rectangle_module("abstract28cmProfile")
        self.assertAlmostEqual(rr.RB[:,1].min(),-.14)
        self.assertAlmostEqual(rr.RB[:,1].max(),.14)
        for x in [-.15,.15]:
            for y in [-.14,.14]:
                self.assertTrue(np.any(np.all(np.isclose(rr.RB,[x,y],atol=1e-12,rtol=0),axis=1)))
    def test_fallback_changes_only_proposal_not_rectangle(self):
        normal=geometry("abstract28cmProfile");fallback=geometry("abstract28cmProfile",.125)
        self.assertEqual(normal["nativeWalkableRadiusCells"],6)
        self.assertEqual(fallback["nativeWalkableRadiusCells"],5)
        np.testing.assert_array_equal(rectangle_module("abstract28cmProfile").RB,rectangle_module("abstract28cmProfile",.125).RB)
        self.assertEqual(fallback["width"],.28);self.assertEqual(fallback["depth"],.30)
        with self.assertRaises(ValueError):geometry("body45cmMargin0",.125)

if __name__ == "__main__": unittest.main()

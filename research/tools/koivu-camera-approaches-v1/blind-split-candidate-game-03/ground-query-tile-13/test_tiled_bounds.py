"""Authored ID-set equivalence only; no recorded reference/map/episode."""
import math
import unittest
import numpy as np
import vtk
from tiled_bounds import find_cells_tiled, tile_edges, TiledBoundsUnavailable


class AuthoredSurface:
    def __init__(self, triangles):
        points = vtk.vtkPoints(); points.SetDataTypeToDouble()
        faces = vtk.vtkCellArray()
        for triangle in np.asarray(triangles, dtype=float):
            faces.InsertNextCell(3)
            for point in triangle: faces.InsertCellPoint(points.InsertNextPoint(point))
        self.mesh = vtk.vtkPolyData(); self.mesh.SetPoints(points); self.mesh.SetPolys(faces)
        self.mesh.BuildCells(); self.errors = []
        self.locator = vtk.vtkStaticCellLocator(); self.locator.SetDataSet(self.mesh)
        self.locator.AutomaticOff(); self.locator.SetDivisions(12, 12, 12)
        self.locator.AddObserver('ErrorEvent', lambda *a: self.errors.append('native error'))
        self.locator.BuildLocator(); self.revision = self.mesh.GetMTime()
    def check(self):
        if self.errors or self.mesh.GetMTime() != self.revision or self.locator.GetDataSet() != self.mesh:
            raise TiledBoundsUnavailable('authored surface owner/error changed')
    def single(self, bounds):
        self.check(); found = vtk.vtkIdList(); self.locator.FindCellsWithinBounds(bounds, found); self.check()
        return np.unique(np.fromiter((found.GetId(i) for i in range(found.GetNumberOfIds())), np.int64))


def random_surface(seed=271828):
    rng = np.random.default_rng(seed)
    centres = rng.uniform(-1., 1., (64, 1, 3))
    return AuthoredSurface(centres+rng.uniform(-.08, .08, (64, 3, 3)))


class TileEquivalenceTests(unittest.TestCase):
    def compare(self, surface, bounds, **kwargs):
        expected = surface.single(bounds)
        actual, receipt = find_cells_tiled(surface.locator, bounds, check=surface.check,
                                          unique_cap=10000, **kwargs)
        np.testing.assert_array_equal(actual, expected)
        self.assertEqual(actual.dtype, np.int64)
        self.assertFalse(actual.flags.writeable)
        self.assertEqual(receipt['uniqueOriginalIDs'], len(actual))
        self.assertGreaterEqual(receipt['rawReturnedIDs'], len(actual))
        self.assertFalse(receipt['originalGeometryChanged'])
        return actual, receipt
    def test_random_authored_mesh_queries(self):
        surface = random_surface(); rng = np.random.default_rng(314159)
        for _ in range(12):
            lo = rng.uniform(-1.1, .4, 3); hi = lo+rng.uniform(.01, .9, 3)
            with self.subTest(bounds=(lo.tolist(), hi.tolist())):
                self.compare(surface, np.column_stack((lo, hi)).ravel())
    def test_whole_dataset_and_duplicates_across_tiles(self):
        surface = random_surface(); ids, receipt = self.compare(surface, [-1.2, 1.2]*3)
        self.assertEqual(len(ids), 64)
        self.assertGreater(receipt['rawReturnedIDs'], len(ids))
    def test_exact_tile_boundary_triangles(self):
        triangles = []
        for x in [-.5, -.25, 0., .25, .5]:
            triangles.append([[x, -.5, -.5], [x, .5, -.5], [x, 0., .5]])
        surface = AuthoredSurface(triangles)
        self.compare(surface, [-.5, .5, -.5, .5, -.5, .5])
        self.compare(surface, [-.25, .25, -.25, .25, -.25, .25])
    def test_partial_outside_bounds(self):
        self.compare(random_surface(), [-1.8, -.6, -.5, .3, .4, 1.4])
    def test_fully_outside_preserves_native_clamped_bin_semantics(self):
        self.compare(random_surface(), [1.3, 1.9, -.3, .3, -.3, .3])
    def test_empty_query_result(self):
        surface = AuthoredSurface([[[-1., -1., -1.], [-.9, -1., -1.], [-1., -.9, -.9]],
                                   [[1., 1., 1.], [.9, 1., 1.], [1., .9, .9]]])
        ids, _ = self.compare(surface, [-.1, .1]*3)
        self.assertEqual(len(ids), 0)
    def test_zero_and_tiny_intervals(self):
        surface = random_surface()
        self.compare(surface, [0., 0., -.5, .5, -.5, .5])
        self.compare(surface, [0., np.nextafter(0., 1.), 0., 0., 0., 0.])
    def test_positive_similarity_transformed_mesh(self):
        rng = np.random.default_rng(1234); triangles = rng.uniform(-.5, .5, (30, 3, 3))
        theta = .37; rotation = np.array([[math.cos(theta), 0, math.sin(theta)], [0, 1, 0], [-math.sin(theta), 0, math.cos(theta)]])
        surface = AuthoredSurface(1.02079084*triangles@rotation.T+[1.25, -.8, .5])
        self.compare(surface, [.8, 1.7, -1.2, -.3, .1, .8])
    def test_closed_partition_has_exact_outer_and_shared_endpoints(self):
        bounds = [-.7, .7, .25, .25, -1., -.1]
        edges = tile_edges(bounds)
        for axis, edge in enumerate(edges):
            self.assertEqual(edge[0], bounds[2*axis]); self.assertEqual(edge[-1], bounds[2*axis+1])
            self.assertTrue(np.all(np.diff(edge) >= 0.)); self.assertTrue(np.all(np.diff(edge) <= .25+1e-14))
            self.assertFalse(edge.flags.writeable)
    def test_invalid_bounds_rejected(self):
        for bounds in [[0., 1.], [1., 0., 0., 1., 0., 1.], [0., np.nan, 0., 1., 0., 1.]]:
            with self.subTest(bounds=bounds):
                with self.assertRaises(ValueError): tile_edges(bounds)
    def test_invalid_size_and_resource_configuration_rejected(self):
        for size in [0., -.1, .251, np.inf, True]:
            with self.subTest(size=size):
                with self.assertRaises(ValueError): tile_edges([0., 1.]*3, tile_size=size)
        for cap in [0, 10001, True, 2.5]:
            with self.subTest(cap=cap):
                with self.assertRaises(ValueError): tile_edges([0., 1.]*3, max_tiles=cap)
    def test_tile_count_cap_is_unavailable_not_empty(self):
        with self.assertRaises(TiledBoundsUnavailable): tile_edges([0., 10.]*3)
    def test_raw_id_cap_is_unavailable_not_empty(self):
        surface = random_surface()
        with self.assertRaises(TiledBoundsUnavailable) as caught:
            find_cells_tiled(surface.locator, [-1.2, 1.2]*3, check=surface.check, unique_cap=100, max_raw_ids=0)
        self.assertIn('raw-ID', str(caught.exception))
    def test_unique_id_cap_is_unavailable_not_truncated(self):
        surface = random_surface()
        with self.assertRaises(TiledBoundsUnavailable) as caught:
            find_cells_tiled(surface.locator, [-1.2, 1.2]*3, check=surface.check, unique_cap=1)
        self.assertEqual(caught.exception.details['uniqueIDs'], 64)
    def test_mesh_mutation_during_query_is_rejected(self):
        surface = random_surface(); calls = [0]
        def check():
            calls[0] += 1
            if calls[0] == 4: surface.mesh.Modified()
            surface.check()
        with self.assertRaises(TiledBoundsUnavailable):
            find_cells_tiled(surface.locator, [-.5, .5]*3, check=check, unique_cap=100)
    def test_locator_owner_mutation_is_rejected_without_strong_external_check(self):
        surface = random_surface(); calls = [0]
        def check():
            calls[0] += 1
            if calls[0] == 4: surface.locator.Modified()
        with self.assertRaises(TiledBoundsUnavailable):
            find_cells_tiled(surface.locator, [-.5, .5]*3, check=check, unique_cap=100)
    def test_checker_reports_native_error_before_result(self):
        surface = random_surface(); calls = [0]
        def check():
            calls[0] += 1
            if calls[0] == 4: surface.errors.append('injected authored error')
            surface.check()
        with self.assertRaises(TiledBoundsUnavailable):
            find_cells_tiled(surface.locator, [-.5, .5]*3, check=check, unique_cap=100)


if __name__ == '__main__': unittest.main(verbosity=2)

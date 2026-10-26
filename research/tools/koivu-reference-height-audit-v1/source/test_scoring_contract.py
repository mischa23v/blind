"""Small source/native fixtures; no recorded mesh, map or data evaluation."""
from pathlib import Path
import ast, hashlib, json, sys, unittest
import numpy as np
import vtk

ROOT = Path(__file__).resolve().parents[1]
WS = ROOT.parent
sys.path.insert(0, str(WS / 'blind-koivu-game-07'))
from reference_container import ReferenceContainer, Container
sys.path.insert(0, str(WS / 'blind-koivu-reference-comparison-06'))
from reference_geometry import ReferenceSurface, serial_vtk

def original_score():
    # Compile only the exact pinned pure score function, not the untrusted
    # pipeline's imports/main, input reader, renderer, route or fusion code.
    path = ROOT / 'upstream/scripts/pipeline.py'
    expected = '32a2fc27bb23421d2192005a9aa99ff15e3936ad4c20161592c1d85fab337dfc'
    source = path.read_bytes()
    if hashlib.sha256(source).hexdigest() != expected:
        raise ValueError('pinned source changed')
    tree = ast.parse(source)
    nodes = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'score']
    if len(nodes) != 1:
        raise ValueError('ambiguous original score')
    scope = {'np': np}
    exec(compile(ast.Module(body=nodes, type_ignores=[]), str(path), 'exec'), scope)
    return scope['score']

class Contract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        serial_vtk()
        cls.score = staticmethod(original_score())

    def reference(self, height):
        # Exact reference bands in the pinned pipeline, one vertex in a column.
        low = height if .015 <= height < .30 else -np.inf
        body = height if .30 <= height < 1.80 else -np.inf
        return {'n': np.array([[1]]), 'low_max': np.array([[low]]),
                'body_max': np.array([[body]])}

    def test_12mm_geometry_is_outside_reference_low_band(self):
        r = self.score(np.array([[True]]), self.reference(.012))
        self.assertEqual((r['n'], r['noRefCov'], r['refLow25'], r['refBody']), (1, 0, 0, 0))

    def test_20mm_geometry_is_inside_band_but_not_headline_hit(self):
        r = self.score(np.array([[True]]), self.reference(.020))
        self.assertEqual((r['n'], r['refLow25'], r['refBody']), (1, 0, 0))

    def test_25mm_headline_boundary_is_inclusive(self):
        self.assertEqual(self.score(np.array([[True]]), self.reference(.025))['refLow25'], 1)

    def test_body_geometry_separate_from_low_headline(self):
        r = self.score(np.array([[True]]), self.reference(.5))
        self.assertEqual((r['refLow25'], r['refBody']), (0, 1))

    def test_ceiling_vertex_still_claims_column_coverage(self):
        r = self.score(np.array([[True]]), self.reference(2.6))
        self.assertEqual((r['n'], r['noRefCov'], r['refLow25'], r['refBody']), (1, 0, 0, 0))

    def test_triangle_can_cross_column_without_any_vertex_inside(self):
        # Real upstream tested game scorer, unchanged. This triangle crosses the
        # entire column at 1 cm height; all its vertices are outside that column.
        vertices = np.array([[-1., .01, -1.], [1., .01, -1.], [0., .01, 1.]])
        points = vtk.vtkPoints(); points.SetDataTypeToDouble()
        for p in vertices: points.InsertNextPoint(*p)
        cells = vtk.vtkCellArray(); cells.InsertNextCell(3)
        for i in range(3): cells.InsertCellPoint(i)
        mesh = vtk.vtkPolyData(); mesh.SetPoints(points); mesh.SetPolys(cells)
        model = ReferenceContainer(ReferenceSurface(mesh), np.eye(4),
                                   Container(half_extent=.025, height=.5))
        self.assertFalse(np.any(np.all(np.abs(vertices[:, [0, 2]]) < .025, axis=1)))
        self.assertTrue(model.swept_contact([0., 0., 0.], [0., 0., 0.])['contact'])

if __name__ == '__main__':
    unittest.main(verbosity=2)

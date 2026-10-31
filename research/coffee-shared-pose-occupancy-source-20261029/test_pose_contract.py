"""Prepared pure-stdlib controls; no data raster, NumPy, ctypes or mapper load."""
import ast
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('pure_pose_contract', ROOT/'pose_contract.py')
subject = importlib.util.module_from_spec(spec)
spec.loader.exec_module(subject)
I = [[1.,0.,0.,0.],[0.,1.,0.,0.],[0.,0.,1.,0.],[0.,0.,0.,1.]]
RZ_TRANSLATED = [[0.,-1.,0.,10.],[1.,0.,0.,20.],[0.,0.,1.,30.],[0.,0.,0.,1.]]


class PoseContractControls(unittest.TestCase):
    def test_cv_forward_maps_to_gl_negative_z(self):
        self.assertEqual(subject.transform_point(subject.camera_cv_to_saved_world(I), [2.,3.,4.]),
                         (2.,-3.,-4.))

    def test_right_multiply_with_asymmetric_rotation(self):
        t = subject.camera_cv_to_saved_world(RZ_TRANSLATED)
        self.assertEqual(subject.transform_point(t, [2.,3.,4.]), (13.,22.,26.))

    def test_origin_translation_not_flipped_or_permuted(self):
        t = subject.camera_cv_to_saved_world(RZ_TRANSLATED)
        self.assertEqual(subject.transform_point(t, [0.,0.,0.]), (10.,20.,30.))
        self.assertEqual(tuple(t[i][3] for i in range(3)), (10.,20.,30.))

    def test_inverse_is_for_return_to_camera_not_forward_mapping(self):
        t = subject.camera_cv_to_saved_world(RZ_TRANSLATED)
        inv = subject.inverse_rigid(t)
        original = [2.,3.,4.]
        mapped = subject.transform_point(t, original)
        self.assertEqual(subject.transform_point(inv, list(mapped)), tuple(original))
        self.assertNotEqual(subject.transform_point(inv, original), mapped)

    def test_metric_translation_is_not_scaled_or_centered(self):
        p = copy.deepcopy(I); p[0][3] = .125; p[1][3] = -2.5; p[2][3] = 7.75
        t = subject.camera_cv_to_saved_world(p)
        self.assertEqual(subject.transform_point(t, [0.,0.,0.]), (.125,-2.5,7.75))
        self.assertEqual(subject.transform_point(t, [0.,0.,2.]), (.125,-2.5,5.75))

    def test_actual_column_arithmetic_matches_scalar_transform(self):
        t = subject.camera_cv_to_saved_world(RZ_TRANSLATED)
        self.assertEqual(subject.transform_coordinates(2.,3.,4.,t), (13.,22.,26.))

    def test_no_extra_raw_world_axis_permutation(self):
        mapped = subject.transform_point(subject.camera_cv_to_saved_world(RZ_TRANSLATED), [2.,3.,4.])
        self.assertEqual(mapped, (13.,22.,26.))
        self.assertNotEqual(mapped, (26.,13.,22.))

    def test_absent_ragged_nonnumeric_nonfinite_pose_refused(self):
        bad = [None, [], I[:3], [row[:3] for row in I]]
        for value in [float('nan'), float('inf'), True, '1']:
            p = copy.deepcopy(I); p[0][0] = value; bad.append(p)
        for pose in bad:
            with self.subTest(pose=repr(pose)):
                with self.assertRaises(ValueError): subject.validate_pose(pose)

    def test_reflection_shear_scale_and_nonhomogeneous_pose_refused(self):
        for location,value in [((0,0),-1.),((0,0),1.01),((0,1),.1),((3,3),2.),((3,0),.1)]:
            p = copy.deepcopy(I); p[location[0]][location[1]] = value
            with self.subTest(location=location,value=value):
                with self.assertRaises(ValueError): subject.validate_pose(p)

    def test_frame_requires_own_pose_intrinsics_and_original_shape(self):
        f = {'w':738,'h':994,'fl_x':800.,'fl_y':801.,'cx':368.,'cy':504.,
             'transform_matrix':RZ_TRANSLATED}
        t,origin = subject.frame_contract(f)
        self.assertEqual(origin, (10.,20.,30.))
        self.assertEqual(t, subject.camera_cv_to_saved_world(RZ_TRANSLATED))
        for key in ('transform_matrix','fl_x','fl_y','cx','cy','w','h'):
            candidate = dict(f); candidate.pop(key)
            with self.subTest(missing=key):
                with self.assertRaises(ValueError): subject.frame_contract(candidate)
        for key,value in [('w',994),('h',738),('fl_x',0.),('fl_y',-1.)]:
            with self.subTest(key=key,value=value):
                with self.assertRaises(ValueError): subject.frame_contract(dict(f,**{key:value}))


class SourceBindingControls(unittest.TestCase):
    def test_frozen_batch_hash_and_not_heldout(self):
        p = ROOT/'FRAME_SELECTION.json'
        self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),
                         'e5191320be4c61ba35820694d8b3638d799b27693f66b9890563c941bb4ec979')
        frozen = json.loads(p.read_text())
        self.assertTrue(frozen['frozenBeforeControls'])
        self.assertFalse(frozen['isHeldOut'])
        self.assertEqual(frozen['frameIDs'], ['frame_00290','frame_00357','frame_00391'])

    def test_driver_uses_exact_column_transform_and_sensor_origin(self):
        tree = ast.parse((ROOT/'shared_pose.py').read_text())
        calls = [n for n in ast.walk(tree) if isinstance(n,ast.Call)]
        insert = [n for n in calls if isinstance(n.func,ast.Attribute) and n.func.attr == 'insert']
        self.assertEqual(len(insert),1)
        self.assertEqual([ast.unparse(x) for x in insert[0].args], ['scan_id','world','origin'])
        transform = [n for n in calls if isinstance(n.func,ast.Attribute) and n.func.attr == 'transform_coordinates']
        self.assertEqual(len(transform),1)
        self.assertEqual([ast.unparse(x) for x in transform[0].args],
                         ['points[:, 0]','points[:, 1]','points[:, 2]','transform'])
        self.assertFalse(any(isinstance(n.func,ast.Attribute) and n.func.attr in
                             ('inverse_rigid','diagnostic') for n in calls))

    def test_pose_validation_precedes_native_wrapper_load(self):
        source = (ROOT/'shared_pose.py').read_text()
        self.assertLess(source.index('contracts[name] = pose.frame_contract(frame)'),
                        source.index("engine = load_source(wrapper_path"))
        self.assertLess(source.index("args.run_shared_map"), source.index('engine.OctoMap('))
        self.assertIn("COFFEE_SHARED_OUTER_GUARD",source)

    def test_pose_module_only_imports_standard_library_math(self):
        tree = ast.parse((ROOT/'pose_contract.py').read_text())
        imports = [alias.name for node in ast.walk(tree) if isinstance(node,ast.Import)
                   for alias in node.names]
        self.assertEqual(imports,['math'])
        self.assertFalse(any(isinstance(node,ast.ImportFrom) for node in ast.walk(tree)))


if __name__ == '__main__':
    unittest.main(verbosity=2)

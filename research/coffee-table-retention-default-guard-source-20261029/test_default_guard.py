"""Pure-stdlib controls for the actual retained guard AST; no mapper import/load."""
import ast
import math
from pathlib import Path
import struct
import unittest


class NativeDefaultGuardControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = ast.parse(Path(__file__).with_name('retention.py').read_text())
        native = next(node for node in source.body
                      if isinstance(node, ast.FunctionDef) and node.name == 'native_retention')
        matches = [node for node in ast.walk(native)
                   if isinstance(node, ast.Call) and isinstance(node.func, ast.Name)
                   and node.func.id == 'require' and len(node.args) == 2
                   and isinstance(node.args[1], ast.Constant)
                   and node.args[1].value == 'upstream defaults changed']
        if len(matches) != 1:
            raise AssertionError('exactly one upstream-default guard is required')
        cls.condition = matches[0].args[0]
        cls.expression = compile(ast.Expression(body=cls.condition), '<actual-default-guard>', 'eval')

    def accepts(self, **changes):
        values = {'hit': .7, 'miss': .4, 'occupancy': .5}
        values.update(changes)
        return eval(self.expression, {'__builtins__': {}, 'abs': abs}, {'defaults': values})

    def test_exact_absolute_tolerance_policy(self):
        self.assertIsInstance(self.condition, ast.BoolOp)
        self.assertIsInstance(self.condition.op, ast.And)
        comparisons = self.condition.values
        self.assertEqual(len(comparisons), 3)
        for node in comparisons:
            self.assertIsInstance(node, ast.Compare)
            self.assertEqual(len(node.ops), 1)
            self.assertIsInstance(node.ops[0], ast.LtE)
            self.assertEqual(ast.literal_eval(node.comparators[0]), 1e-7)

    def test_nominal_defaults_accepted(self):
        self.assertTrue(self.accepts())

    def test_upstream_float32_logodds_roundtrip_accepted(self):
        predicted = {}
        for name, probability in [('hit', .7), ('miss', .4), ('occupancy', .5)]:
            logodds = math.log(probability / (1. - probability))
            stored = struct.unpack('f', struct.pack('f', logodds))[0]
            predicted[name] = 1. - 1. / (1. + math.exp(stored))
        self.assertGreater(abs(predicted['hit'] - .7), 1e-12)
        self.assertGreater(abs(predicted['miss'] - .4), 1e-12)
        self.assertTrue(self.accepts(**predicted))

    def test_inside_absolute_tolerance_accepted(self):
        for name, target in [('hit', .7), ('miss', .4), ('occupancy', .5)]:
            for direction in [-1., 1.]:
                with self.subTest(name=name, direction=direction):
                    self.assertTrue(self.accepts(**{name: target + direction * 5e-8}))

    def test_outside_absolute_tolerance_rejected(self):
        for name, target in [('hit', .7), ('miss', .4), ('occupancy', .5)]:
            for direction in [-1., 1.]:
                with self.subTest(name=name, direction=direction):
                    self.assertFalse(self.accepts(**{name: target + direction * 1.01e-7}))

    def test_material_default_changes_rejected(self):
        for name, target in [('hit', .7), ('miss', .4), ('occupancy', .5)]:
            for direction in [-1., 1.]:
                with self.subTest(name=name, direction=direction):
                    self.assertFalse(self.accepts(**{name: target + direction * .01}))

    def test_nonfinite_defaults_rejected(self):
        for name in ['hit', 'miss', 'occupancy']:
            for value in [float('nan'), float('inf'), float('-inf')]:
                with self.subTest(name=name, value=value):
                    self.assertFalse(self.accepts(**{name: value}))


if __name__ == '__main__':
    unittest.main(verbosity=2)

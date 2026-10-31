#!/usr/bin/env python3
"""Small stdlib-only source control; never import/run the native comparator.

Execute the actual CLI/verify prefix and actual endpoint-binding statements in
one lexical scope. Omit all scene parsing, scientific imports and native calls.
"""
import argparse, ast, copy, hashlib, json, pathlib, sys, tempfile, unittest

SOURCE = pathlib.Path(__file__).with_name('run_comparison.py')


def probe(source, directory):
    tree = ast.parse(source)
    main = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'main')
    prefix = []
    for node in main.body:
        if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call) and isinstance(node.value.func, ast.Name) and node.value.func.id == 'verify':
            break
        prefix.append(copy.deepcopy(node))
    else:
        raise AssertionError('actual initial verify call not found')
    route_loops = []
    for node in ast.walk(main):
        if not isinstance(node, ast.For) or not node.body:
            continue
        first = node.body[0]
        if isinstance(first, ast.Assign) and isinstance(first.targets[0], ast.Tuple) and [n.id for n in first.targets[0].elts] == ['a', 'b']:
            loop = copy.deepcopy(node)
            loop.body = [copy.deepcopy(first), ast.parse('verify()').body[0]]
            loop.orelse = []
            route_loops.append(loop)
    if len(route_loops) != 2:
        raise AssertionError('expected both actual baseline/grid endpoint-binding loops')
    prefix += ast.parse("verify(); requests = [{'requestedStartXYZ': [0, 0, 0], 'requestedGoalXYZ': [1, 0, 0]}, {'requestedStartXYZ': [1, 0, 0], 'requestedGoalXYZ': [2, 0, 0]}]; model = {'paths': requests}").body
    prefix += route_loops + ast.parse('verify(); return verify').body
    main.body = prefix
    sha = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'sha')
    extracted = ast.fix_missing_locations(ast.Module(body=[sha, main], type_ignores=[]))
    namespace = {'argparse': argparse, 'hashlib': hashlib, 'json': json, 'pathlib': pathlib, 'R': directory, 'W': directory}
    exec(compile(extracted, str(SOURCE), 'exec'), namespace)
    manifest = directory / 'pins.json'
    old_argv = sys.argv
    sys.argv = [str(SOURCE), '--pins', str(manifest), '--pins-sha256', hashlib.sha256(manifest.read_bytes()).hexdigest()]
    try:
        return namespace['main']()
    finally:
        sys.argv = old_argv


class CliPinsControl(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='conference-cli-pins-')
        self.addCleanup(self.temporary.cleanup)
        self.directory = pathlib.Path(self.temporary.name)
        self.input = self.directory / 'fixture.bin'
        self.input.write_bytes(b'bounded synthetic pin fixture\n')
        self.manifest = self.directory / 'pins.json'
        self.manifest.write_text(json.dumps({'status': 'SOURCE_FROZEN_AWAITING_ROOT_ADMISSION', 'inputs': {'fixture.bin': hashlib.sha256(self.input.read_bytes()).hexdigest()}}))
        self.source = SOURCE.read_text()

    def test_cli_namespace_retained_after_both_route_loops(self):
        verify = probe(self.source, self.directory)
        captured = dict(zip(verify.__code__.co_freevars, (c.cell_contents for c in verify.__closure__)))
        self.assertEqual(captured['cli_args'].pins, self.manifest)
        self.assertEqual(captured['cli_args'].pins_sha256, hashlib.sha256(self.manifest.read_bytes()).hexdigest())
        verify()

    def test_original_shadowing_bug_is_detected(self):
        # Reverse only the namespace rename, retaining the actual route bindings.
        with self.assertRaisesRegex(AttributeError, "'list' object has no attribute 'pins'"):
            probe(self.source.replace('cli_args', 'a'), self.directory)

    def test_manifest_change_still_rejected_after_route_iteration(self):
        verify = probe(self.source, self.directory)
        self.manifest.write_text(self.manifest.read_text() + '\n')
        with self.assertRaisesRegex(ValueError, '^manifest changed$'):
            verify()

    def test_input_change_still_rejected_after_route_iteration(self):
        verify = probe(self.source, self.directory)
        self.input.write_bytes(b'changed fixture\n')
        with self.assertRaisesRegex(ValueError, '^source/input pin mismatch: fixture.bin$'):
            verify()


if __name__ == '__main__':
    unittest.main(verbosity=2)

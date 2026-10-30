#!/usr/bin/env python3
"""Root-admitted authored controls only; no actual room or native planner load."""
import argparse, hashlib, json, pathlib, types, unittest
H = pathlib.Path(__file__).resolve().parent


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--pins', type=pathlib.Path, required=True); parser.add_argument('--pins-sha256', required=True)
    cli_args = parser.parse_args()
    data = cli_args.pins.read_bytes()
    if hashlib.sha256(data).hexdigest() != cli_args.pins_sha256: raise ValueError('manifest SHA mismatch')
    pins = json.loads(data); source = (H / 'runtime.py').read_bytes()
    if hashlib.sha256(source).hexdigest() != pins['inputs']['research/conference-geos-simplification-proposal-20261030/runtime.py']:
        raise ValueError('runtime source mismatch')
    runtime = types.ModuleType('_paired_runtime_controls'); runtime.__file__ = str(H / 'runtime.py')
    exec(compile(source, runtime.__file__, 'exec', dont_inherit=True), runtime.__dict__)
    runtime.check_sanitized_environment()
    manifest = runtime.Manifest(cli_args.pins, cli_args.pins_sha256)
    manifest.module('candidate', H / 'candidate.py', register=True)
    test = manifest.module('test_candidate', H / 'test_candidate.py', register=True)
    try:
        suite = unittest.defaultTestLoader.loadTestsFromModule(test)
        if suite.countTestCases() != 17: raise ValueError('fixed authored control count changed')
        result = unittest.TextTestRunner(verbosity=2).run(suite)
        summary = {'status': 'passed' if result.wasSuccessful() and not result.skipped else 'failed',
                   'count': result.testsRun, 'failures': len(result.failures), 'errors': len(result.errors), 'skipped': len(result.skipped),
                   'scope': 'authored GEOS/2D and explicit corridor stubs only; not native-room validation', 'physicalAuthority': False}
        print(json.dumps(summary), flush=True)
        if summary['status'] != 'passed': raise SystemExit(2)
    finally:
        manifest.verify()


if __name__ == '__main__': main()

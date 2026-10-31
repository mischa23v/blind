"""Stdlib-only pinned-byte loading and runtime admission helpers, not a runner."""
import contextlib
import hashlib
import importlib.abc
import importlib.util
import json
import os
import pathlib
import stat
import sys
import types

H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]
W = R.parent


def sha(path):
    with pathlib.Path(path).open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


class Manifest:
    def __init__(self, path, expected):
        self.path = pathlib.Path(path).resolve()
        data = self.path.read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('admitted manifest SHA mismatch')
        self.digest = expected
        self.pins = json.loads(data)
        if self.pins['status'] != 'SOURCE_FROZEN_AWAITING_ROOT_ADMISSION':
            raise ValueError('unexpected manifest status')
        self.by_path = {str(self.expand(name).resolve()): digest for name, digest in self.pins['inputs'].items()}
        self.verify()

    def expand(self, name):
        expanded = name.replace('@WORKSPACE@', str(W)).replace('@REPO@', str(R)).replace('@PROTOCOL@', str(H))
        path = pathlib.Path(expanded)
        return path if path.is_absolute() else R / path

    def verify(self):
        if sha(self.path) != self.digest:
            raise ValueError('manifest changed')
        for name, digest in self.pins['inputs'].items():
            path = self.expand(name)
            if not stat.S_ISREG(path.stat().st_mode) or sha(path) != digest:
                raise ValueError('source/input pin mismatch: ' + name)

    def source(self, path):
        path = pathlib.Path(path).resolve()
        expected = self.by_path.get(str(path))
        if expected is None:
            raise ValueError('unadmitted module path: ' + str(path))
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != expected:
            raise ValueError('module source mismatch: ' + str(path))
        return data

    def module(self, name, path, *, register=False):
        path = pathlib.Path(path).resolve(); data = self.source(path)
        module = types.ModuleType(name); module.__file__ = str(path)
        if register:
            if name in sys.modules:
                raise ValueError('module already loaded: ' + name)
            sys.modules[name] = module
        try:
            exec(compile(data, str(path), 'exec', dont_inherit=True), module.__dict__)
        except BaseException:
            if register:
                sys.modules.pop(name, None)
            raise
        return module


def check_sanitized_environment():
    if sys.platform != 'linux':
        raise ValueError('Linux procfs/aggregate required')
    if any(name.startswith(('LD_', 'DYLD_')) or name in ('PYTHONPATH', 'PYTHONHOME') for name in os.environ):
        raise ValueError('unsanitized dynamic/Python loader environment')
    if os.environ.get('PYTHONDONTWRITEBYTECODE') != '1' or not os.environ.get('PYTHONPYCACHEPREFIX'):
        raise ValueError('fresh aggregate bytecode environment required')
    for name in ('OMP_NUM_THREADS', 'OPENBLAS_NUM_THREADS', 'MKL_NUM_THREADS'):
        if os.environ.get(name) != '1':
            raise ValueError('single-thread runtime required')
    sys.dont_write_bytecode = True


@contextlib.contextmanager
def exact_native_imports(manifest):
    """Unchanged wrapper modules execute exact pinned bytes, never cached pyc."""
    base = W / 'coffee-native-replay-prepared-002'
    paths = {
        'native_exclusion': base / 'blind-tabletop-exclusion-planner-66/native_exclusion.py',
        'planner': base / 'blind-clearance-centered-loop-55/planner.py',
    }
    binding = base / 'blind-split-candidate-game-03/body-margin-variants-07/native025/detour_engine.py'
    cached = {str(p.resolve()): manifest.source(p) for p in (*paths.values(), binding)}
    if any(name in sys.modules for name in (*paths, 'clearance55native', 'exclusion66_binding')):
        raise ValueError('native source module already loaded')
    original_spec = importlib.util.spec_from_file_location

    class Loader(importlib.abc.Loader):
        def __init__(self, path): self.path = pathlib.Path(path).resolve()
        def create_module(self, spec): return None
        def exec_module(self, module):
            module.__file__ = str(self.path)
            exec(compile(cached[str(self.path)], str(self.path), 'exec', dont_inherit=True), module.__dict__)

    def exact_spec(name, path, *args, **kwargs):
        resolved = str(pathlib.Path(path).resolve())
        if resolved in cached:
            return importlib.util.spec_from_loader(name, Loader(path), origin=resolved)
        return original_spec(name, path, *args, **kwargs)

    class Finder(importlib.abc.MetaPathFinder):
        def find_spec(self, fullname, path=None, target=None):
            if fullname in paths:
                return exact_spec(fullname, paths[fullname])
            return None

    finder = Finder(); sys.meta_path.insert(0, finder)
    importlib.util.spec_from_file_location = exact_spec
    try:
        yield paths
    finally:
        importlib.util.spec_from_file_location = original_spec
        sys.meta_path.remove(finder)


def assert_native_binding(native, Native, planner_path, binary_path):
    import planner
    if type(native) is not Native or native.segment.__func__ is not planner.Native.segment:
        raise ValueError('native callback owner changed')
    if pathlib.Path(native.segment.__func__.__code__.co_filename).resolve() != pathlib.Path(planner_path).resolve():
        raise ValueError('native callback source changed')
    if pathlib.Path(native.lib._name).resolve() != pathlib.Path(binary_path).resolve():
        raise ValueError('native binary owner changed')
    return {'implementation': 'unchanged planner.Native.segment / bn_segment',
            'sourcePath': str(pathlib.Path(planner_path).relative_to(W)),
            'binaryPath': str(pathlib.Path(binary_path).relative_to(W)),
            'callbackBoundToKnownImplementation': True, 'routeSearchCalled': False}

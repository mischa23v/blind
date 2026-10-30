"""Source-only read-only query binding. Explicit new build hash required.

Loads a private verified copy of the original Python binding. Only that copy's
library path/hash is assigned to the separately reviewed candidate binary; the
original file and its binary pin remain unchanged. This is not execution authority.
"""
import ctypes as C
import hashlib
import importlib.util
import math
from pathlib import Path
import re
import numpy as np

ROOT=Path(__file__).resolve().parent
BASE=ROOT.parent/'coffee-table-retention-default-guard-source-20261029/octomap_engine.py'
BASE_SHA='09645bd4065ccef13d28353d5a05e54c75f5ea284ca8e5c4439c58cc45aa4621'
STATUS=('unresolved','hit-known-prefix','origin-unknown','origin-occupied',
        'unknown-before-hit','range-exhausted','invalid-input','bounds-rejected',
        'intersection-failed','observed-hit-visibility-unverified')


class RayResult(C.Structure):
    _fields_=[(n,C.c_uint32) for n in ('status','terminalKnown','terminalOccupied','hitScans','freeScans')]+[
        (n,C.c_double) for n in ('maxRange','centerProjectedRange','entryProjectedRange','probability','logOdds')]+[
        ('center',C.c_double*3),('entry',C.c_double*3)]


def reviewed_base(library, expected_sha256):
    library=Path(library).resolve()
    if not re.fullmatch(r'[0-9a-f]{64}',expected_sha256):
        raise ValueError('explicit reviewed candidate SHA256 required')
    if not library.is_file() or library.stat().st_size>2*1024**2:
        raise ValueError('missing/oversize candidate library')
    if hashlib.sha256(library.read_bytes()).hexdigest()!=expected_sha256:
        raise ValueError('candidate library hash mismatch')
    if hashlib.sha256(BASE.read_bytes()).hexdigest()!=BASE_SHA:
        raise ValueError('original binding source changed')
    spec=importlib.util.spec_from_file_location('private_reviewed_octomap_binding',BASE)
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    module.LIBRARY=library; module.LIBRARY_SHA256=expected_sha256
    return module


def open_reviewed_tree(library, expected_sha256, resolution=.05):
    base=reviewed_base(library,expected_sha256)
    tree=base.OctoMap(resolution=resolution)
    try:
        return tree,ReadOnlyRays(tree)
    except BaseException:
        tree.close()
        raise


class ReadOnlyRays:
    def __init__(self,tree):
        self.tree=tree; lib=tree.lib
        lib.om_ro_result_size.argtypes=[];lib.om_ro_result_size.restype=C.c_uint64
        if lib.om_ro_result_size()!=C.sizeof(RayResult):
            raise RuntimeError('ray result ABI size mismatch')
        lib.om_ro_state.argtypes=[C.c_void_p,C.POINTER(C.c_uint64)];lib.om_ro_state.restype=C.c_int
        lib.om_ro_rays.argtypes=[C.c_void_p,C.POINTER(C.c_float),C.POINTER(C.c_float),
                                C.POINTER(C.c_double),C.c_uint64,C.POINTER(RayResult)]
        lib.om_ro_rays.restype=C.c_int
        lib.om_ro_observed_rays.argtypes=list(lib.om_ro_rays.argtypes)
        lib.om_ro_observed_rays.restype=C.c_int

    def state(self):
        with self.tree._lock:
            if not self.tree.handle:raise RuntimeError('closed handle')
            out=(C.c_uint64*6)();self.tree.check(self.tree.lib.om_ro_state(self.tree.handle,out))
            return dict(zip(('scans','treeNodes','leaves','evidenceKeys','hitVotes','freeVotes'),map(int,out)))

    def cast(self,origin,directions,max_ranges):
        return self._cast(origin,directions,max_ranges,False)

    def cast_observed(self,origin,directions,max_ranges):
        """Offline observed surfaces only; unknown visibility is never clearance."""
        return self._cast(origin,directions,max_ranges,True)

    def _cast(self,origin,directions,max_ranges,observed_only):
        # Count guards precede ndarray conversion, including adversarial __array__.
        count=len(directions)
        if count>256 or len(max_ranges)!=count:raise ValueError('ray batch count/shape')
        if len(origin)!=3:raise ValueError('origin shape')
        o=np.ascontiguousarray(origin,dtype=np.float32)
        d=np.ascontiguousarray(directions,dtype=np.float32)
        ranges=np.ascontiguousarray(max_ranges,dtype=np.float64)
        if o.shape!=(3,) or d.shape!=(count,3) or ranges.shape!=(count,):
            raise ValueError('ray array shape')
        output=(RayResult*count)()
        with self.tree._lock:
            if not self.tree.handle:raise RuntimeError('closed handle')
            fn=self.tree.lib.om_ro_observed_rays if observed_only else self.tree.lib.om_ro_rays
            self.tree.check(fn(self.tree.handle,
                o.ctypes.data_as(C.POINTER(C.c_float)),d.ctypes.data_as(C.POINTER(C.c_float)),
                ranges.ctypes.data_as(C.POINTER(C.c_double)),count,output))
        def number(x):return float(x) if math.isfinite(x) else None
        rows=[]
        for out in output:
            if out.status>=len(STATUS):raise RuntimeError('invalid native ray status')
            rows.append({'status':STATUS[out.status],
                **{n:int(getattr(out,n)) for n in ('terminalKnown','terminalOccupied','hitScans','freeScans')},
                **{n:number(getattr(out,n)) for n in ('maxRange','centerProjectedRange','entryProjectedRange','probability','logOdds')},
                'center':[number(x) for x in out.center], 'entry':[number(x) for x in out.entry]})
        return rows

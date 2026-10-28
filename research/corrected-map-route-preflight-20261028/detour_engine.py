"""ctypes binding to the pinned, real Recast/Detour C++ engine.

Candidate paths only. This does not establish live pose, body clearance,
observation coverage, human control compliance or physical safety. The provided
triangle set defines the available geometry. Blank/progressive mode MUST NOT pass
hidden truth triangles. Query endpoint projections never alter caller positions.
"""
from __future__ import annotations
import ctypes as C
import threading
from dataclasses import dataclass
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parent
PIN = '9f4ce64458dfae86e1239c525ddc219c4e9e06f1'
F = C.POINTER(C.c_float)
I = C.POINTER(C.c_int)

class NativeConfig(C.Structure):
    _fields_ = [(n,C.c_float) for n in ('radius','height','cell_size','cell_height','max_climb','max_slope')] + [('max_cells',C.c_int),('max_nodes',C.c_int)]

@dataclass(frozen=True)
class Config:
    radius: float = .5204
    height: float = 1.6
    cell_size: float = .1
    cell_height: float = .025
    max_climb: float = .05
    max_slope: float = 5.
    max_cells: int = 250000
    max_nodes: int = 4096

@dataclass(frozen=True)
class Route:
    points: tuple[tuple[float,float,float], ...]
    projected_start: tuple[float,float,float]
    projected_goal: tuple[float,float,float]
    complete: bool
    status: int
    error: str | None


def _array(a, dtype, shape=None):
    out=np.ascontiguousarray(a,dtype=dtype)
    if shape is not None and out.shape != shape: raise ValueError(f'expected shape {shape}, got {out.shape}')
    return out

def _fp(a): return a.ctypes.data_as(F)

def _lib():
    lib=C.CDLL(str(ROOT/'libblind_detour.so'))
    lib.bn_build.argtypes=[F,C.c_int,I,C.c_int,C.POINTER(NativeConfig)]; lib.bn_build.restype=C.c_void_p
    lib.bn_destroy.argtypes=[C.c_void_p]; lib.bn_destroy.restype=None
    lib.bn_last_error.argtypes=[]; lib.bn_last_error.restype=C.c_char_p
    lib.bn_path.argtypes=[C.c_void_p,F,F,F,F,C.c_int,F,F,C.POINTER(C.c_uint),C.POINTER(C.c_int)];lib.bn_path.restype=C.c_int
    lib.bn_velocity.argtypes=[F,C.c_float,C.c_float,F,F,C.c_float,F,C.c_int,F,C.c_int,F];lib.bn_velocity.restype=C.c_int
    return lib

class Engine:
    def __init__(self,vertices,triangles,config=Config(),*,mode='known-provided-map'):
        self.handle=None;self._lock=threading.RLock()
        if mode not in ('known-provided-map','progressively-observed-map'): raise ValueError('explicit evidence mode required')
        self.lib=_lib();self.config=config;self.mode=mode
        v=_array(vertices,np.float32);t=_array(triangles,np.int32)
        if v.ndim!=2 or v.shape[1]!=3 or t.ndim!=2 or t.shape[1]!=3: raise ValueError('mesh arrays must be N×3')
        c=NativeConfig(**config.__dict__)
        h=self.lib.bn_build(_fp(v),len(v),t.ctypes.data_as(I),len(t),C.byref(c))
        if not h: raise ValueError(self.lib.bn_last_error().decode())
        self.handle=h
    def close(self):
        with self._lock:
            if self.handle:
                self.lib.bn_destroy(self.handle);self.handle=None
    def __enter__(self):return self
    def __exit__(self,*_):self.close()
    def __del__(self):self.close()
    def route(self,start,goal,*,query_half_extents=(.20,.30,.20),max_points=256):
        with self._lock:
            if not self.handle:raise RuntimeError('closed engine')
            if not isinstance(max_points,int) or not 2<=max_points<=4096:raise ValueError('point capacity')
            a=_array(start,np.float32,(3,));b=_array(goal,np.float32,(3,));e=_array(query_half_extents,np.float32,(3,))
            out=np.zeros((max_points,3),np.float32);pa=np.full(3,np.nan,np.float32);pb=pa.copy();status=C.c_uint();complete=C.c_int()
            count=self.lib.bn_path(self.handle,_fp(a),_fp(b),_fp(e),_fp(out),max_points,_fp(pa),_fp(pb),C.byref(status),C.byref(complete))
            error=self.lib.bn_last_error().decode() or None
            return Route(tuple(tuple(float(x) for x in row) for row in out[:max(0,count)]),tuple(map(float,pa)),tuple(map(float,pb)),bool(complete.value),status.value,error)
    def candidate_velocity(self,pos,velocity,desired,*,max_speed=.5,horizon=2.5,circles=(),segments=()):
        """No delay/acceleration guarantee: caller must validate the full rollout."""
        a=_array(pos,np.float32,(3,));v=_array(velocity,np.float32,(3,));d=_array(desired,np.float32,(3,))
        cs=_array(circles,np.float32).reshape(-1,7);ss=_array(segments,np.float32).reshape(-1,6);out=np.zeros(3,np.float32)
        n=self.lib.bn_velocity(_fp(a),self.config.radius,max_speed,_fp(v),_fp(d),horizon,_fp(cs),len(cs),_fp(ss),len(ss),_fp(out))
        if n<0: raise ValueError(self.lib.bn_last_error().decode())
        return tuple(map(float,out)),n

"""Geometry-only binding. Does not issue clearance or movement authority."""
from pathlib import Path
import ctypes as C,threading,sys
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from detour_engine import Engine,Config,NativeConfig,F
DT=np.dtype([('x','<f4'),('y','<f4'),('z','<f4'),('size','<f4'),('probability','<f4'),('type','<i4'),('node','<i4'),('occupied','<i4')])
class Stats(C.Structure):
 _fields_=[(k,C.c_int) for k in ('rows','occupied','free','ground','other','width','depth','insertions','provisionalSpans','obstacleSpans')]
def lib():
 l=C.CDLL(str(Path(__file__).resolve().parent/'liboccupancy.so'))
 l.bn_build_occupancy.argtypes=[C.c_void_p,C.c_int,C.POINTER(NativeConfig)];l.bn_build_occupancy.restype=C.c_void_p
 l.bn_destroy.argtypes=[C.c_void_p];l.bn_destroy.restype=None
 l.bn_last_error.argtypes=[];l.bn_last_error.restype=C.c_char_p
 l.bn_path.argtypes=[C.c_void_p,F,F,F,F,C.c_int,F,F,C.POINTER(C.c_uint),C.POINTER(C.c_int)];l.bn_path.restype=C.c_int
 l.bn_occupancy_stats.argtypes=[C.POINTER(Stats)];l.bn_occupancy_stats.restype=None
 l.bn_occupancy_leaf_bounds.argtypes=[C.c_void_p,C.POINTER(C.c_double),C.POINTER(C.c_double)];l.bn_occupancy_leaf_bounds.restype=C.c_int
 return l
class OccupancyEngine(Engine):
 def __init__(self,rows,config):
  self.handle=None;self._lock=threading.RLock();self.lib=lib();self.config=config;self.mode='provisional-occupancy-geometry-only'
  a=np.ascontiguousarray(rows,dtype=DT)
  if a.ndim!=1:raise ValueError('one-dimensional structured ledger required')
  self.rows=a.copy();self.rows.setflags(write=False)
  c=NativeConfig(**config.__dict__);h=self.lib.bn_build_occupancy(self.rows.ctypes.data,len(a),C.byref(c))
  stats=Stats();self.lib.bn_occupancy_stats(C.byref(stats));self.stats={k:getattr(stats,k) for k,_ in stats._fields_}
  if not h:raise ValueError(self.lib.bn_last_error().decode())
  self.handle=h
 def diagnostic(self,start,goal,**kwargs):
  r=self.route(start,goal,**kwargs)
  return {'geometryCandidateComplete':r.complete,'path':r.points,'projectedStart':r.projected_start,'projectedGoal':r.projected_goal,'error':r.error,'evidenceQualifiedTraversable':False,'fullBodyCoverage':'unverified','fullFootprintSupport':'unverified','physicalAuthority':False}

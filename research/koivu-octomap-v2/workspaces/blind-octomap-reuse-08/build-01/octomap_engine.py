"""ctypes access to the pinned OctoMap core. Simulation occupancy, never physical authority."""
from pathlib import Path
import ctypes as C,hashlib
import numpy as np
ROOT=Path(__file__).resolve().parent
LIBRARY=ROOT/'build-01/libblind_octomap.so'
LIBRARY_SHA256='8cf6c8dbbfe5ef7159e8757a5d8a572c1e7be9e4addd45f2f1ec16318d2b5bd8'
class ScanStats(C.Structure):_fields_=[(x,C.c_uint64)for x in ('frame','originalPoints','occupiedKeys','representativeRays','freeKeys','treeNodes','conflictKeys')]
F=C.POINTER(C.c_float);D=C.POINTER(C.c_double);U=C.POINTER(C.c_uint32);B=C.POINTER(C.c_uint8)
def pointer(a,t):return a.ctypes.data_as(t)
class OctoMap:
 def __init__(self,resolution=.05):
  if hashlib.sha256(LIBRARY.read_bytes()).hexdigest()!=LIBRARY_SHA256:raise RuntimeError('library hash mismatch')
  self.lib=C.CDLL(str(LIBRARY));l=self.lib;l.om_last_error.restype=C.c_char_p
  l.om_create.argtypes=[C.c_double];l.om_create.restype=C.c_void_p;l.om_destroy.argtypes=[C.c_void_p]
  l.om_defaults.argtypes=[C.c_void_p,D];l.om_defaults.restype=C.c_int
  l.om_insert.argtypes=[C.c_void_p,C.c_uint64,F,C.c_uint64,F,C.POINTER(ScanStats)];l.om_insert.restype=C.c_int
  l.om_query.argtypes=[C.c_void_p,F,C.c_uint64,B,D,F,U,U];l.om_query.restype=C.c_int
  l.om_leaf_count.argtypes=[C.c_void_p];l.om_leaf_count.restype=C.c_uint64
  l.om_export.argtypes=[C.c_void_p,C.c_uint64,D,F,U,U];l.om_export.restype=C.c_int
  self.handle=l.om_create(resolution)
  if not self.handle:raise RuntimeError(l.om_last_error().decode())
 def check(self,result):
  if not result:raise RuntimeError(self.lib.om_last_error().decode())
 def close(self):
  if self.handle:self.lib.om_destroy(self.handle);self.handle=None
 def __enter__(self):return self
 def __exit__(self,*args):self.close()
 def defaults(self):
  a=np.empty(6,np.float64);self.check(self.lib.om_defaults(self.handle,pointer(a,D)));return dict(zip(('resolution','hit','miss','occupancy','clampMin','clampMax'),a.tolist()))
 def insert(self,frame,points,origin):
  p=np.ascontiguousarray(points,dtype=np.float32);o=np.ascontiguousarray(origin,dtype=np.float32)
  if p.ndim!=2 or p.shape[1]!=3 or o.shape!=(3,):raise ValueError('XYZ shape required')
  s=ScanStats();self.check(self.lib.om_insert(self.handle,frame,pointer(p,F),len(p),pointer(o,F),C.byref(s)));return {n:int(getattr(s,n))for n,_ in s._fields_}
 def query(self,points):
  p=np.ascontiguousarray(points,dtype=np.float32)
  if p.ndim!=2 or p.shape[1]!=3:raise ValueError('XYZ shape required')
  n=len(p);known=np.empty(n,np.uint8);prob=np.empty(n,np.float64);log=np.empty(n,np.float32);hits=np.empty(n,np.uint32);frees=np.empty(n,np.uint32)
  self.check(self.lib.om_query(self.handle,pointer(p,F),n,pointer(known,B),pointer(prob,D),pointer(log,F),pointer(hits,U),pointer(frees,U)))
  return {'known':known,'probability':prob,'logOdds':log,'hitScans':hits,'freeScans':frees}
 def leaves(self):
  n=int(self.lib.om_leaf_count(self.handle))
  if n>5000000:raise RuntimeError('invalid/oversize leaf count')
  values=np.empty((n,5),np.float64);log=np.empty(n,np.float32);hits=np.empty(n,np.uint32);frees=np.empty(n,np.uint32)
  self.check(self.lib.om_export(self.handle,n,pointer(values,D),pointer(log,F),pointer(hits,U),pointer(frees,U)));return {'xyzSizeProbability':values,'logOdds':log,'hitScans':hits,'freeScans':frees}

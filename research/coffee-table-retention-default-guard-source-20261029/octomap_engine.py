"""ctypes access to the pinned OctoMap core. Simulation occupancy, never physical authority."""
from pathlib import Path
import ctypes as C,hashlib,threading,functools
import numpy as np
ROOT=Path(__file__).resolve().parent
LIBRARY=ROOT/'build-04/libblind_octomap.so'
LIBRARY_SHA256='0a044001b1455634ab881cc42fb5954362d960abf5cd851b7b6dc99b6c3eb963'
class ScanStats(C.Structure):_fields_=[(x,C.c_uint64)for x in ('frame','originalPoints','occupiedKeys','representativeRays','freeKeys','treeNodes','conflictKeys')]
K=C.POINTER(C.c_uint16)
F=C.POINTER(C.c_float);D=C.POINTER(C.c_double);U=C.POINTER(C.c_uint32);B=C.POINTER(C.c_uint8)
def pointer(a,t):return a.ctypes.data_as(t)
def serialized(fn):
 @functools.wraps(fn)
 def guarded(self,*args,**kwargs):
  with self._lock:
   if not self.handle:raise RuntimeError('closed handle')
   return fn(self,*args,**kwargs)
 return guarded

def points_array(points,cap):
 if len(points)>cap:raise ValueError('point count cap before conversion')
 a=np.asarray(points)
 if a.ndim!=2 or a.shape[1]!=3:raise ValueError('XYZ shape required')
 return np.ascontiguousarray(a,dtype=np.float32)

class OctoMap:
 def __init__(self,resolution=.05):
  if hashlib.sha256(LIBRARY.read_bytes()).hexdigest()!=LIBRARY_SHA256:raise RuntimeError('library hash mismatch')
  self._lock=threading.RLock();self.lib=C.CDLL(str(LIBRARY));l=self.lib;l.om_last_error.restype=C.c_char_p
  l.om_create.argtypes=[C.c_double];l.om_create.restype=C.c_void_p;l.om_destroy.argtypes=[C.c_void_p]
  l.om_defaults.argtypes=[C.c_void_p,D];l.om_defaults.restype=C.c_int
  l.om_insert.argtypes=[C.c_void_p,C.c_uint64,F,C.c_uint64,F,C.POINTER(ScanStats)];l.om_insert.restype=C.c_int
  l.om_query.argtypes=[C.c_void_p,F,C.c_uint64,B,D,F,U,U];l.om_query.restype=C.c_int
  l.om_query_occupied.argtypes=[C.c_void_p,F,C.c_uint64,B,B];l.om_query_occupied.restype=C.c_int
  l.om_keys.argtypes=[C.c_void_p,F,C.c_uint64,K];l.om_keys.restype=C.c_int
  l.om_query_keys.argtypes=[C.c_void_p,K,C.c_uint64,B,B,D,F,U,U];l.om_query_keys.restype=C.c_int
  l.om_leaf_count.argtypes=[C.c_void_p];l.om_leaf_count.restype=C.c_uint64
  l.om_export.argtypes=[C.c_void_p,C.c_uint64,D,F,U,U];l.om_export.restype=C.c_int
  self.handle=l.om_create(resolution)
  if not self.handle:raise RuntimeError(l.om_last_error().decode())
 def check(self,result):
  if not result:raise RuntimeError(self.lib.om_last_error().decode())
 def close(self):
  with self._lock:
   if self.handle:self.lib.om_destroy(self.handle);self.handle=None
 def __enter__(self):return self
 def __exit__(self,*args):self.close()
 @serialized
 def defaults(self):
  a=np.empty(6,np.float64);self.check(self.lib.om_defaults(self.handle,pointer(a,D)));return dict(zip(('resolution','hit','miss','occupancy','clampMin','clampMax'),a.tolist()))
 @serialized
 def insert(self,frame,points,origin):
  p=points_array(points,2000000)
  if len(origin)!=3:raise ValueError('origin XYZ shape required')
  o=np.ascontiguousarray(origin,dtype=np.float32)
  if o.shape!=(3,):raise ValueError('origin XYZ shape required')
  s=ScanStats();self.check(self.lib.om_insert(self.handle,frame,pointer(p,F),len(p),pointer(o,F),C.byref(s)));return {n:int(getattr(s,n))for n,_ in s._fields_}
 @serialized
 def query(self,points):
  p=points_array(points,5000000)
  n=len(p);known=np.empty(n,np.uint8);prob=np.empty(n,np.float64);log=np.empty(n,np.float32);hits=np.empty(n,np.uint32);frees=np.empty(n,np.uint32)
  self.check(self.lib.om_query(self.handle,pointer(p,F),n,pointer(known,B),pointer(prob,D),pointer(log,F),pointer(hits,U),pointer(frees,U)))
  occupied=np.empty(n,np.uint8);again=np.empty(n,np.uint8);self.check(self.lib.om_query_occupied(self.handle,pointer(p,F),n,pointer(again,B),pointer(occupied,B)))
  if not np.array_equal(known,again):raise RuntimeError('inconsistent serial native queries')
  return {'known':known,'occupied':occupied,'probability':prob,'logOdds':log,'hitScans':hits,'freeScans':frees}
 @serialized
 def leaves(self):
  n=int(self.lib.om_leaf_count(self.handle))
  if n>5000000:raise RuntimeError('invalid/oversize leaf count')
  values=np.empty((n,5),np.float64);log=np.empty(n,np.float32);hits=np.empty(n,np.uint32);frees=np.empty(n,np.uint32)
  self.check(self.lib.om_export(self.handle,n,pointer(values,D),pointer(log,F),pointer(hits,U),pointer(frees,U)));return {'xyzSizeProbability':values,'logOdds':log,'hitScans':hits,'freeScans':frees}

 @serialized
 def keys(self,points):
  p=points_array(points,2000000);keys=np.empty((len(p),3),np.uint16);self.check(self.lib.om_keys(self.handle,pointer(p,F),len(p),pointer(keys,K)));return keys
 @serialized
 def query_keys(self,keys):
  if len(keys)>5000000:raise ValueError('key count cap before conversion')
  k=np.asarray(keys)
  if k.ndim!=2 or k.shape[1]!=3 or k.dtype!=np.uint16:raise ValueError('native uint16 XYZ keys required')
  k=np.ascontiguousarray(k);n=len(k);known=np.empty(n,np.uint8);occupied=np.empty(n,np.uint8);prob=np.empty(n,np.float64);log=np.empty(n,np.float32);hits=np.empty(n,np.uint32);frees=np.empty(n,np.uint32)
  self.check(self.lib.om_query_keys(self.handle,pointer(k,K),n,pointer(known,B),pointer(occupied,B),pointer(prob,D),pointer(log,F),pointer(hits,U),pointer(frees,U)))
  return {'known':known,'occupied':occupied,'probability':prob,'logOdds':log,'hitScans':hits,'freeScans':frees}

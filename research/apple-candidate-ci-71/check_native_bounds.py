#!/usr/bin/env python3
"""Small Linux audit of pinned66 bounds; not an Apple execution or memory proof."""
import ctypes as C,hashlib,json,sys
from pathlib import Path
class Config(C.Structure):
 _fields_=[(n,C.c_float)for n in ['radius','height','cell_size','cell_height','max_climb','max_slope']]+[(n,C.c_int)for n in ['max_cells','max_nodes']]
p=Path(sys.argv[1]);lib=C.CDLL(str(p.resolve()))
lib.bn_build_excluded.argtypes=[C.POINTER(C.c_float),C.c_int,C.POINTER(C.c_int),C.c_int,C.POINTER(Config),C.POINTER(C.c_float),C.c_int,C.c_float,C.c_float]
lib.bn_build_excluded.restype=C.c_void_p;lib.bn_last_error.restype=C.c_char_p
lib.bn_destroy.argtypes=[C.c_void_p]
c=Config(.225,1.75,.025,.025,.025,15,250000,4096)
cases=[('huge finite coordinate',[0,0,0,1e30,0,0,0,0,1],'invalid vertex'),('huge negative coordinate',[-1e30,0,0,1,0,0,0,0,1],'invalid vertex'),('oversized X extent',[0,0,0,201,0,0,0,0,1],'mesh extent limit'),('oversized Z extent',[0,0,0,1,0,0,0,0,201],'mesh extent limit'),('oversized Y extent',[0,0,0,1,21,0,0,0,1],'mesh extent limit'),('extent allowed but grid too large',[0,0,0,200,0,0,0,0,200],'grid cell cap'),('zero planar dimension',[0,0,0,1,0,0,2,0,0],'grid cell cap')]
r=[]
for name,v,expected in cases:
 a=(C.c_float*len(v))(*v);t=(C.c_int*3)(0,1,2)
 h=lib.bn_build_excluded(a,3,t,1,C.byref(c),None,0,0,0);err=lib.bn_last_error().decode()
 if h:lib.bn_destroy(h)
 assert not h and err==expected,(name,h,err)
 r.append(dict(name=name,returnedHandle=False,error=err,passed=True))
print(json.dumps(dict(scope='Existing Linux native66 bound rejection only; Apple unexecuted; no physical authority',librarySHA256=hashlib.sha256(p.read_bytes()).hexdigest(),checks=r,passed=True),indent=2))

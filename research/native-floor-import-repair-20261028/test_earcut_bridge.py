#!/usr/bin/env python3
"""Bounded real C ABI execution; exact-rational area/scanline coverage oracle."""
import ctypes, fractions, hashlib, json, math, pathlib, struct, unittest
ROOT=pathlib.Path(__file__).resolve().parents[2]
HERE=pathlib.Path(__file__).resolve().parent
LIB=ctypes.CDLL(str(HERE/'libearcut-probe.so'))
CALL=LIB.bn_earcut_simple_ring
CALL.argtypes=[ctypes.POINTER(ctypes.c_double),ctypes.c_int32,ctypes.POINTER(ctypes.c_int32),ctypes.c_int32]
CALL.restype=ctypes.c_int32
F=fractions.Fraction

def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
def triangulate(points,capacity=None):
 n=len(points);xy=(ctypes.c_double*(n*2))(*(v for p in points for v in p));cap=capacity if capacity is not None else max(0,3*(n-2));out=(ctypes.c_int32*max(1,cap))()
 count=CALL(xy,n,out,cap)
 return count,list(out[:max(0,count)])
def edges(p):return list(zip(p,p[1:]+p[:1]))
def section(p,x):
 hits=[]
 for a,b in edges(p):
  if min(a[0],b[0])<x<max(a[0],b[0]):hits.append(a[1]+(x-a[0])*(b[1]-a[1])/(b[0]-a[0]))
 hits.sort();assert len(hits)%2==0
 return list(zip(hits[::2],hits[1::2]))
def verify(points,indices):
 p=[tuple(map(F,xy)) for xy in points]
 assert indices and len(indices)%3==0 and all(0<=i<len(p) for i in indices)
 triangles=[[p[i] for i in indices[k:k+3]] for k in range(0,len(indices),3)]
 assert all(cross(*tri)>0 for tri in triangles)
 source_area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in edges(p)))
 assert sum(cross(*tri) for tri in triangles)==source_area
 # Exact slab arrangement includes every source/triangle vertex and every edge
 # intersection: a missing/overlapping patch cannot hide between sample slabs.
 all_edges=edges(p)+[e for tri in triangles for e in edges(tri)]
 xs={a[0] for a,b in all_edges}|{b[0] for a,b in all_edges}
 for (a,b) in all_edges:
  for c,d in all_edges:
   u=(b[0]-a[0],b[1]-a[1]);v=(d[0]-c[0],d[1]-c[1]);den=u[0]*v[1]-u[1]*v[0]
   if den:
    t=((c[0]-a[0])*v[1]-(c[1]-a[1])*v[0])/den
    q=((c[0]-a[0])*u[1]-(c[1]-a[1])*u[0])/den
    if 0<=t<=1 and 0<=q<=1:xs.add(a[0]+t*u[0])
 slabs=sorted(xs)
 for left,right in zip(slabs,slabs[1:]):
  x=(left+right)/2;expected=section(p,x);spans=sorted(s for tri in triangles for s in section(tri,x))
  merged=[]
  for lo,hi in spans:
   assert hi>lo
   if merged and lo<merged[-1][1]:raise AssertionError('positive-area overlap')
   if merged and lo==merged[-1][1]:merged[-1]=(merged[-1][0],hi)
   else:merged.append((lo,hi))
  assert merged==expected,(x,merged,expected)
 return {'vertices':len(p),'triangles':len(triangles),'exact_area':str(source_area/2),'exact_scanline_slabs':len(slabs)-1}

class Tests(unittest.TestCase):
 def test_square_both_windings(self):
  p=[(-1,-1),(1,-1),(1,1),(-1,1)]
  for q in [p,p[::-1]]:verify(q,triangulate(q)[1])
 def test_concave_both_windings(self):
  p=[(-1,-1),(1,-1),(1,0),(0,0),(0,1),(-1,1)]
  for q in [p,p[::-1]]:verify(q,triangulate(q)[1])
 def test_tiny_positive_area_is_retained(self):
  p=[(0,0),(2**-30,0),(0,2**-30)];self.assertEqual(triangulate(p)[0],3);verify(p,triangulate(p)[1])
 def test_collinear_boundary_vertex(self):
  p=[(0,0),(1,0),(2,0),(2,2),(0,2)];verify(p,triangulate(p)[1])
 def test_original_public_apple_floors(self):
  pins={'Hallway2':'f4cf3460fd9e746a86fe6538e2b1980e22e18207a2d3c7ea3f7679f58c8c6f4d','Bedroom3':'44df7bd5f4d1961bf13344916384dcfa20d42c7ef8dc58b0e13d1c2f7c6a4d2e'}
  rows=[]
  f32=lambda x:struct.unpack('<f',struct.pack('<f',x))[0]
  for name,pin in pins.items():
   data=(ROOT/f'ios/BlindAssistTests/Fixtures/RoomPlanApple/{name}.capturedRoom.json').read_bytes();self.assertEqual(hashlib.sha256(data).hexdigest(),pin)
   feature=json.loads(data)['floors'][0];p=[tuple(map(f32,v[:2])) for v in feature['polygonCorners']]
   count,indices=triangulate(p);row=verify(p,indices);row.update(fixture=name,source_sha256=pin,indices=indices);rows.append(row)
  (HERE/'EARCUT_PUBLIC_FLOOR_RESULTS.json').write_text(json.dumps(rows,indent=2)+'\n')
 def test_nan_and_infinity_rejected(self):
  for x in [math.nan,math.inf,-math.inf]:self.assertEqual(triangulate([(0,0),(1,0),(0,x)])[0],-1)
 def test_under_and_over_vertex_budget_rejected(self):
  for n in [0,1,2,1025]:self.assertEqual(triangulate([(0,0)]*n)[0],-1)
 def test_output_capacity_rejected(self):
  self.assertEqual(triangulate([(0,0),(1,0),(0,1)],capacity=2)[0],-1)
 def test_exact_oracle_rejects_overlap_and_missing_patch(self):
  p=[(-1,-1),(1,-1),(1,1),(-1,1)]
  for i in [[0,1,2],[0,1,2,0,1,2]]:
   with self.assertRaises(AssertionError):verify(p,i)
 def test_exact_oracle_rejects_concavity_bridge(self):
  p=[(-1,-1),(1,-1),(1,0),(0,0),(0,1),(-1,1)]
  with self.assertRaises(AssertionError):verify(p,[0,1,4,0,4,5])
if __name__=='__main__':unittest.main(verbosity=2)

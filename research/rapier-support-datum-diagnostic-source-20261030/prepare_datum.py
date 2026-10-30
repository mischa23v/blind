#!/usr/bin/env python3
"""Source-only support datum inspector. All outputs estimated; no engine import."""
import argparse, ast, copy, hashlib, json, math, pathlib, struct
H=pathlib.Path(__file__).resolve().parent
W=H.parents[2]
SELECT=[('conference','conference:table_92_to_120:960'),('conference','conference:table_120_to_200:2051'),('conference','conference:table_20_to_92:1057'),('conference','conference:varpu_160_to_130:966'),('coffee','coffee:0_to_8:630'),('coffee','coffee:0_to_8:1643')]
WINDOW=.10
COS=math.cos(math.radians(15))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def arrays(vb,ib):
 if len(vb)%12 or len(ib)%12: raise ValueError('invalid buffer lengths')
 v=list(struct.iter_unpack('<fff',vb));t=list(struct.iter_unpack('<III',ib))
 if any(not math.isfinite(c) for p in v for c in p) or any(i>=len(v) for f in t for i in f): raise ValueError('invalid mesh')
 return v,t
def ids_npy(b):
 if b[:8]!=b'\x93NUMPY\x01\x00': raise ValueError('expected NPY1')
 n=struct.unpack('<H',b[8:10])[0];h=ast.literal_eval(b[10:10+n].decode())
 if h['descr']!='<i8' or h['fortran_order'] or len(h['shape'])!=1: raise ValueError('ground ID format')
 p=b[10+n:]
 if len(p)!=8*h['shape'][0]: raise ValueError('ground ID bytes')
 return set(x[0] for x in struct.iter_unpack('<q',p))
def normal(a,b,c):
 u=[b[i]-a[i] for i in range(3)];v=[c[i]-a[i] for i in range(3)]
 q=(u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]);s=math.sqrt(sum(x*x for x in q))
 return tuple(x/s for x in q) if s else None
def hit(x,z,a,b,c):
 # Barycentric vertical intersection in XZ; exact fixed numerical epsilon only.
 den=(b[2]-c[2])*(a[0]-c[0])+(c[0]-b[0])*(a[2]-c[2])
 if abs(den)<1e-15:return None
 u=((b[2]-c[2])*(x-c[0])+(c[0]-b[0])*(z-c[2]))/den
 v=((c[2]-a[2])*(x-c[0])+(a[0]-c[0])*(z-c[2]))/den
 w=1-u-v
 if min(u,v,w)<-1e-12:return None
 return u*a[1]+v*b[1]+w*c[1]
def sample_xz(foot,yaw):
 # comparator +X forward, heading convention forward=(cos(yaw),sin(yaw)).
 co,si=math.cos(yaw),math.sin(yaw)
 return [(foot[0]+f*co-l*si,foot[2]+f*si+l*co) for f in (-.15,0,.15) for l in (-.225,0,.225)]
def inspect(v,t,p,eligible=None):
 f=p['foot'];xz=sample_xz(f,p['yawRadians']);samples=[[] for _ in xz]
 for i,tri in enumerate(t):
  if eligible is not None and i not in eligible:continue
  a,b,c=(v[j] for j in tri);n=normal(a,b,c)
  if n is None or n[1]<COS:continue
  for k,(x,z) in enumerate(xz):
   y=hit(x,z,a,b,c)
   if y is not None and abs(y-f[1])<=WINDOW:
    samples[k].append({'triangleID':i,'height':y,'normal':list(n)})
 for s in samples:s.sort(key=lambda r:(abs(r['height']-f[1]),r['triangleID']))
 out={'originalProbe':copy.deepcopy(p),'estimatedOnly':True,'semanticFloorEstablished':False,'supportEstablished':False,'movementEligible':False,'windowMetres':WINDOW,'sampleXZ':xz,'allSampleLayers':samples,'sampleLayerScope':'eligible signed-upward triangles within fixed height window and optional geometric component; not all raw hazards','status':'unresolved','candidateFoot':None}
 if not samples[4]:return out
 center=samples[4][0];tri=[v[i] for i in t[center['triangleID']]];a,b,c=tri;n=center['normal']
 u=[b[i]-a[i] for i in range(3)];w=[c[i]-a[i] for i in range(3)]
 cross=(u[1]*w[2]-u[2]*w[1],u[2]*w[0]-u[0]*w[2],u[0]*w[1]-u[1]*w[0]);area=.5*math.sqrt(sum(z*z for z in cross))
 def plane(x,z):return a[1]-(n[0]*(x-a[0])+n[2]*(z-a[2]))/n[1]
 heights=[plane(x,z) for x,z in xz];datum=max(heights[k] for k in (0,2,6,8));candidate=list(f);candidate[1]=datum+.002
 corners=[{'sampleIndex':k,'xz':list(xz[k]),'insideSelectedTriangle':hit(*xz[k],*tri) is not None,'extrapolated':hit(*xz[k],*tri) is None} for k in (0,2,6,8)]
 out.update(status='estimatedCandidateOnly',centerTriangleID=center['triangleID'],selectedTriangleVertices=[list(q) for q in tri],selectedTriangleAreaSquareMetres=area,nominalCornerCoverage=corners,unoffsetPlaneMaxDatumY=datum,queryPlacementOffsetMetres=.002,verticalPaddingNormalComponentMetres=.002*n[1],offsetConvention='frozen vertical Y query-foot padding, not exact normal separation or KCC compensation; KCC retains its separate unchanged 2mm controller offset',placementFootprint='nominal0.45x0.30m only; identical candidate foot used for body and margin; margin not separately lifted',candidateFoot=candidate,candidateVerticalShiftMetres=candidate[1]-f[1],planeNormal=n,planeSampleHeights=heights,missingRaySampleIndices=[i for i,s in enumerate(samples) if not s])
 return out
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',type=pathlib.Path,required=True);args=ap.parse_args()
 pins=json.loads((H/'INPUT_PINS.json').read_text())
 for name,h in pins.items():
  if digest(W/name)!=h:raise ValueError('input drift '+name)
 results=[]
 for scene in ('conference','coffee'):
  d=W/'rapier-real-room-inputs-001';v,t=arrays((d/(scene+'.vertices.f32')).read_bytes(),(d/(scene+'.indices.u32')).read_bytes());probes={p['id']:p for p in json.loads((d/(scene+'.probes.json')).read_text())}
  eligible=ids_npy((W/'coffee-joint-route-body-attempt-001/comparison/GROUND_IDS_0_8.npy').read_bytes()) if scene=='coffee' else None
  if eligible is not None and (len(eligible)!=4827 or min(eligible)<0 or max(eligible)>=len(t)):raise ValueError('ground ID inventory')
  for s,k in SELECT:
   if s!=scene:continue
   r=inspect(v,t,probes[k],eligible);r.update(scene=scene,componentRestriction=('geometric-only4827' if eligible is not None else 'none; no original component'));results.append(r)
 if len(results)!=6:raise ValueError('six original probes required')
 args.output.mkdir(parents=False,exist_ok=False)
 packet={'status':'candidateGeometryInspectionOnly','physicalAuthority':False,'nativeEngineExecuted':False,'movementApplied':False,'originalMeshesModified':False,'results':results,'inputPins':pins}
 (args.output/'CANDIDATE_DATUMS.json').write_text(json.dumps(packet,indent=2,allow_nan=False)+'\n')
if __name__=='__main__':main()

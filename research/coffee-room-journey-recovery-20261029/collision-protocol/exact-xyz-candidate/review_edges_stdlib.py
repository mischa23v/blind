import resource,time,pathlib,json,math,gzip,collections,hashlib,ast,struct
resource.setrlimit(resource.RLIMIT_CPU,(10,10));resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));began=time.monotonic();cpu=time.process_time()
h=pathlib.Path('blind/research/coffee-room-journey-recovery-20261029/collision-protocol'); mesh=pathlib.Path('coffee-recovered-source/textured.obj');f=-1.6301633051396203
vertices=[];faces=[]
for line in mesh.open():
 q=line.split()
 if not q:continue
 if q[0]=='v':vertices.append(tuple(map(float,q[1:])))
 elif q[0]=='f':faces.append(tuple(int(x.split('/')[0])-1 for x in q[1:]))
assert(len(vertices),len(faces))==(51965,87370)
canonical={};canon=[];freq=collections.Counter(vertices)
for p in vertices:
 if p not in canonical:canonical[p]=len(canonical)
 canon.append(canonical[p])
props=[]
for face in faces:
 p=[(vertices[i][0],vertices[i][1]-f,vertices[i][2])for i in face];a=[p[1][i]-p[0][i]for i in range(3)];b=[p[2][i]-p[0][i]for i in range(3)];n=(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]);norm=math.sqrt(sum(x*x for x in n));ny=abs(n[1])/norm if norm else float('nan'); bounds=tuple(v for i in range(3)for v in(min(x[i]for x in p),max(x[i]for x in p)));props.append((ny,bounds))
initial={}
with gzip.open(h/'attempt001-review/CONTACTS.jsonl.gz','rt')as inp:
 for line in inp:
  r=json.loads(line)
  if r['arm']=='B_initial':initial[tuple(r['path'])]=r
schedule=json.loads((h/'SCHEDULE_20.json').read_text());out=[];threshold=math.cos(math.radians(5))
def graph(ids,usecanon):
 parent={i:i for i in ids};size={i:1 for i in ids};edges={};joined=0
 def find(i):
  while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
  return i
 for i in ids:
  tri=tuple(canon[v]for v in faces[i]) if usecanon else faces[i]
  for a,b in ((tri[0],tri[1]),(tri[1],tri[2]),(tri[2],tri[0])):
   edge=(a,b)if a<b else(b,a)
   if edge in edges:
    x,y=find(i),find(edges[edge])
    if x!=y:
     if size[x]<size[y]:x,y=y,x
     parent[y]=x;size[x]+=size[y];joined+=1
   else:edges[edge]=i
 return {i:find(i)for i in ids},len(ids)-joined
rows=[]
for path in schedule['paths']:
 key=(path['start'],path['goal']);r=initial[key];chain=path['chain'];bounds=[min(p[0]for p in chain)-.8,max(p[0]for p in chain)+.8,-.25,.25,min(p[2]for p in chain)-.8,max(p[2]for p in chain)+.8]
 def within(b):return b[2]>=bounds[2] and b[3]<=bounds[3] and b[1]>=bounds[0] and b[0]<=bounds[1] and b[5]>=bounds[4] and b[4]<=bounds[5]
 ids=[i for i,(ny,b) in enumerate(props)if math.isfinite(ny) and threshold<=ny<=1+1e-12 and within(b)]
 labels,_=graph(ids,True);seeds=[p['referenceCellID']for p in r['probes']['probes']];roots={labels[i]for i in seeds if i in labels};selected=[i for i in ids if labels[i]in roots]
 edges=collections.defaultdict(list);tris=collections.Counter()
 for i in selected:
  tri=faces[i];c=tuple(canon[v]for v in tri);tris[tuple(sorted(c))]+=1
  for x,y in ((0,1),(1,2),(2,0)):edges[tuple(sorted((c[x],c[y])))].append((i,tuple(sorted((tri[x],tri[y])))))
 added=[v for v in edges.values()if len({e for _,e in v})>1]
 nonman=[v for v in edges.values()if len(v)>2]
 rows.append({'path':list(key),'seedComponentsSelected':len(roots),'selectedFaceCount':len(selected),'newCrossIndexEdges':len(added),'nonmanifoldCanonicalEdges':len(nonman),'maximumEdgeIncidence':max(map(len,edges.values()),default=0),'exactDuplicateTrianglesBeyondFirst':sum(n-1 for n in tris.values()),'nonmanifoldWitnessFaces':[ [i for i,_ in v]for v in nonman[:5]]})
result={'status':'stdlib-static-source-edge-review-no-native-execution','meshSHA256':hashlib.sha256(mesh.read_bytes()).hexdigest(),'paths':rows,'limits':{'CPUSeconds':10,'addressSpaceBytes':512*1024**2},'usage':{'CPUSeconds':time.process_time()-cpu,'wallSeconds':time.monotonic()-began,'maxRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024},'limitation':'Exact edge topology cannot establish semantic sheet identity. Selected components include eligible seed components even when ninth seed is ineligible.'}
(h/'exact-xyz-candidate/EDGE_AMBIGUITY_REVIEW.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))

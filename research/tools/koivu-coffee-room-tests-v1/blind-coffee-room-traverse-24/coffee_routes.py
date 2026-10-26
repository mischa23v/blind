"""Bounded Coffee phone-only provided-map route test. No reference input selection."""
from pathlib import Path
import collections,hashlib,importlib.util,itertools,json,math,sys
sys.dont_write_bytecode=True
import numpy as np
from scipy import ndimage
HERE=Path(__file__).resolve().parent;WS=HERE.parent
PAIR=WS/'blind-corrected-mask-route-comparison-18/paired_adapter.py'
PAIR_SHA='86d4510a3f801a2f5dd303fe184c8fe0f3fb1d1c90b9057ab1665352939d7c04'
INPUT=WS/'blind-pose-experiments-review-17/upstream/pose-consistency/runs/coffee_floorfix'
MASK=INPUT/'occthres_split0.7.npz';META=INPUT/'pipeline2_out.npz'
MASK_SHA='8cf54a1d2e9f4e6a01f212975cc985a9bcbb88ffb243b36106db78be58006efa'
META_SHA='57c8552dbd98c966f26625dc1440bd77ff4cfb4257966b4cf6af76bfcd95963b'
DIRECTIONS=((1,0),(1,1),(0,1),(-1,1),(-1,0),(-1,-1),(0,-1),(1,-1))
KEYS=('support','deepBelow','nearDip','low1','lowUnresolvedFlag','highObstacle','highUnknown','walk')
ACCESS=[]
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def load(name,p,expected):
 if sha(p)!=expected:raise ValueError('source pin: '+str(p))
 spec=importlib.util.spec_from_file_location(name,p);m=importlib.util.module_from_spec(spec);sys.modules[name]=m;spec.loader.exec_module(m);return m
def phone_inputs():
 if sha(MASK)!=MASK_SHA or sha(META)!=META_SHA:raise ValueError('input hash')
 with np.load(MASK,allow_pickle=False) as z:
  if set(z.files)!=set(KEYS):raise ValueError('mask allowlist')
  flags={k:z[k].copy() for k in KEYS};ACCESS.append({'path':str(MASK.relative_to(WS)),'arrayKeysRead':list(KEYS)})
 with np.load(META,allow_pickle=False) as z:
  m={k:z[k].copy() for k in ('lo','res','R','t')};ACCESS.append({'path':str(META.relative_to(WS)),'arrayKeysRead':['lo','res','R','t']})
 if float(m['res'])!=.05 or m['lo'].shape!=(3,) or m['R'].shape!=(3,3) or m['t'].shape!=(3,):raise ValueError('metadata schema')
 if any(a.dtype!=np.bool_ or a.shape!=(151,179) for a in flags.values()):raise ValueError('mask schema')
 if not np.isfinite(m['R']).all() or not np.isfinite(m['t']).all() or not np.allclose(m['R']@m['R'].T,np.eye(3),atol=1e-8,rtol=0) or abs(np.linalg.det(m['R'])-1)>1e-8:raise ValueError('rigid frame')
 return flags,m

def select(mask,origin):
 clearance=ndimage.distance_transform_edt(np.pad(mask,1,constant_values=False))[1:-1,1:-1]*.05-.05*math.sqrt(2)/2
 cells=np.argwhere(mask&(clearance>=.35));endpoints=[];labels=[];seen={}
 if len(cells):
  d=clearance[cells[:,0],cells[:,1]]
  for direction in DIRECTIONS:
   score=cells@np.asarray(direction);q=int(np.lexsort((cells[:,1],cells[:,0],-d,-score))[0]);ij=tuple(map(int,cells[q]));xy=np.asarray(origin)+(cells[q]+.5)*.05
   if ij not in seen:
    seen[ij]=len(endpoints);endpoints.append({'id':len(endpoints),'sourceIJ':list(ij),'levelXYMetres':xy.tolist(),'gameXYZMetres':[float(xy[0]),0.,float(-xy[1])],'clearanceLowerBoundMetres':float(d[q])})
   labels.append({'directionIJ':list(direction),'endpointID':seen[ij]})
 labs,n=ndimage.label(mask,ndimage.generate_binary_structure(2,1));sizes=np.bincount(labs.ravel())[1:]
 raw=np.argwhere(mask)
 return {'selectionMadeBeforeNativeQueries':True,'sharedAcrossProfiles':True,'qualifyingCentreCount':len(cells),'endpoints':endpoints,'directionEndpoints':labels,'rawWalkCellCount':int(mask.sum()),'rawWalkAreaSquareMetres':float(mask.sum()*.05**2),'rawWalkCentreSpanMetres':((raw.max(0)-raw.min(0))*.05).tolist() if len(raw) else [],'selectedEndpointSpanMetres':((np.array([p['sourceIJ'] for p in endpoints]).max(0)-np.array([p['sourceIJ'] for p in endpoints]).min(0))*.05).tolist() if endpoints else [],'rawWalk4ConnectedComponents':int(n),'rawWalk4ConnectedComponentCellsDescending':sorted(map(int,sizes),reverse=True),'endpoints4ConnectedComponentIDs':[int(labs[tuple(p['sourceIJ'])])for p in endpoints]}

def model(pa,profile,flags,meta):
 variants=pa.load('coffee_profiles_'+profile,pa.VARIANTS/'margin_variants.py',pa.VARIANTS_SHA)
 cm=variants.base_module();g=variants.geometry(profile);rr=variants.rectangle_module(profile)
 if sha(pa.NATIVE/'libblind_detour.so')!=pa.LIB_SHA:raise ValueError('native lib')
 de=variants.load_pinned('coffee_detour_'+profile,pa.NATIVE/'detour_engine.py',variants.BINDING_SHA)
 class CoffeeMap(cm.CandidateMap):
  def __init__(self):
   self.engine=None;self.rr=rr;self.de=de;self.flags=flags;self.mask=flags['walk'];self.lo=meta['lo'];self.R=meta['R'];self.t=meta['t'];self.origin=tuple((self.lo[:2]*.05).tolist())
   self.revision=hashlib.sha256((MASK_SHA+META_SHA+json.dumps(g,sort_keys=True)+pa.LIB_SHA).encode()).hexdigest()
   for a in [self.lo,self.R,self.t,*self.flags.values()]:a.setflags(write=False)
   vertices,triangles=rr.quads(self.mask,self.origin,.05);vertices[:,2]*=-1;triangles=triangles[:,[0,2,1]].copy()
   self.engine=de.Engine(vertices,triangles,de.Config(radius=g['nativeRadiusIntended'],height=1.75,cell_size=.025,max_climb=0.),mode='known-provided-map')
 return CoffeeMap(),g

def fixtures():
 mask=np.ones((50,50),bool);r=select(mask,(0.,0.));assert len(r['endpoints'])==4
 assert select(mask,(0.,0.))==r
 assert select(np.zeros((50,50),bool),(0.,0.))['endpoints']==[]
 assert len({tuple(p['sourceIJ'])for p in r['endpoints']})==4
 return 4

def prepare():
 fixture_count=fixtures();flags,meta=phone_inputs();end=select(flags['walk'],meta['lo'][:2]*.05)
 (HERE/'ENDPOINTS.json').write_text(json.dumps(end,indent=2)+'\n')
 # Include all transitive original sources and input artifacts; no reference fields materialized.
 pa=load('coffee_prepare_pa',PAIR,PAIR_SHA)
 variants=pa.load('coffee_prepare_variants',pa.VARIANTS/'margin_variants.py',pa.VARIANTS_SHA);cm=variants.base_module()
 files=[Path(__file__),HERE/'run_bounded.py',HERE/'PROTOCOL.md',HERE/'ENDPOINTS.json',PAIR,MASK,META,pa.VARIANTS/'margin_variants.py',pa.NATIVE/'detour_engine.py',pa.NATIVE/'libblind_detour.so',pa.GAME/'source/candidate_map.py',pa.GAME/'two-approach-selection-11/select_approaches.py',pa.GAME/'table-loop-proposal/table_loop.py',pa.GAME/'table-loop-proposal/topology_quick.py',*cm.SOURCE_PINS]
 freeze={'scope':'Coffee supplied-phone-map availability; no episode or reference scoring','profiles':list(pa.PROFILES),'endpointPolicy':'PROTOCOL.md','endpointCount':len(end['endpoints']),'orderedQueriesPerProfile':len(end['endpoints'])*(len(end['endpoints'])-1),'fixtureChecksPassed':fixture_count,'referenceDataUsed':False,'files':{str(p.relative_to(WS)):sha(p) for p in files}}
 (HERE/'FROZEN.json').write_text(json.dumps(freeze,indent=2)+'\n');print(json.dumps({'frozenSHA256':sha(HERE/'FROZEN.json'),'endpoints':end}))

def main(out,expected):
 if sha(HERE/'FROZEN.json')!=expected:raise ValueError('manifest')
 pins=json.loads((HERE/'FROZEN.json').read_text())['files']
 def verify():
  for p,h in pins.items():
   if sha(WS/p)!=h:raise ValueError('changed pin '+p)
 verify();out=Path(out);out.mkdir(exist_ok=False);flags,meta=phone_inputs();end=json.loads((HERE/'ENDPOINTS.json').read_text())
 if select(flags['walk'],meta['lo'][:2]*.05)!=end:raise ValueError('endpoint repeat mismatch')
 pa=load('coffee_run_pa',PAIR,PAIR_SHA);helpers=pa.helper_modules();summaries=[]
 for profile in pa.PROFILES:
  m,g=model(pa,profile,flags,meta);routes=[]
  try:
   for a,b in itertools.permutations(end['endpoints'],2):
    r=pa.query_fixed(m,a['gameXYZMetres'],b['gameXYZMetres'],helpers);r['startEndpointID']=a['id'];r['goalEndpointID']=b['id'];r['straightLineEndpointDistanceMetres']=float(np.linalg.norm(np.asarray(a['levelXYMetres'])-b['levelXYMetres']))
    if r['status']=='fixedPhoneModelLegAccepted':
     r['sampledFootprintDiagnostic']=helpers['approach'].check_open(m,np.asarray(r['planarFootprintValidationPath']));r['sampledFootprintDiagnostic'].pop('sampledCentrePosesInsideROI',None);r['sampledFootprintDiagnostic'].pop('sampledFootprintPosesTouchingROI',None);r['sampledFootprintDiagnostic'].pop('sampledROIIntersectionAffectsAcceptance',None)
    routes.append(r)
  finally:m.close()
  accepted=[r for r in routes if r['status']=='fixedPhoneModelLegAccepted'];lengths=[r['openPathCheck']['horizontalLengthMetres']for r in accepted]
  summary={'profile':profile,'geometry':g,'queries':len(routes),'accepted':len(accepted),'statusCounts':dict(collections.Counter(r['status']for r in routes)),'nativeReasonCounts':dict(collections.Counter(r['nativeAndOriginalRectangleResult']['reason']for r in routes)),'acceptedLengthMetresMinMax':[min(lengths),max(lengths)] if lengths else None,'maximumAcceptedEndpointDisplacementMetres':max((r['straightLineEndpointDistanceMetres']for r in accepted),default=None),'acceptedRoutesTouchingLowUnresolved':sum(r['sampledFootprintDiagnostic']['lowUnresolvedSampledCells']>0 for r in accepted),'allAcceptedSampledFootprintRechecksPassed':all(r['sampledFootprintDiagnostic']['passed']for r in accepted),'acceptedEndpointPairs':[[r['startEndpointID'],r['goalEndpointID']]for r in accepted]}
  (out/(profile+'.json')).write_text(json.dumps(pa.safe({'summary':summary,'routes':routes}),indent=2)+'\n');summaries.append(summary);print(json.dumps(pa.safe(summary)),flush=True)
 verify();result={'room':'coffee_room','inputMode':'supplied corrected split-0.7 derived map; not raw reconstruction rerun','endpointSelection':end,'profiles':summaries,'arrayAccessLog':ACCESS,'metadataArrayReadAllowlist':['lo','res','R','t'],'referenceGeometryLoaded':False,'referenceArraysRead':False,'movementEpisodesExecuted':0,'physicalMovementExecuted':False,'physicalAuthority':False,'limits':'Finite shared endpoint test, not whole physical room coverage or swept-triangle proof','sourceHashesVerifiedBeforeAndAfter':True,'frozenManifestSHA256':expected}
 (out/'RESULTS.json').write_text(json.dumps(pa.safe(result),indent=2)+'\n')
if __name__=='__main__':
 if sys.argv[1]=='prepare':prepare()
 else:main(sys.argv[1],sys.argv[2])

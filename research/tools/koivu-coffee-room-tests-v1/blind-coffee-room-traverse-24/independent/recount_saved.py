"""Read-only saved-evidence recount; never imports planner or materializes NPZ arrays."""
from pathlib import Path
import collections,hashlib,itertools,json,math
ROOT=Path(__file__).resolve().parents[1];WS=ROOT.parent

def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for c in iter(lambda:f.read(65536),b''):h.update(c)
 return h.hexdigest()
def load(p):return json.loads(p.read_text())
manifest=load(ROOT/'FROZEN.json');receipt=load(ROOT/'run-01/RUN_RECEIPT.json');end=load(ROOT/'ENDPOINTS.json');summary=load(ROOT/'run-01/result/RESULTS.json')
assert sha(ROOT/'FROZEN.json')==receipt['frozenManifestSHA256']==summary['frozenManifestSHA256']
assert all(sha(WS/p)==h for p,h in manifest['files'].items())
assert receipt['success'] and receipt['exitCode']==0 and not receipt['failure']
assert summary['endpointSelection']==end and end['selectionMadeBeforeNativeQueries']
assert summary['referenceArraysRead'] is False and summary['referenceGeometryLoaded'] is False and summary['movementEpisodesExecuted']==0
assert summary['arrayAccessLog'][1]['arrayKeysRead']==['lo','res','R','t']
assert summary['arrayAccessLog'][0]['arrayKeysRead']==['support','deepBelow','nearDip','low1','lowUnresolvedFlag','highObstacle','highUnknown','walk']
endpoints=end['endpoints'];assert len(endpoints)==7
allpairs=set(itertools.permutations(range(7),2));groups=({0,1,5,6},{2,3,4});cross={(a,b) for a,b in allpairs if (a in groups[0])!=(b in groups[0])}
reports=[]
for profile in manifest['profiles']:
 p=ROOT/'run-01/result'/f'{profile}.json';data=load(p);rows=data['routes'];saved=data['summary']
 assert saved==next(r for r in summary['profiles'] if r['profile']==profile)
 pairs=[(r['startEndpointID'],r['goalEndpointID']) for r in rows]
 assert len(rows)==42 and set(pairs)==allpairs and len(pairs)==len(set(pairs))
 accepted=[r for r in rows if r['status']=='fixedPhoneModelLegAccepted'];lengths=[];direct=[]
 for r in rows:
  a=endpoints[r['startEndpointID']]['gameXYZMetres'];b=endpoints[r['goalEndpointID']]['gameXYZMetres']
  assert r['requestedStartXYZ']==a and r['requestedGoalXYZ']==b
  assert not r['fixedObjectivesRelocated'] and not r['movementExecuted'] and not r['physicalAuthority']
  assert abs(math.hypot(a[0]-b[0],a[2]-b[2])-r['straightLineEndpointDistanceMetres'])<1e-12
 for r in accepted:
  path=r['planarFootprintValidationPath'];assert path[0]==r['requestedStartXYZ'] and path[-1]==r['requestedGoalXYZ']
  assert r['nativeAndOriginalRectangleResult']['complete'] and r['nativeAndOriginalRectangleResult']['nativeComplete']
  assert r['openPathCheck']['passed'] and r['sampledFootprintDiagnostic']['passed']
  assert r['startAssociation']['existingHorizontalAssociationAtMost0p10m'] and r['goalAssociation']['existingHorizontalAssociationAtMost0p10m']
  n=sum(math.hypot(b[0]-a[0],b[2]-a[2]) for a,b in zip(path[:-1],path[1:]))
  assert abs(n-r['openPathCheck']['horizontalLengthMetres'])<1e-12
  assert abs(n-r['sampledFootprintDiagnostic']['pathLengthMetres'])<1e-12
  lengths.append(n);direct.append(r['straightLineEndpointDistanceMetres'])
 reasons=dict(collections.Counter(r['nativeAndOriginalRectangleResult']['reason'] for r in rows));assert reasons==saved['nativeReasonCounts']
 assert dict(collections.Counter(r['status'] for r in rows))==saved['statusCounts']
 assert len(accepted)==saved['accepted'] and all(abs(a-b)<1e-12 for a,b in zip([min(lengths),max(lengths)],saved['acceptedLengthMetresMinMax']))
 assert max(direct)==saved['maximumAcceptedEndpointDisplacementMetres']
 incomplete={(r['startEndpointID'],r['goalEndpointID'])for r in rows if r['nativeAndOriginalRectangleResult']['reason']=='incomplete'}
 assert incomplete==cross and len(incomplete)==24
 low=[r['sampledFootprintDiagnostic']['lowUnresolvedSampledCells'] for r in accepted]
 assert all(n>0 for n in low) and saved['acceptedRoutesTouchingLowUnresolved']==len(accepted)
 reports.append({'profile':profile,'savedRouteFileSHA256':sha(p),'orderedQueryCount':len(rows),'accepted':len(accepted),'nativeReasons':reasons,'minimumLengthMetres':min(lengths),'maximumLengthMetres':max(lengths),'maximumEndpointDisplacementMetres':max(direct),'acceptedPathsAtLeast2Metres':sum(v>=2 for v in lengths),'acceptedEndpointPairsAtLeast2MetresApart':sum(v>=2 for v in direct),'acceptedPathsUnder0p10Metres':sum(v<.1 for v in lengths),'lowUnresolvedCellCountsAmongAcceptedMinMax':[min(low),max(low)],'incompleteCrossGroupQueryCount':len(incomplete),'acceptedPathEndpointsExact':True,'lengthArithmeticReproduced':True})
result={'scope':'Independent source review and saved JSON arithmetic; no new route query and no NPZ array materialization','frozenManifestSHA256':sha(ROOT/'FROZEN.json'),'all18PinnedFileHashesVerified':len(manifest['files'])==18,'frozenSourcePinCount':len(manifest['files']),'allOrderedPairsPresentExactlyOnce':True,'profiles':reports,'commonNativeIncompleteEndpointPartition':[[0,1,5,6],[2,3,4]],'claimCautions':['Two accepted ordered paths in every profile connect endpoints just 5 cm apart; accepted-query counts are not room coverage.','The endpoints span 5.0 x 3.1 m but all accepted endpoint displacements are at most 2.05 m.','No cross-group candidate is accepted; this bounded native/rectangle policy does not prove physical impossibility.','Reference array access log is self-reported, corroborated by inspected explicit-key loading source; this audit did not trace OS reads.','No movement episode, continuous swept-body test or FARO triangle scoring occurred.']}
(ROOT/'independent/RECOUNT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

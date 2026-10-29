"""Read saved records only; no geometry/native query. Deterministic gzip export."""
import gzip,hashlib,json,math,pathlib
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    p=W/'coffee-clearance-comparison-attempt-002/comparison/PROPOSALS.json'
    first=W/'coffee-clearance-comparison-attempt-001/comparison/PROPOSALS.json'
    guard=W/'coffee-clearance-comparison-attempt-002/GUARD_RUN/RESULT.json'
    data=json.loads(p.read_text());g=json.loads(guard.read_text());q=data['paths'][0]
    original=next(x for x in json.loads(first.read_text())['paths']if(x['start'],x['goal'])==(0,8))
    if q['baselineArmsUnchanged']!=original:raise ValueError('baseline changed')
    length=lambda pts:sum(math.dist(a,b)for a,b in zip(pts,pts[1:]))
    rows={}
    for arm in ('distanceGrid','clearanceGrid'):
        v=q['manualRepair'][arm];diag=v['independentManualWindowDiagnostic'];chain=v['requestedConnectorChainXYZ']
        lengths={'nativeGridLengthMetres':length(v['pointsXYZ']),'connectorInclusiveLengthMetres':length(chain)}
        if abs(lengths['nativeGridLengthMetres']-v['lengthMetres'])>1e-10:raise ValueError('length recount mismatch')
        if chain[0]!=original['requestedStartXYZ']or chain[-1]!=original['requestedGoalXYZ']:raise ValueError('requested endpoint changed')
        if len(diag['segments'])!=len(chain)-1:raise ValueError('incomplete saved connector check')
        distances=[]
        for i,s in enumerate(diag['segments']):
            if s['index_zero_based']!=i or len(s['windows'])!=2:raise ValueError('saved diagnostic schedule')
            for d in s['windows']:
                if d['body_margin_contact']or d['distance_metres']<=q['edgeFilter']['bodyCircumscribedRadiusPlusMarginMetres']+q['edgeFilter']['numericalGuardMetres']:raise ValueError('saved manual contact')
                distances.append(d['distance_metres'])
        if diag['manual_exclusion_contact']is not False:raise ValueError('manual veto flag')
        rows[arm]={**lengths,'minimumSavedDistanceToManualWindowsMetres':min(distances),
            'minimumSavedResidualAfterRadialBodyAndMarginMetres':min(distances)-q['edgeFilter']['bodyCircumscribedRadiusPlusMarginMetres'],
            'connectorInclusiveSavedSegmentsChecked':len(diag['segments']),
            'manualWindowContact':False,'sampledNavmeshWall':v['sampledWallDiagnostic']}
    before={name:sha(R/name)==digest for name,digest in g['inputHashesBefore'].items()if name.startswith('research/')and name.endswith('.py')}
    if not all(before.values())or g['inputHashesBefore']!=g['inputHashesAfter']:raise ValueError('source/input pin drift')
    compressed=gzip.compress(p.read_bytes(),mtime=0);(H/'PROPOSALS.json.gz').write_bytes(compressed)
    if gzip.decompress(compressed)!=p.read_bytes():raise ValueError('gzip roundtrip')
    result={'status':'savedResultIndependentlyRecountedNoNativeQueries','sourceCommit':g['sourceCommit'],
        'proposalSHA256':sha(p),'gzipSHA256':sha(H/'PROPOSALS.json.gz'),'gzipBytes':len(compressed),
        'guardSHA256':sha(guard),'baselineExactlyPreserved':True,'baselineOriginalNativeLengthMetres':length(original['originalNativePoints']),
        'baselineCenteredLengthMetres':original['clearanceGrid']['lengthMetres'],
        'baselineManualContact':{a:d['manual_exclusion_contact']for a,d in original['manualWindowDiagnostics'].items()},
        'repairArms':rows,'unchangedLengthCapMetres':q['manualRepair']['lengthCapMetres'],
        'edgePruning':{k:q['edgeFilter'][k]for k in ('directedEdgesKept','directedEdgesRemoved','uniqueEdgeQueries')},
        'guardResources':{k:g[k]for k in ('aggregateCPUSeconds','wallSeconds','peakObservedAggregateRSS')},
        'currentCodeHashesEqualGuardInputs':before,'beforeAfterInputsEqual':True,
        'full3DBodyAndSupportValidated':False,'physicalAuthority':False,
        'scope':'Manual diagnostic windows only; saved GEOS records recounted, not fresh geometry checks',
        'containsCoordinatesOrRawPhotos':False}
    (H/'PUBLIC_SAFE_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()

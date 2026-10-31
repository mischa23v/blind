"""Recount saved JSON records only; no search/geometry/native imports or archive."""
import gzip
import hashlib
import json
import math
import pathlib

H = pathlib.Path(__file__).resolve().parent
R = H.parents[1]
W = R.parent
SOURCE = '1882514d76452b15107bb61ca192533052dd64ed'


def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def length(points): return sum(math.dist(a,b) for a,b in zip(points,points[1:]))


def main():
    proposal = W/'coffee-clearance-comparison-attempt-003/comparison/PROPOSALS.json'
    guard = W/'coffee-clearance-comparison-attempt-003/GUARD_RUN/RESULT.json'
    previous = R/'research/clearance-first-coffee-repair-result-20261029/PROPOSALS.json.gz'
    windows_file = R/'research/independent-2d-route-validator-20261029/actual-coffee-0-to-8-attempt002/INPUT_FREEZE.json'
    preflight = W/'coordination/joint-preflight-001/RESULT.json'
    d = json.loads(proposal.read_text()); g = json.loads(guard.read_text())
    old_bytes = gzip.decompress(previous.read_bytes()); old = json.loads(old_bytes)
    q = d['paths'][0]; before = old['paths'][0]
    windows = set(json.loads(windows_file.read_text())['windows'])
    assert g['sourceCommit'] == SOURCE and g['status']=='completed-zero-exit'
    assert len(d['paths'])==1 and d['newlyComparedPairs']==[[0,8]] and (q['start'],q['goal'])==(0,8)
    assert all(c['exitCode']==0 and c['groupRetired'] is True for c in g['commands'])
    assert [c['label'] for c in g['commands']]==['controls','comparison']
    assert hashlib.sha256(old_bytes).hexdigest()==d['previousRepairSHA256']
    assert q['baselineArmsUnchanged']==before['baselineArmsUnchanged']
    assert q['previousManualRepairArmsUnchanged']==before['manualRepair']
    assert d['associations']==old['associations']
    assert d['bodyWidthDepthHeightMetres']==[.45,.30,1.60] and d['horizontalMarginMetres']==.15
    assert d['physicalAuthority'] is False and q['full3DBodyAndSupportValidated'] is False
    assert q['edgeFilter']==before['edgeFilter']
    assert q['manualRepair']['lengthCapMetres']==before['manualRepair']['lengthCapMetres']==q['baselineArmsUnchanged']['lengthCapMetres']
    inventory = g['finalPayloadInventory']['comparison/PROPOSALS.json']
    assert inventory['sha256']==sha(proposal) and inventory['bytes']==proposal.stat().st_size
    assert g['inputHashesBefore']==g['inputHashesAfter']==g['pins']['inputs']
    verified = {}
    for name,expected in g['inputHashesBefore'].items():
        path = pathlib.Path(name.replace('@WORKSPACE@',str(W)))
        if not path.is_absolute(): path = R/path
        verified[name] = sha(path)==expected
    assert all(verified.values())
    source_manifest = R/'research/clearance-first-joint-cost-source-20261029/SOURCE_PINS.json'
    assert sha(source_manifest)==g['manifestSHA256']
    controls = json.loads((guard.parent/'controls.stdout').read_text())
    assert controls['status']=='passed' and controls['count']==35
    radius = q['edgeFilter']['bodyCircumscribedRadiusPlusMarginMetres']
    guard_metres = q['edgeFilter']['numericalGuardMetres']
    baseline = q['baselineArmsUnchanged']
    def arm_record(arm):
        chain = arm['requestedConnectorChainXYZ']; diag = arm['independentManualWindowDiagnostic']
        assert chain[0]==baseline['requestedStartXYZ'] and chain[-1]==baseline['requestedGoalXYZ']
        assert chain[1:-1]==arm['pointsXYZ']
        assert arm['pointsXYZ'][0]==baseline['clearanceGrid']['pointsXYZ'][0]
        assert arm['pointsXYZ'][-1]==baseline['clearanceGrid']['pointsXYZ'][-1]
        assert abs(length(arm['pointsXYZ'])-arm['lengthMetres'])<1e-10
        assert arm['lengthMetres']<=q['manualRepair']['lengthCapMetres']
        assert len(diag['segments'])==len(chain)-1 and diag['manual_exclusion_contact'] is False
        assert diag['physical_clearance']=='unknown' and diag['live_guidance_allowed'] is False
        per_window = {name:[] for name in windows}
        for index,segment in enumerate(diag['segments']):
            assert segment['index_zero_based']==index
            assert len(segment['windows'])==len(windows) and {w['id'] for w in segment['windows']}==windows
            for row in segment['windows']:
                assert row['body_margin_contact'] is False and row['distance_metres']>radius+guard_metres
                assert abs(row['clearance_after_body_and_margin_metres']-(row['distance_metres']-radius))<1e-12
                per_window[row['id']].append((row['distance_metres']-radius,index))
        rows = {name:{'minimumResidualBeyondBodyCircleAndMarginMetres':min(values)[0],
                      'segmentsChecked':len(values),
                      'minimumSegmentIndices':[i for value,i in values if value==min(values)[0]]}
                for name,values in sorted(per_window.items())}
        minimum = min(v['minimumResidualBeyondBodyCircleAndMarginMetres'] for v in rows.values())
        return {'nativeGridLengthMetres':arm['lengthMetres'],
                'connectorInclusiveLengthMetres':length(chain),
                'minimumSavedDistanceToManualWindowsMetres':minimum+radius,
                'minimumSavedResidualBeyondBodyCircleAndMarginMetres':minimum,
                'connectorInclusiveSegmentsChecked':len(chain)-1,
                'savedWindowChecks':sum(len(v) for v in per_window.values()),
                'allSavedSegmentsAndWindowsChecked':True,'manualWindowContact':False,
                'perWindow':rows,'sampledNativeWallProxy':arm['sampledWallDiagnostic']}
    records = {'previousCentered':arm_record(before['manualRepair']['clearanceGrid']),
               'unchangedRepairedShortest':arm_record(q['manualRepair']['distanceGrid']),
               'jointCentered':arm_record(q['manualRepair']['clearanceGrid'])}
    for field in ('nodeIDs','pointsXYZ','lengthMetres','requestedConnectorChainXYZ','independentManualWindowDiagnostic'):
        assert q['manualRepair']['distanceGrid'][field]==before['manualRepair']['distanceGrid'][field]
    a,b = records['previousCentered'],records['jointCentered']
    delta = b['nativeGridLengthMetres']-a['nativeGridLengthMetres']
    p = json.loads(preflight.read_text())
    assert p['sourceCommit']==SOURCE and p['nativeExecution'] is False
    result = {'status':'savedAttempt003IndependentlyRecountedNoNewNativeOrGeometryQueries',
        'sourceCommit':SOURCE,'sourceManifestSHA256':g['manifestSHA256'],
        'proposalSHA256':sha(proposal),'proposalBytes':proposal.stat().st_size,
        'guardSHA256':sha(guard),'previousProposalsGzipSHA256':sha(previous),
        'firstBaselineArmsExactlyPreserved':True,'previousRepairArmsExactlyPreserved':True,
        'shortestRepairGeometryAndDiagnosticsExactlyUnchanged':True,
        'requestedAndProjectedEndpointsExactlyPreserved':True,'associationsExactlyPreserved':True,
        'bodyWidthDepthHeightMetres':d['bodyWidthDepthHeightMetres'],'horizontalMarginMetres':.15,
        'bodyCirclePlusRadialMarginMetres':radius,'unchangedNativeGridLengthCapMetres':q['manualRepair']['lengthCapMetres'],
        'capScope':'native-grid length only, as before; requested connectors checked and reported separately',
        'arms':records,
        'changeFromPreviousCentered':{
            'nativeGridLengthAddedMetres':delta,'lengthIncreasePercent':100*delta/a['nativeGridLengthMetres'],
            'manualMinimumResidualAddedMetres':b['minimumSavedResidualBeyondBodyCircleAndMarginMetres']-a['minimumSavedResidualBeyondBodyCircleAndMarginMetres'],
            'sampledNativeWallP10ChangeMetres':b['sampledNativeWallProxy']['p10SampledResidualWallMetres']-a['sampledNativeWallProxy']['p10SampledResidualWallMetres'],
            'sampledNativeWallMinimumChangeMetres':b['sampledNativeWallProxy']['minimumSampledResidualWallMetres']-a['sampledNativeWallProxy']['minimumSampledResidualWallMetres']},
        'all40CurrentInputHashesMatchGuard':True,'beforeAfterInputHashesEqual':True,
        'controlsPassed':35,'bothCommandsZeroAndGroupsRetired':True,
        'guardResources':{name:g[name] for name in ('aggregateCPUSeconds','wallSeconds','peakObservedAggregateRSS')},
        'preservedPreflightFailure':{**p,'recordSHA256':sha(preflight)},
        'noArchivesCreatedOrUploaded':True,'containsCoordinatesOrRawPhotos':False,
        'physicalAuthority':False,'full3DBodyAndSupportValidated':False,
        'scope':'Manual diagnostic windows, not measured tables. Native eroded-navmesh boundary distance is a separate proxy. No live journey acceptance.'}
    (H/'PUBLIC_SAFE_RESULT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'status':result['status'],'arms':records,'change':result['changeFromPreviousCentered']},indent=2))


if __name__=='__main__': main()

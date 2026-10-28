#!/usr/bin/env python3
"""Offline-only exact report viewer, not a planner, controller or collision oracle.

CLI accepts only the existing bounded CI evidence JSON plus its expected hash.
It never calls xcode, network, the app, routing or physics. Tests are synthetic.
"""
import argparse
from collections import Counter
import hashlib
import importlib.util
import itertools
import json
import math
import os
from pathlib import Path
import re
import sys
import textwrap

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
LIMIT = 1024 * 1024
PIXELS_PER_METRE = 110
DPI = 100
MAX_SPAN_METRES = 25
LICENSE_SHA256 = 'ef80d1c2ac05c7040c0ced9d603c2c359712f90fdb3ece8da70b976981a69e89'
BASIS = 'Original saved world X right, Z up; Y omitted, in metres. No alignment between rooms.'
LIMITATIONS = [
    'Supplied test poses and historical modeled geometry; NOT live person localization.',
    'Get-up motion is NOT modeled: no seated-to-standing path is drawn.',
    'Candidate segments only; withheld, invalid, partial and unexecuted are NOT arrivals.',
    '2D projection is NOT 3D collision proof, full-footprint support or physical safety.',
    'Current doors, unseen obstacles, floor outside polygon and ceiling coverage are unknown.',
    'Walls: parametric surface projections, NOT the exported full-height triangle shells/cutouts.',
]


class ViewError(ValueError):
    pass


def need(test, code):
    if not test:
        raise ViewError(code)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


def module(path):
    spec = importlib.util.spec_from_file_location('route_evidence_for_view', path)
    obj = importlib.util.module_from_spec(spec)
    old = sys.dont_write_bytecode
    try:
        sys.dont_write_bytecode = True
        spec.loader.exec_module(obj)
    finally:
        sys.dont_write_bytecode = old
    return obj


def validator(repo=ROOT):
    return module(repo / 'tools/ci/native-route-diagnostic-evidence.py')


def read_bounded(path):
    need(path.is_file() and not path.is_symlink(), 'input_not_regular_file')
    need(0 < path.stat().st_size <= LIMIT, 'input_over_budget')
    return path.read_bytes()


def transform(point, matrix):
    """Original column-major affine 4x4, all three axes and translation once."""
    need(len(point) == 3 and len(matrix) == 16, 'invalid_transform')
    need(all(math.isfinite(x) for x in [*point, *matrix]), 'nonfinite_transform')
    need(matrix[3] == matrix[7] == matrix[11] == 0 and matrix[15] == 1, 'non_affine_transform')
    return [sum(matrix[c * 4 + r] * point[c] for c in range(3)) + matrix[12+r] for r in range(3)]


def projected(point):
    return [point[0], point[2]]


def corners(feature, box=False):
    if box:
        local = list(itertools.product(*[(-d / 2, d / 2) for d in feature['dimensions']]))
    else:
        local = feature.get('polygonCorners') or [
            [-feature['dimensions'][0]/2, -feature['dimensions'][1]/2, 0],
            [feature['dimensions'][0]/2, -feature['dimensions'][1]/2, 0],
            [feature['dimensions'][0]/2, feature['dimensions'][1]/2, 0],
            [-feature['dimensions'][0]/2, feature['dimensions'][1]/2, 0],
        ]
    return [transform(p, feature['transform']) for p in local]


def hull(points):
    """Convex silhouette of ORIGINAL box's eight projected corners, not floor."""
    pts = sorted(set(tuple(p) for p in points))
    def cross(a, b, c):
        return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    sides = []
    for seq in (pts, reversed(pts)):
        out = []
        for p in seq:
            while len(out)>1 and cross(out[-2],out[-1],p)<=0:
                out.pop()
            out.append(p)
        sides.append(out[:-1])
    return sides[0]+sides[1]


def scene(room):
    out = []
    for kind in ('floors', 'walls', 'doors', 'windows', 'openings', 'objects'):
        for f in room[kind]:
            xyz = corners(f, box=kind == 'objects')
            xy = [projected(p) for p in xyz]
            # Never convexify floors: original ordered concave boundary survives.
            out.append({'id': f['identifier'], 'kind': kind,
                        'category': next(iter(f['category'])),
                        'worldCorners': xyz,
                        'topDown': hull(xy) if kind == 'objects' else xy,
                        'heightRangeY': [min(p[1] for p in xyz),max(p[1] for p in xyz)],
                        'historicalDoorOpen': f['category'].get('door',{}).get('isOpen'),
                        'parentIdentifier': f.get('parentIdentifier')})
    return out


def schedule_map(docs, label):
    if label == 'journey':
        plan = docs['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']
        return {(j['id'],s['id']):(j['room'],j,s,plan['profile']) for j in plan['journeys'] for s in j['stages']}
    base = docs['RoomRouteDiagnostic/PROTOCOL.json']
    profiles = docs['RoomRouteDiagnostic/PROFILE_28CM_ADDENDUM.json']['profiles'] if label == 'width28-addendum' else base['profiles']
    return {(p['id'],profile['id']):(p['room'],p,None,profile) for p in base['pairs'] for profile in profiles}


def identity(row, label):
    return (row['journey'],row['stage']) if label=='journey' else (row['pair'],row['profile'])


def audit_segments(row):
    """Check reported line identity, disclose missing edges, never bridge gaps.

Missing association edges in a report are an evidence limitation, not grounds to
invent a line. A line that contradicts its declared kind/route is rejected.
"""
    if 'routePoints' not in row:
        need(not row.get('segments'), 'segments_without_route')
        return []
    points = row['routePoints']
    expected = [('requested-start-to-projection',row['requestedStart'],row['projectedStart'])]
    if row['projectedStart'] != points[0]:
        expected.append(('projection-to-detour-start',row['projectedStart'],points[0]))
    expected.extend((f'detour-segment-{i}',points[i-1],points[i]) for i in range(1,len(points)))
    if row['nativeComplete']:
        if points[-1] != row['projectedGoal']:
            expected.append(('detour-end-to-projection',points[-1],row['projectedGoal']))
        expected.append(('projection-to-requested-goal',row['projectedGoal'],row['requestedGoal']))
    lookup = {k:(i,a,b) for i,(k,a,b) in enumerate(expected)}
    seen = set()
    previous = -1
    for s in row['segments']:
        need(s['kind'] in lookup and s['kind'] not in seen, 'unexpected_or_duplicate_segment')
        i,a,b = lookup[s['kind']]
        need(i>previous, 'segment_order_disagreement')
        need(s['from']==a and s['to']==b, 'segment_endpoint_disagreement')
        seen.add(s['kind']); previous=i
    gaps = [{'kind':k,'from':a,'to':b,'distanceMetres':math.dist(a,b),
             'meaning':'unreported connection; NOT drawn or collision-scored by this viewer'}
            for k,a,b in expected if k not in seen]
    for key,a,b in [('startProjectionMetres',row['requestedStart'],row['projectedStart']),
                    ('goalProjectionMetres',row['requestedGoal'],row['projectedGoal'])]:
        # Float32 distance computation in native producer; no coordinate changes.
        need(math.isclose(row[key],math.dist(a,b),rel_tol=2e-5,abs_tol=2e-6),'projection_distance_disagreement')
    need(row['bodyContact'] == (row['initialBodyContact'] or any(s['bodyContact'] for s in row['segments'])),
         'body_contact_aggregate_disagreement')
    need(row['marginContact'] == (row['initialMarginContact'] or any(s['marginContact'] for s in row['segments'])),
         'margin_contact_aggregate_disagreement')
    if 'scoredChainContinuous' in row:
        need(row['scoredChainContinuous'] is True and not gaps,'scored_chain_claim_disagreement')
        need(row.get('scoredChainIncludesRequestedGoal') is row['nativeComplete'],'scored_goal_chain_claim_disagreement')
        need(row.get('sourceFloorSupportAlongScoredChain')=='unverified-full-footprint','unexpected_floor_support_claim')
    return gaps


def audit_profile(row, profile):
    if 'rawRadius' not in row:
        return
    raw=math.hypot(profile['width'],profile['depth'])/2
    expected={'rawRadius':raw,'rawHeight':profile['height'],
              'effectiveRadius':raw+profile['margin'],'effectiveHeight':profile['height']+profile['margin']}
    for key,value in expected.items():
        need(math.isclose(row[key],value,rel_tol=2e-5,abs_tol=2e-6),'profile_dimension_disagreement')


def audit_replay(report, docs):
    """No cross-stage animation or manufactured movement; verify recorded replay."""
    byid = {identity(r,'journey'):r for r in report['outcomes']}
    for j in docs['RoomRouteDiagnostic/JOURNEY_ADDENDUM.json']['journeys']:
        previous = None
        for s in j['stages']:
            row = byid[(j['id'],s['id'])]
            if 'requestedStart' not in row:
                continue
            if previous is not None:
                need(row['requestedStart']==previous, 'journey_start_discontinuity')
            expected = row['requestedGoal'] if row['outcome']=='modeled-segment-candidate-no-contact' else row['requestedStart']
            need(row['replayPositionAfterStage']==expected, 'replay_outcome_disagreement')
            previous = row['replayPositionAfterStage']


def load_evidence(path, expected_sha256, repo=ROOT):
    raw = read_bounded(path)
    need(re.fullmatch('[0-9a-f]{64}',expected_sha256) is not None, 'invalid_expected_hash')
    need(digest(raw)==expected_sha256,'evidence_hash_mismatch')
    v = validator(repo)
    top = v.decode(raw)
    need(isinstance(top,dict) and isinstance(top.get('routeDiagnosticEvidence'),dict),'missing_ci_route_evidence')
    need(top.get('schema')==1 and top.get('source_verified') is True and top.get('complete') is True,'unverified_ci_source_or_cases')
    need(re.fullmatch('[0-9a-f]{40}',top.get('source_commit','')) is not None,'missing_source_commit')
    evidence = top['routeDiagnosticEvidence']
    need(evidence.get('schema')==1 and evidence.get('physicalAuthority') is False, 'invalid_evidence_header')
    docs, uuids, source_hashes = v.sources(repo)
    license_path=repo/'ios/BlindAssistTests/Fixtures/RoomPlanApple/APPLE-LICENSE.txt'
    need(digest(read_bounded(license_path))==LICENSE_SHA256,'source_license_hash_mismatch')
    supplied = evidence.get('sourceSHA256',{})
    need(isinstance(supplied,dict) and set(supplied)==set(source_hashes),'missing_or_unknown_source_hashes')
    for name,value in source_hashes.items():
        if '/Fixtures/' in name:
            need(supplied.get(name)==value,'evidence_source_hash_mismatch')
    need(all(isinstance(k,str) and re.fullmatch('[0-9a-f]{64}',val or '') for k,val in supplied.items()),'invalid_source_hashes')
    records = evidence.get('reports')
    need(isinstance(records,list) and len(records)==3,'missing_report_inventory')
    reports, inventory, seen = [],[],set()
    specs = {name:(test,label) for test,name,label in v.SPECS}
    for record in records:
        name = record.get('attachmentName')
        need(name in specs and name not in seen,'unknown_or_duplicate_report')
        seen.add(name)
        test,label = specs[name]
        need(v.canonical(record.get('testIdentifier'))==test,'test_identifier_mismatch')
        item = {'attachmentName':name,'label':label,'collectionStatus':'collected' if record.get('status')=='collected' else 'not_collected'}
        if record.get('status')!='collected':
            # Do not copy arbitrary free-form collector errors.
            item['note']='report not collected; no outcomes or paths inferred'
            inventory.append(item); continue
        need(record.get('testResult') in ('Passed','Failed','Skipped','Expected Failure'),'missing_test_result')
        need(type(record.get('bytes')) is int and 0<record['bytes']<=LIMIT,'invalid_report_bytes')
        need(re.fullmatch('[0-9a-f]{64}',record.get('sha256','')) is not None,'invalid_attachment_hash')
        report = v.validate_report(record.get('report'),label,docs,uuids)
        for row in report['outcomes']:
            audit_segments(row)
            audit_profile(row,schedule_map(docs,label)[identity(row,label)][3])
        if label=='journey': audit_replay(report,docs)
        item.update(testResult=record['testResult'],reportErrors=report['errors'],
                    outcomeCounts=dict(sorted(Counter(row['outcome'] for row in report['outcomes']).items())),
                    originalAttachmentSHA256=record['sha256'],
                    originalAttachmentBytes=record['bytes'],
                    canonicalReportSHA256=digest(json.dumps(report,sort_keys=True,separators=(',',':')).encode()))
        inventory.append(item); reports.append((label,report,item))
    need(reports,'no_collected_reports')
    return docs,reports,{'inputEvidenceSHA256':expected_sha256,'sourceCommit':top['source_commit'],
                         'producerSourceSHA256':supplied,'localValidationSourceSHA256':source_hashes,
                         'producerCodeHashDifferences':[name for name in source_hashes if supplied[name]!=source_hashes[name]],
                         'reportInventory':inventory,'sourceLicenseSHA256':LICENSE_SHA256,
                         'attachmentHashMeaning':'Original attachment digest retained from CI; original raw bytes are not present to independently rehash. Input evidence bytes and canonical parsed report are independently hashed.'}


def bounds(features, rows):
    pts = [p for f in features for p in f['topDown']]
    for row in rows:
        for name in ('requestedStart','requestedGoal','projectedStart','projectedGoal','originalSuppliedStandingPoint'):
            if name in row: pts.append(projected(row[name]))
        pts.extend(projected(p) for p in row.get('routePoints',[]))
    low = [min(p[i] for p in pts)-.5 for i in (0,1)]
    high = [max(p[i] for p in pts)+.5 for i in (0,1)]
    need(all(0<high[i]-low[i]<=MAX_SPAN_METRES for i in (0,1)),'plot_extent_over_budget')
    return [low[0],high[0],low[1],high[1]]


def point_text(p):
    return '('+', '.join(format(n,'.8g') for n in p)+')'


def draw_one(row,label,room,features,domain,profile,output,synthetic=False):
    # Agg and preinstalled matplotlib only; no installation or network fallback.
    os.environ.setdefault('MPLCONFIGDIR','/tmp/blind-route-view-matplotlib')
    os.environ.setdefault('XDG_CACHE_HOME','/tmp/blind-route-view-cache')
    Path(os.environ['XDG_CACHE_HOME']).mkdir(parents=True,exist_ok=True)
    import matplotlib
    matplotlib.use('Agg')
    from matplotlib import pyplot as plt
    from matplotlib.patches import Polygon
    from matplotlib.lines import Line2D
    plt.rcParams.update({'font.family':'DejaVu Sans','svg.fonttype':'none','font.size':10,'svg.hashsalt':'blind-route-view-v1'})
    gaps = audit_segments(row)
    spanx,spany = domain[1]-domain[0],domain[3]-domain[2]
    mapw,maph = spanx*PIXELS_PER_METRE,spany*PIXELS_PER_METRE
    panelw=610; header=110; footer=210; left=80; right=32
    bodyh=max(maph+60,660)
    width=left+mapw+panelw+right; height=header+bodyh+footer
    fig=plt.figure(figsize=(width/DPI,height/DPI),dpi=DPI,facecolor='white')
    ax=fig.add_axes([left/width,(footer+(bodyh-maph)/2)/height,mapw/width,maph/height])
    ax.set_xlim(domain[:2]); ax.set_ylim(domain[2:]); ax.set_aspect('equal',adjustable='box')
    ax.set_xlabel('Original saved world X (metres)'); ax.set_ylabel('Original saved world Z (metres)')
    ax.grid(True,color='#e6e8ed',linewidth=.6); ax.set_axisbelow(True)
    labels={}
    counts={}
    contact_ids=set(row.get('obstacleSurfaceIDs',[]))|set(row.get('furnitureBoundIDs',[]))|set(row.get('initialFurnitureBoundIDs',[]))
    for f in features:
        k=f['kind']; counts[k]=counts.get(k,0)+1
        ident=(f['category'] if k=='objects' else {'floors':'F','walls':'W','doors':'D','windows':'WIN','openings':'O'}[k]+str(counts[k]))
        labels[f['id']]=ident
        xy=f['topDown']; color='#616a77'; fill='none'; lw=1; ls='-'
        if k=='floors': fill='#f1f5f8'; color='#9aa6b3'; lw=1.3
        elif k=='objects': fill='#dde0e8'; color='#667085'
        elif k=='doors': color='#006e50' if f['historicalDoorOpen'] else '#9b334d'; lw=3; ls='--' if f['historicalDoorOpen'] else '-'
        elif k in ('windows','openings'): color='#4c8da8'; ls=':'
        if f['id'] in contact_ids: color='#b31524'; lw=max(lw,2)
        patch=Polygon(xy,closed=True,facecolor=fill,edgecolor=color,linewidth=lw,linestyle=ls,zorder=1 if k=='floors' else 2)
        patch.set_gid('feature-'+f['id']); ax.add_patch(patch)
        if k in ('objects','doors'):
            center=projected([sum(p[i] for p in f['worldCorners'])/len(f['worldCorners']) for i in range(3)])
            ax.annotate(ident,center,xytext=(4,7),textcoords='offset points',fontsize=9,color='#26313f',
                        bbox={'facecolor':'white','edgecolor':'none','alpha':.75,'pad':1},zorder=4)
    for i,s in enumerate(row.get('segments',[])):
        a,b=projected(s['from']),projected(s['to'])
        contact=s['bodyContact'] or s['marginContact']
        connector=not s['kind'].startswith('detour-segment-')
        color='#b31524' if contact else '#8b4f00' if connector else '#1559a5'
        line,=ax.plot([a[0],b[0]],[a[1],b[1]],color=color,lw=2.3,ls='--' if connector else '-',zorder=5)
        line.set_gid('reported-segment-'+str(i))
    if row.get('routePoints'):
        pts=[projected(p) for p in row['routePoints']]
        ax.scatter([p[0] for p in pts],[p[1] for p in pts],s=13,c='#1559a5',zorder=6)
    marks=[('originalSuppliedStandingPoint','s','#7b4da3','S0'),('requestedStart','o','#142f4d','A'),
           ('requestedGoal','*','#142f4d','B'),('projectedStart','+','#bc6200','PA'),('projectedGoal','x','#bc6200','PB')]
    for key,marker,color,short in marks:
        if key not in row: continue
        p=projected(row[key]); size=80 if key=='requestedGoal' else 54
        if key=='requestedStart' and (row.get('initialBodyContact') or row.get('initialMarginContact')):
            marker='X'; color='#b31524'; size=100
        # Offset labels ONLY, never coordinates or overlapping point markers.
        ax.scatter([p[0]],[p[1]],s=size,marker=marker,c=color,zorder=7)
        offsets={'S0':(-24,-22),'A':(-18,12),'B':(10,12),'PA':(10,-14),'PB':(12,-25)}
        ax.annotate(short,p,xytext=offsets[short],textcoords='offset points',fontsize=10,fontweight='bold',color=color,zorder=8)
    identity_text=' / '.join(identity(row,label))
    title='SYNTHETIC RENDERER CHECK - NOT A NATIVE RESULT' if synthetic else 'Apple historical model - reported candidate only'
    fig.text(30/width,1-30/height,title,fontsize=15,fontweight='bold',color='#8b1622' if synthetic else '#162a41',va='top')
    fig.text(30/width,1-58/height,room+' | '+label,fontsize=11,va='top')
    fig.text(30/width,1-79/height,identity_text,fontsize=9,va='top')
    panelx=(left+mapw+38)/width
    lines=[('OUTCOME: '+row['outcome']).upper(),'Not a person arrival or physical-guidance result.','']
    if 'requestedStart' not in row:
        lines+=['No executed pose/path is in this row.','No route or protocol goal has been invented.']
    else:
        lines+=['A: requested start   B: requested goal','PA/PB: native projected endpoints (not teleports)',
                'A  '+point_text(row['requestedStart']),'B  '+point_text(row['requestedGoal'])]
        if 'originalSuppliedStandingPoint' in row:
            lines+=['S0: supplied post-rise standing pose (not observed)',
                    'Seated feature: '+labels.get(row.get('seatedFeatureID'),'none')+' (supplied context)',
                    'No get-up transition has been measured/drawn.']
        if 'projectedStart' in row:
            lines+=['PA '+point_text(row['projectedStart']),'PB '+point_text(row['projectedGoal']),
                    f"Projection displacement A: {row['startProjectionMetres']:.6g} m; B: {row['goalProjectionMetres']:.6g} m",
                    'Native complete: '+str(row['nativeComplete'])+' (projected goal only)']
        lines+=['','Declared cylinder inputs: w='+str(profile['width'])+' d='+str(profile['depth'])+' h='+str(profile['height'])+' m',
                'Declared margin: '+str(profile['margin'])+' m (not source inflation)',
                'Initial contact: body='+str(row['initialBodyContact'])+'; margin='+str(row['initialMarginContact'])]
        if 'initialFurnitureBoundIDs' in row:
            lines+=['Initial bound IDs: '+(', '.join(labels.get(x,x) for x in row['initialFurnitureBoundIDs']) or 'none reported')]
        if 'bodyContact' in row:
            lines+=['Candidate contact: body='+str(row['bodyContact'])+'; margin='+str(row['marginContact']),
                    'Segments: '+str(len(row['segments']))+'; missing connections: '+str(len(gaps)),
                    'Reported contacts identify segments/features, NOT impact points.',
                    'Floor contacts: '+(', '.join(labels.get(x,x) for x in row['floorContactIDs']) or 'none reported'),
                    'Obstacle/bound IDs: '+(', '.join(labels.get(x,x) for x in sorted(contact_ids)) or 'none reported')]
        else: lines+=['Native query: '+row.get('nativeError','no result')+'; no path drawn.']
        if 'scoredChainContinuous' in row:
            lines+=['Reported scored chain continuous: '+str(row['scoredChainContinuous']),
                    'Requested-goal connector included: '+str(row['scoredChainIncludesRequestedGoal']),
                    'Full-footprint support along chain: UNVERIFIED']
        if 'guidanceDelivered' in row:
            lines+=['Guidance receipts: '+str(len(row.get('productionGuidanceReceipts',[])))+' (test sink; not speech)']
    doors=[labels[f['id']]+(' OPEN' if f['historicalDoorOpen'] else ' CLOSED') for f in features if f['kind']=='doors']
    lines+=['','Historical doors: '+', '.join(doors),'Current door state is UNKNOWN.']
    if gaps: lines+=['','WARNING: unreported connector(s) left as gaps.','See receipt; no interpolation or invented collision result.']
    wrapped=[]
    for line in lines: wrapped.extend(textwrap.wrap(line,76) or [''])
    need(len(wrapped)<=43,'detail_panel_over_budget')
    detail_text=fig.text(panelx,1-header/height,'\n'.join(wrapped),fontsize=9,linespacing=1.4,va='top',family='DejaVu Sans Mono',color='#26313f')
    handles=[Line2D([0],[0],color='#1559a5',lw=2,label='Reported Detour segment'),
             Line2D([0],[0],color='#8b4f00',lw=2,ls='--',label='Reported projection connector'),
             Line2D([0],[0],color='#b31524',lw=2,label='Reported contact (segment, not impact point)')]
    fig.legend(handles=handles,loc='lower left',bbox_to_anchor=(24/width,165/height),ncol=1,frameon=False,fontsize=9)
    footer_text=fig.text(30/width,140/height,'\n'.join([BASIS,*LIMITATIONS]),fontsize=9,linespacing=1.45,va='top',color='#344054')
    fig.canvas.draw()
    need(detail_text.get_window_extent(fig.canvas.get_renderer()).y0>=footer,'detail_panel_overflow')
    need(footer_text.get_window_extent(fig.canvas.get_renderer()).y0>=8,'footer_overflow')
    # Assert display units remain uniform across axes/images; never tight_layout/fit.
    origin=ax.transData.transform((domain[0],domain[2])); px=ax.transData.transform((domain[0]+1,domain[2])); pz=ax.transData.transform((domain[0],domain[2]+1))
    need(abs(px[0]-origin[0]-PIXELS_PER_METRE)<1e-6 and abs(pz[1]-origin[1]-PIXELS_PER_METRE)<1e-6,'display_scale_disagreement')
    for ext in ('svg','png'):
        fig.savefig(output.with_suffix('.'+ext),dpi=DPI,metadata={'Description':title} if ext=='svg' else None)
    plt.close(fig)
    # Lossless values and true height spans are retained in machine-readable output.
    receipt={'schema':1,'syntheticRendererFixture':synthetic,'physicalAuthority':False,
             'cameraLocalizationTested':False,'getUpKinematicsTested':False,'twoDimensionalOnly':True,
             'fullFootprintSupportVerified':False,'sourceGeometryExpanded':False,'pathsInterpolated':False,
             'newConnectorSegmentsInvented':False,
             'room':room,'schedule':label,'identity':list(identity(row,label)),'profile':profile,
             'pixelsPerMetre':PIXELS_PER_METRE,'projection':BASIS,'domainXZ':domain,
             'gapsNotDrawn':gaps,'originalFeatureGeometry':features,'reportedOutcome':row,
             'contactLocationMeaning':'No impact coordinates exist in this schema. Color marks the entire reported contacting segment or feature only.',
             'wallProjectionMeaning':'Original parametric surface projections with separate door/window overlays; NOT an exported triangle-shell rendering or full-height aperture model.',
             'limitations':LIMITATIONS}
    return receipt


def run(evidence, expected_hash, destination, repo=ROOT):
    docs,reports,meta=load_evidence(evidence,expected_hash,repo)
    need(not destination.exists(),'output_already_exists')
    scenes={name:scene(docs[f'RoomPlanApple/{name}.capturedRoom.json']) for name in ('Bedroom3','Hallway2')}
    rows_by_room={r:[] for r in scenes}; jobs=[]
    for label,report,entry in reports:
        schedule=schedule_map(docs,label)
        for row in report['outcomes']:
            room,_,_,profile=schedule[identity(row,label)]
            rows_by_room[room].append(row); jobs.append((row,label,room,profile,entry))
    domains={r:bounds(scenes[r],rows_by_room[r]) for r in scenes}
    destination.mkdir(parents=True)
    manifest={'schema':1,'physicalAuthority':False,'status':'rendering','metadata':meta,
              'rendererSHA256':digest(Path(__file__).read_bytes()),'pixelsPerMetre':PIXELS_PER_METRE,
              'originalRoomFramesNeverJoined':True,'limitations':LIMITATIONS,'outputs':[]}
    # A failed render never leaves a success receipt; no automatic overwrite/retry.
    try:
        license_raw=read_bounded(repo/'ios/BlindAssistTests/Fixtures/RoomPlanApple/APPLE-LICENSE.txt')
        need(digest(license_raw)==LICENSE_SHA256,'source_license_hash_mismatch')
        (destination/'APPLE-LICENSE.txt').write_bytes(license_raw)
        manifest['outputs'].append({'file':'APPLE-LICENSE.txt','bytes':len(license_raw),'sha256':LICENSE_SHA256})
        for index,(row,label,room,profile,entry) in enumerate(jobs,1):
            name=f'{index:02d}-{label}-'+ '-'.join(identity(row,label))
            stem=destination/name
            receipt=draw_one(row,label,room,scenes[room],domains[room],profile,stem)
            receipt.update(inputEvidenceSHA256=expected_hash,reportProvenance=entry)
            receipt_path=stem.with_suffix('.receipt.json')
            receipt_path.write_text(json.dumps(receipt,indent=2,allow_nan=False)+'\n')
            for path in (stem.with_suffix('.svg'),stem.with_suffix('.png'),receipt_path):
                manifest['outputs'].append({'file':path.name,'bytes':path.stat().st_size,'sha256':digest(path.read_bytes())})
        manifest['status']='complete'
    except Exception:
        manifest['status']='incomplete_render_error'
        raise
    finally:
        (destination/'RENDER_RECEIPT.json').write_text(json.dumps(manifest,indent=2,allow_nan=False)+'\n')
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence',type=Path,required=True,help='existing native-hosted-case-statuses.json, not xcresult/private files')
    parser.add_argument('--expected-evidence-sha256',required=True)
    parser.add_argument('--output',type=Path,required=True,help='new directory; existing paths rejected')
    args=parser.parse_args()
    try:
        value=run(args.evidence,args.expected_evidence_sha256,args.output)
        print(json.dumps({'status':value['status'],'outputFiles':len(value['outputs']),'physicalAuthority':False}))
    except (ValueError,OSError,KeyError,TypeError,RecursionError,ImportError):
        print('Renderer refused input or could not complete; no successful render claimed.',file=sys.stderr)
        return 1
    return 0


if __name__=='__main__':
    raise SystemExit(main())

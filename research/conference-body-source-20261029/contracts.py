"""Stdlib-only frozen route selection and receipt contract; no geometry solver."""
import hashlib, json, math
from schedule_source import make_schedule

NAMES=['table_92_to_120','table_120_to_200','table_200_to_220',
       'table_220_to_20','table_20_to_92','varpu_130_to_160','varpu_160_to_130']
PROPOSAL_SHA='0f50fbbd52df3fa4369c0784579a93a2461b6c765b052acb2daf51d15f5f290f'
MESH_SHA='79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1'
VERTEX_SHA='50557edee3f4f0b1432c21206f1cc4f3b4c1133f0c0e754db70268eca7c250eb'
TRIANGLE_SHA='2c5cb77f5548e12c2bcf59680b459389a097567cec0079f30526481d6e9b9324'

def encoded(value):
    return (json.dumps(value,separators=(',',':'),allow_nan=False)+'\n').encode()

def select_routes(proposals):
    if [p['name'] for p in proposals['paths']]!=NAMES:
        raise ValueError('all seven ordered source requests must be retained')
    rows=[]
    for row in proposals['paths']:
        selected=row.get('gridSelection',{}).get('clearanceGrid')
        base={k:row[k] for k in ('name','requestedStartXYZ','requestedGoalXYZ','sourcePoseIndices')}
        if selected is None:
            rows.append({**base,'status':'unavailable','sourceGridStatus':row['gridStatus'],
                         'chain':None,'eventCount':0});continue
        chain=selected['requestedConnectorChainXYZ']
        if chain!=[row['requestedStartXYZ']]+selected['pointsXYZ']+[row['requestedGoalXYZ']]:
            raise ValueError('requested connectors changed')
        schedule=make_schedule(chain)
        rows.append({**base,'status':'frozenAuthoredProposalNotBodyPose',
                     'sourceGridStatus':row['gridStatus'],'chain':chain,
                     'chainSHA256':hashlib.sha256(encoded(chain)).hexdigest(),
                     'eventCount':len(schedule['events']),
                     'scheduleSHA256':hashlib.sha256(encoded(schedule)).hexdigest(),
                     'lengthMetres':sum(math.dist(a,b) for a,b in zip(chain,chain[1:])),
                     'eventCounts':{kind:sum(e['kind']==kind for e in schedule['events'])
                                    for kind in ('initial','turn','translate','stationary','terminal')}})
    return {'status':'SOURCE_ONLY_NOT_BODY_EXECUTED','proposalSHA256':PROPOSAL_SHA,
            'selection':'clearanceGrid.requestedConnectorChainXYZ; no easier-arm fallback',
            'routeCount':7,'totalEvents':sum(r['eventCount'] for r in rows),
            'allSevenRequestsRetained':True,'paths':rows}

def check_schedule(row):
    schedule=make_schedule(row['chain'])
    if len(schedule['events'])!=row['eventCount'] or hashlib.sha256(encoded(schedule)).hexdigest()!=row['scheduleSHA256']:
        raise ValueError('authored schedule reproduction mismatch')
    return schedule

def validate_receipt(actual, frozen):
    if actual['status']!='rawDiagnosticCompleted' or actual['error'] is not None:
        raise ValueError('incomplete raw comparison is not complete or clear')
    if actual['proposalSHA256']!=PROPOSAL_SHA or actual['sourceMeshSHA256']!=MESH_SHA:
        raise ValueError('source identity changed')
    if actual['registeredFloat32VerticesSHA256']!=VERTEX_SHA or actual['trianglesInt32SHA256']!=TRIANGLE_SHA:
        raise ValueError('registered frame bytes changed')
    if actual['bodyWidthDepthHeightMetres']!=[.45,.30,1.60] or actual['horizontalMarginMetres']!=.15 or actual['floorContactExclusionMetres']!=.002:
        raise ValueError('body or floor-preservation contract changed')
    if actual['groundExemptedFaceCount']!=0 or actual['counters']['rays']!=0:
        raise ValueError('unexpected ground exemption/support work')
    for key in ('physicalAuthority','continuousSupportProven','semanticFloorEstablished',
                'coverageEstablished','movementEpisode','arrivalClaimed','validatedCameraMeshAlignment'):
        if actual[key] is not False: raise ValueError('authority changed: '+key)
    if actual['registrationAuthority']!='historicalEstimatedComparatorOnlyNotOfficialCameraMeshCalibration':
        raise ValueError('registration provenance missing')
    if [r['name'] for r in actual['paths']]!=NAMES: raise ValueError('requests omitted/reordered')
    completed=0
    for row,source in zip(actual['paths'],frozen['paths']):
        if source['status']=='unavailable':
            if row['status']!='unavailable' or row['completedEvents']!=0:
                raise ValueError('unavailable source promoted')
        else:
            if row['status']!='rawDiagnosticComplete' or row['completedEvents']!=source['eventCount'] or row['scheduleSHA256']!=source['scheduleSHA256']:
                raise ValueError('schedule incomplete or changed')
            completed+=row['completedEvents']
    if actual['counters']['boxes']!=2*completed or completed!=frozen['totalEvents']:
        raise ValueError('nominal/margin query count mismatch')

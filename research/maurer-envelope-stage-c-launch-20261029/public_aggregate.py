"""Coordinate-free receipts derived from fixed native rows. No engine decisions."""
import hashlib,json,math,struct
from mac_guard import GuardFailure
PATH_DOMAIN=b'blind.ordered-float32-xyz-path.v1\0'
POINT_DOMAIN=b'blind.ordered-float32-xyz-points.v1\0'
SEGMENT_DOMAIN=b'blind.ordered-float32-xyz-segment-endpoints.v1\0'

def require(value,label):
    if not value:raise GuardFailure('aggregate: '+label)

def load_json(text):
    # JSON's integer-looking -0 is legal and can encode a negative Float32 zero.
    # Python's normal parse_int would erase its sign before the canonical digest.
    return json.loads(text,parse_int=lambda value:-0.0 if value=='-0' else int(value))

def f32(value):
    require(type(value) in (float,int) and math.isfinite(value),'finite numeric Float32 required')
    try:bits=struct.pack('<f',value)
    except (OverflowError,struct.error) as error:raise GuardFailure('aggregate: Float32 range') from error
    rounded=struct.unpack('<f',bits)[0]
    require(math.isfinite(rounded) and abs(rounded)<=10000,'coordinate/body range')
    return rounded,bits

def point(value):
    require(type(value) is list and len(value)==3,'XYZ triple required')
    return [f32(x)[0] for x in value]

def points_digest(points,domain=PATH_DOMAIN):
    require(type(points) is list and len(points)<=518,'bounded ordered points required')
    value=hashlib.sha256(domain+struct.pack('<I',len(points)))
    for p in points:
        require(type(p) is list and len(p)==3,'XYZ triple required')
        for x in p:value.update(f32(x)[1])
    return value.hexdigest()

def lengths(points):
    values=[point(p) for p in points]
    return (sum(math.dist(a,b) for a,b in zip(values,values[1:])),
            sum(math.hypot(b[0]-a[0],b[2]-a[2]) for a,b in zip(values,values[1:])))

def bool_or_absent(row,key):
    value=row.get(key);require(value is None or type(value) is bool,'boolean status '+key);return value

def contact_counts(segments):
    require(type(segments) is list and len(segments)<=259,'bounded segments required')
    for s in segments:
        require(type(s['bodyContact']) is bool and type(s['marginContact']) is bool,'segment contact booleans')
        for key in ['obstacleSurfaceIDs','furnitureBoundIDs','floorContactIDs']:
            require(type(s[key]) is list and len(s[key])<=4096 and all(type(x) is str for x in s[key]),'contact witnesses')
    return {'segmentCount':len(segments),'bodyContactSegmentCount':sum(s['bodyContact'] for s in segments),
      'marginContactSegmentCount':sum(s['marginContact'] for s in segments),
      'uniqueMarginObstacleSurfaceCount':len({x for s in segments for x in s['obstacleSurfaceIDs']}),
      'uniqueMarginFurnitureBoundCount':len({x for s in segments for x in s['furnitureBoundIDs']}),
      'uniqueFloorSurfaceCount':len({x for s in segments for x in s['floorContactIDs']})}

def candidate_receipts(data,requests,reference):
    require(data['schema']=='blind.public-fixed-seed-radius-envelope-navigation.v2','result schema')
    require(type(data['candidateRequests']) is int and data['candidateRequests'] in [0,25],'candidate count')
    rows=data['rows'];count=data['candidateRequests']
    require(type(rows) is list and len(rows)==50+count and len(requests['requests'])==25,'result inventory')
    refs={}
    for row in reference['rows']:
        key=(row['requestID'],row['endpointPolicy']);require(key not in refs,'duplicate reference identity');refs[key]=row
    receipts=[]
    for row,request in zip(rows[50:],requests['requests']):
        require(row['requestID']==request['id'] and row['fixtureSHA256']==request['fixtureSHA256'] and
          row['profile']==request['profile'] and row['configuration']=='stock-AND-exact-seed-radius-envelope-v2-strict-endpoints' and
          row['endpointPolicy']=='requireSuppliedXZOverPolygon' and row['physicalAuthority'] is False,'candidate identity')
        for key in ['rawRadius','effectiveRadius','effectiveHeight']:
            require(f32(row[key])[1]==f32(request[key])[1],'body identity')
        for key in ['requestedStart','requestedGoal']:
            require(points_digest([row[key]],POINT_DOMAIN)==points_digest([request[key]],POINT_DOMAIN),'supplied endpoint identity')
        points=row.get('routePoints');require(points is None or (type(points) is list and 1<=len(points)<=256),'path cardinality')
        path_hash=points_digest(points) if points is not None else None
        path_lengths=lengths(points) if points is not None else (None,None)
        segments=row.get('segments',[]);counts=contact_counts(segments)
        endpoints=[];complete_length=0.;complete_xz=0.
        for segment in segments:
            pair=[segment['from'],segment['to']];a,b=lengths(pair);complete_length+=a;complete_xz+=b;endpoints.extend(pair)
        native_status=row.get('nativeStatus')
        require(native_status is None or (type(native_status) is int and 0<=native_status<=0xffffffff),'native status')
        published={};matches={}
        for name,policy in [('legacy','legacyNearestProjection'),('strict','requireSuppliedXZOverPolygon')]:
            ref=refs[(request['id'],policy)];ref_points=ref.get('routePoints')
            published[name]=points_digest(ref_points) if ref_points is not None else None
            matches[name]=path_hash==published[name] if path_hash is not None and published[name] is not None else None
        receipts.append({'requestID':request['id'],'fixtureSHA256':request['fixtureSHA256'],'bodyProfileID':request['profile'],
          'bodyFloat32Bits':{k:struct.unpack('<I',f32(request[k])[1])[0] for k in ['rawRadius','rawHeight','effectiveRadius','effectiveHeight']},
          'requestedStartFloat32SHA256':points_digest([request['requestedStart']],POINT_DOMAIN),
          'requestedGoalFloat32SHA256':points_digest([request['requestedGoal']],POINT_DOMAIN),
          'projectedStartFloat32SHA256':points_digest([row['projectedStart']],POINT_DOMAIN) if 'projectedStart' in row else None,
          'projectedGoalFloat32SHA256':points_digest([row['projectedGoal']],POINT_DOMAIN) if 'projectedGoal' in row else None,
          'nativeStatus':native_status,'nativeSucceeded':bool_or_absent(row,'nativeSucceeded'),
          'nativeComplete':bool_or_absent(row,'nativeComplete'),'buildFailed':bool_or_absent(row,'buildFailed'),
          'endpointAdmissionRejected':bool_or_absent(row,'endpointAdmissionRejected'),
          'fullLayoutValidated':bool_or_absent(row,'fullLayoutValidated'),'routeQueryAttempted':bool_or_absent(row,'routeQueryAttempted'),
          'initialBodyContact':bool_or_absent(row,'initialBodyContact'),'initialMarginContact':bool_or_absent(row,'initialMarginContact'),
          'bodyContact':bool_or_absent(row,'bodyContact'),'marginContact':bool_or_absent(row,'marginContact'),
          'pathAvailable':points is not None,'pathPointCount':len(points) if points is not None else 0,
          'orderedPathFloat32SHA256':path_hash,'detourPathLength3DMetres':path_lengths[0],'detourPathLengthXZMetres':path_lengths[1],
          'connectorInclusiveSegmentLength3DMetres':complete_length if segments else None,
          'connectorInclusiveSegmentLengthXZMetres':complete_xz if segments else None,
          'orderedSegmentEndpointsFloat32SHA256':points_digest(endpoints,SEGMENT_DOMAIN) if segments else None,
          'routeContactCounts':counts,'initialContactCounts':contact_counts(row['initialContactReceipt']),
          'publishedReferencePathSHA256':published,'matchesPublishedReferencePath':matches})
    require(len(receipts)==count,'candidate receipts missing')
    return receipts

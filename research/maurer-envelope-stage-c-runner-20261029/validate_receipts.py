"""Strict export boundary for coordinate-free Stage C records."""
import math,re,hashlib,struct
INPUTS={'packedRoutingGeometry': '0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7', 'requests25': 'e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51', 'expectedMasksAndLayouts': '13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a', 'nativeReference50': '0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893'}
DIGEST=re.compile('[0-9a-f]{64}')
ENCODING='blind.ordered-float32-xyz-path.v1\\0 + UInt32LE point count + ordered XYZ IEEE754 Float32LE components; SHA256; negative zero preserved'
def require(x,why):
 if not x:raise ValueError(why)
def ishash(x):return type(x) is str and DIGEST.fullmatch(x) is not None
def validate(value, schema, requests):
 require(set(value['frozenInputSHA256'])=={'packedRoutingGeometry','requests25','expectedMasksAndLayouts','nativeReference50'},'input keys')
 require(value['frozenInputSHA256']==INPUTS,'exact input digests')
 if 'candidateReceipts' not in value:
  require('pathDigestEncoding' not in value,'encoding without receipts');return
 rows=value['candidateReceipts'];require(type(rows) is list and len(rows) in [0,25],'candidate count')
 require(value.get('pathDigestEncoding')==ENCODING,'digest encoding')
 require([r['requestID'] for r in rows]==[r['id'] for r in requests['requests']][:len(rows)],'request order')
 keys=set(schema['candidateExactKeysAndObservedTypeShapes'])
 booleans=['nativeSucceeded','nativeComplete','buildFailed','endpointAdmissionRejected','fullLayoutValidated','routeQueryAttempted','initialBodyContact','initialMarginContact','bodyContact','marginContact']
 for row,request in zip(rows,requests['requests']):
  require(type(row) is dict and set(row)==keys,'candidate keys')
  require(row['fixtureSHA256']==request['fixtureSHA256'] and row['bodyProfileID']==request['profile'],'candidate identity')
  for k in ['fixtureSHA256','requestedStartFloat32SHA256','requestedGoalFloat32SHA256']:require(ishash(row[k]),'required digest')
  for k in ['projectedStartFloat32SHA256','projectedGoalFloat32SHA256','orderedPathFloat32SHA256','orderedSegmentEndpointsFloat32SHA256']:require(row[k] is None or ishash(row[k]),'nullable digest')
  require(type(row['bodyFloat32Bits']) is dict and set(row['bodyFloat32Bits'])==set(schema['bodyFloat32BitsExactKeys']),'body keys')
  require(all(type(x) is int and 0<=x<=0xffffffff for x in row['bodyFloat32Bits'].values()),'body bits')
  require(row['bodyFloat32Bits']=={k:struct.unpack('<I',struct.pack('<f',request[k]))[0] for k in schema['bodyFloat32BitsExactKeys']},'exact body bits')
  for field,key in [('requestedStartFloat32SHA256','requestedStart'),('requestedGoalFloat32SHA256','requestedGoal')]:
   h=hashlib.sha256(b'blind.ordered-float32-xyz-points.v1\0'+struct.pack('<I',1)+b''.join(struct.pack('<f',v) for v in request[key])).hexdigest();require(row[field]==h,'exact requested-point digest')
  for k in booleans:require(row[k] is None or type(row[k]) is bool,'nullable native flag')
  require(row['nativeStatus'] is None or type(row['nativeStatus']) is int and 0<=row['nativeStatus']<=0xffffffff,'native status')
  require(type(row['pathAvailable']) is bool and type(row['pathPointCount']) is int and 0<=row['pathPointCount']<=256,'path count')
  require((row['pathPointCount']>0)==row['pathAvailable'] and (row['orderedPathFloat32SHA256'] is not None)==row['pathAvailable'],'path presence')
  for k in ['detourPathLength3DMetres','detourPathLengthXZMetres','connectorInclusiveSegmentLength3DMetres','connectorInclusiveSegmentLengthXZMetres']:require(row[k] is None or type(row[k]) in (int,float) and math.isfinite(row[k]) and row[k]>=0,'finite length')
  for k in ['routeContactCounts','initialContactCounts']:
   c=row[k];require(type(c) is dict and set(c)==set(schema['contactCountExactKeys']),'contact keys');require(all(type(x) is int and 0<=x<=259*4096 for x in c.values()),'bounded contact counts');require(c['segmentCount']<=259 and c['bodyContactSegmentCount']<=c['segmentCount'] and c['marginContactSegmentCount']<=c['segmentCount'],'segment counts')
  for k in ['publishedReferencePathSHA256','matchesPublishedReferencePath']:require(type(row[k]) is dict and set(row[k])=={'legacy','strict'},'reference keys')
  require(all(x is None or ishash(x) for x in row['publishedReferencePathSHA256'].values()),'reference digests');require(all(x is None or type(x) is bool for x in row['matchesPublishedReferencePath'].values()),'reference equality')

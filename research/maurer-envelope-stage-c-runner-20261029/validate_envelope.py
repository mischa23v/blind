"""Additional coordinate-free schema2 work receipts and exact actual003 parity gate.
Work units are envelope loop visits/comparisons, NOT schema1 seed tests.
Declared workspace bytes are accounting, NOT measured RSS.
"""
def require(ok,why):
 if not ok:raise ValueError(why)
KEYS={'requestID','requested','schema','algorithm','workUnit','status','width','height','spanCount','radiusCells','commonYVoxel','realSeedCount','exteriorSeedCount','stockKeep','exactKeep','additionalRejected','buildSucceeded','workLimit','workBound','workPerformed','paddedCells','workspaceBytesDeclared','physicalAuthority'}
def validate_envelope(value,requests,reference):
 require(reference['launcherExit']==0 and reference['aggregate']['status']=='passed-fixed-source-route-matrix','successful actual003 reference')
 expected=reference['aggregate']['candidateReceipts'];require(len(expected)==25,'actual003 count')
 parity=value['actual003CandidateReceiptsExactMatch'];require(type(parity) is bool,'parity boolean')
 if parity:require(value.get('candidateReceipts')==expected,'exact actual003 candidate receipt dictionaries')
 if value['status']=='passed-fixed-source-route-matrix':require(parity and len(value.get('envelopeWorkReceipts',[]))==25,'passing parity and work inventory')
 if 'envelopeWorkReceipts' not in value:return
 rows=value['envelopeWorkReceipts'];require(type(rows) is list and len(rows)==25,'work inventory')
 require([r.get('requestID') for r in rows]==[r['id'] for r in requests['requests']],'work request order')
 for r in rows:
  require(type(r) is dict and set(r)==KEYS,'work receipt keys')
  for k in ['requested','buildSucceeded','physicalAuthority']:require(type(r[k]) is bool,'work boolean')
  require(r['requested'] is True and r['physicalAuthority'] is False,'work scope')
  for k,v in [('schema',2),('algorithm',1),('workUnit',1)]:require(type(r[k]) is int and r[k]==v,'explicit envelope discriminator')
  require(type(r['status']) is int and r['status']==2,'typed status')
  require(type(r['commonYVoxel']) is int and 0<=r['commonYVoxel']<=65535,'common y voxel')
  for k in ['width','height','spanCount','radiusCells','realSeedCount','exteriorSeedCount','stockKeep','exactKeep','additionalRejected']:
   require(type(r[k]) is int and 0<=r[k]<=2147483647,'bounded C integer')
  for k in ['workLimit','workBound','workPerformed','paddedCells','workspaceBytesDeclared']:
   require(type(r[k]) is int and 0<=r[k]<=18446744073709551615,'bounded UInt64')
  require(1<=r['width']<=250000 and 1<=r['height']<=250000 and 1<=r['spanCount']<=65536 and 1<=r['radiusCells']<=80,'frozen layout bounds')
  require(r['spanCount']<=r['width']*r['height'],'single layer span bound')
  require(r['realSeedCount']<=r['spanCount'] and r['exteriorSeedCount']==2*(r['width']+r['height']+2),'seed counts')
  require(r['workLimit']==10000000 and r['workPerformed']<=r['workLimit'],'frozen work limit')
  if r['status']==2:
   n=(r['width']+2)*(r['height']+2)
   require(r['width']>0 and r['height']>0 and n==r['paddedCells']<=250000,'applied padded domain')
   require(r['workBound']==14*n and r['workPerformed']<=r['workBound']<=r['workLimit'],'applied14N work bound')
   require(r['workspaceBytesDeclared']==11*n+16*max(r['width']+2,r['height']+2)+r['spanCount']+448 and r['workspaceBytesDeclared']<=2097152,'declared workspace formula/budget')
   require(r['exactKeep']<=r['stockKeep']<=r['spanCount'] and r['additionalRejected']==r['stockKeep']-r['exactKeep'],'stock AND keep counts')
  if r['buildSucceeded']:require(r['status']==2,'build requires applied envelope')

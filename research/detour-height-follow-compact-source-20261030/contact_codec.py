"""Lossless JSON-dictionary defaults codec. No geometry arithmetic or ID filtering."""
import copy,json
DEFAULTS=[
 (['movementApplied'],False),(['physicalAuthority'],False),(['support'],'unknown'),(['semanticFloor'],'unknown'),(['nativeHeightUnavailableReason'],None),
 (['verticalShiftCoverage','endpointBandsOnlyNotContinuousSupport'],True),
 (['sweep','continuousMotionEnclosed'],True),(['sweep','conservativeEnclosureMayOvercount'],True),
 (['result','closedBoundaries'],True),(['result','closedSolidContainmentClassified'],False),(['result','measuredCoverageEstablished'],False),(['result','physicalClearanceEstablished'],False),(['result','physicalAuthority'],False),(['result','heightRangeIsWholeTriangleNotContactPoint'],True),(['result','groundContactCount'],0),(['result','groundContactEvent'],False),(['result','groundContactFaceIDsFirst16'],[]),(['result','groundContactFaceIDsTruncated'],False),(['result','completeCandidateContactCounts'],True),(['result','groundExemption'],'none; immutable empty set; no triangle suppressed'),(['result','lowHeightAloneExcluded'],False),(['result','groundComponentDoesNotEstablishSemanticFloor'],True),(['result','groundExemptions'],False),(['result','groundClassificationSemantic'],False)]
HEADER={'schema':'lossless-contact-defaults-v1','encoding':'[removedDefaultBitmask,remainingDictionary]','defaults':[{'path':p,'value':v}for p,v in DEFAULTS],'absentFieldsRemainAbsent':True,'coordinatesAndIDsUnchanged':True}
def canonical(x):return json.dumps(x,sort_keys=True,separators=(',',':'),allow_nan=False)
def encode_record(record):
 if not isinstance(record,dict):raise ValueError('dictionary record required')
 row=copy.deepcopy(record);mask=0
 for i,(path,value)in enumerate(DEFAULTS):
  parent=row
  for key in path[:-1]:
   if not isinstance(parent,dict)or key not in parent:parent=None;break
   parent=parent[key]
  if isinstance(parent,dict)and path[-1]in parent and canonical(parent[path[-1]])==canonical(value):
   del parent[path[-1]];mask|=1<<i
 return [mask,row]
def decode_record(packed,header):
 if header!=HEADER:raise ValueError('unsupported/default header changed')
 if not isinstance(packed,list)or len(packed)!=2 or type(packed[0])is not int or not 0<=packed[0]<1<<len(DEFAULTS)or not isinstance(packed[1],dict):raise ValueError('invalid encoded record')
 mask,row=packed[0],copy.deepcopy(packed[1])
 for i,(path,value)in enumerate(DEFAULTS):
  if not mask&(1<<i):continue
  parent=row
  for key in path[:-1]:
   if not isinstance(parent,dict)or key not in parent:raise ValueError('missing nested dictionary')
   parent=parent[key]
  if not isinstance(parent,dict)or path[-1]in parent:raise ValueError('default would overwrite field')
  parent[path[-1]]=copy.deepcopy(value)
 return row

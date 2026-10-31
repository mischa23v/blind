"""Stdlib frozen selection of all seven actual GEOS provisional chains."""
import hashlib,json,math
PAIRS_SHA='3b47960077f817b627b2868748204174020378832b50c3459c8bcdf35d73be47'
PAIR_SOURCE='dad87dcc75d86e3b170201e778ccef69c76ccca4'
NAMES=['table_92_to_120','table_120_to_200','table_200_to_220','table_220_to_20','table_20_to_92','varpu_130_to_160','varpu_160_to_130']
COUNTS=[796,1101,653,889,1740,1145,1146]
def require(ok,message):
    if not ok:raise ValueError(message)
def encoded(value):return (json.dumps(value,separators=(',',':'),allow_nan=False)+'\n').encode()
def select_simplified(pairs,baseline,make_schedule):
    require(pairs['status']=='pairedDiagnosticComplete' and pairs['error'] is None,'actual paired diagnostic incomplete')
    require([r['name']for r in pairs['paths']]==[r['name']for r in baseline['paths']]==NAMES,'all seven ordered requests required')
    for key in ('accepted','physicalAuthority','movementExecuted','bodyComparisonExecuted','validatedCameraMeshAlignment','independentCoverageEstablished'):
        require(pairs[key] is False,'provisional source authority changed: '+key)
    rows=[]
    for pair,old,count in zip(pairs['paths'],baseline['paths'],COUNTS):
        require(pair['unchangedCentered']['chainXYZ']==old['chain'],'baseline path identity changed')
        require(pair['sourcePoseIndices']==old['sourcePoseIndices'],'source pose association changed')
        c=pair['geos025CenteredCandidate'];chain=c['chainXYZ'];indices=c['retainedSourceGraphIndices']
        require(c['status']=='provisionalIndependentCoverageUnknown' and c['checks']['eligibleForLaterFullBodyDiagnostic'] is True and c['checks']['allNativeSegmentsPassBothDirections'] is True,'candidate not one of seven provisional corridor-eligible chains')
        require(c['accepted'] is False and c['physicalAuthority'] is False and c['checks']['accepted'] is False,'candidate acceptance is forbidden')
        graph=old['chain'][1:-1]
        require(isinstance(indices,list) and 2<=len(indices)<=1000 and all(type(i)is int and 0<=i<len(graph)for i in indices) and all(a<b for a,b in zip(indices,indices[1:])),'retained source index sequence')
        exact=[old['chain'][0]]+[graph[i]for i in indices]+[old['chain'][-1]]
        require(chain==exact and chain[:3]==old['chain'][:3] and chain[-3:]==old['chain'][-3:],'exact XYZ, endpoints, connectors or locked edges changed')
        schedule=make_schedule(chain);events=schedule['events']
        require(len(events)==count==c['metrics']['eventCount'],'actual candidate authored event count')
        length=sum(math.dist(a,b)for a,b in zip(chain,chain[1:]))
        require(math.isclose(length,c['metrics']['lengthMetres'],abs_tol=1e-10,rel_tol=0),'candidate length')
        rows.append({'name':pair['name'],'status':'frozenAuthoredProposalNotBodyPose','sourcePoseIndices':old['sourcePoseIndices'],
          'requestedStartXYZ':chain[0],'requestedGoalXYZ':chain[-1],'chain':chain,'eventCount':count,
          'chainSHA256':hashlib.sha256(encoded(chain)).hexdigest(),'scheduleSHA256':hashlib.sha256(encoded(schedule)).hexdigest(),
          'lengthMetres':length,'retainedSourceGraphIndices':indices,'sourceStatus':c['status'],
          'baselineEventCount':old['eventCount'],'baselineLengthMetres':old['lengthMetres']})
    require(sum(r['eventCount']for r in rows)==7470,'all candidate events required')
    return {'status':'SOURCE_ONLY_NOT_BODY_EXECUTED','pairsSHA256':PAIRS_SHA,'pairSourceCommit':PAIR_SOURCE,
      'selection':'all seven actual geos025CenteredCandidate.chainXYZ; no easiest subset or fallback',
      'routeCount':7,'totalEvents':7470,'allSevenRequestsRetained':True,'physicalAuthority':False,'paths':rows}

def compare_baseline(baseline,recording):
    """Descriptive different-trajectory counts/face sets, never a safety ratio."""
    require([r['name']for r in baseline['paths']]==[r['name']for r in recording['paths']]==NAMES,'comparison request set')
    rows=[]
    for old,new in zip(baseline['paths'],recording['paths']):
        arms={}
        for kind in ('actualBody','horizontalMargin'):
            a=old['arms'][kind];b=new['arms'][kind];left=set(a['uniqueIDs']);right=set(b['uniqueIDs'])
            arms[kind]={'baseline':a,'simplified':b,'sharedFaceIDs':sorted(left&right),
                        'addedFaceIDs':sorted(right-left),'removedFaceIDs':sorted(left-right)}
        rows.append({'name':old['name'],'baselineAuthoredEvents':old['authoredEvents'],
          'simplifiedAuthoredEvents':new['completedEvents'],'arms':arms})
    return {'status':'descriptiveDifferentTrajectoryComparison','paths':rows,'physicalAuthority':False,
      'safetyImprovementEstablished':False,'contactEventPercentagesCalculated':False,
      'interpretation':'Different trajectories and turn/event denominators. Counts, unique face-set changes and contact presence only; no safety ranking.'}

"""Merge worker results and tabulate the movement game per the frozen v3 reporting rules.
Categories are reported separately; contact triangles are split by height above the foot plane:
  <= 3 mm  : floor-mesh clipping of the world's fixed 2 mm floor gap (evaluator floor ambiguity)
  3 mm-3 cm: near-foot ambiguous (could be a low object or floor relief)
  > 3 cm   : obstacle contact (body or margin)
usage: game_analyse.py <room_dir> <label>"""
import sys,os,json,glob
from collections import Counter,defaultdict
d,label=sys.argv[1:3]
parts=sorted(glob.glob(os.path.join(d,'GAME_RESULTS*.json')))
res=[];meta=None
for p in parts:
    j=json.load(open(p));meta=meta or j;res+=j['results']
res=sorted({r['runID']:r for r in res}.values(),key=lambda r:r['runID'])
def cat(r):
    s=r['status']
    if s=='arrivalReferenceModelOnly':return 'cleanArrival'
    if s=='routeUnavailable':return 'routeUnavailable'
    if s.startswith('invalidStart'):return 'invalidStart'
    if s=='groundFollowMovementCap':return 'harnessStepCapConflict'
    if s=='unknownReferenceSupportDuringMotion':return 'referenceSupportUnconfirmed'
    if s in('firstContactTriangleNearFootAmbiguous','referenceMarginContact','referenceActualBodyContact'):
        h=max(r.get('firstContact',{}).get('firstTriangleHeightRelativeToStartFootRange') or [0])
        kind='body' if r.get('actualBodyContactEvents') else 'margin'
        if h<=.003:return f'{kind}Contact_floorClip<=3mm'
        if h<=.03:return f'{kind}Contact_nearFoot3mm-3cm'
        return f'{kind}Contact_obstacle>3cm'
    if s.startswith('stoppedNoMotion'):return 'stopped:'+s.split(':',1)[1]
    return s
C=Counter(cat(r) for r in res);byc=defaultdict(Counter)
for r in res:byc[r['condition']][cat(r)]+=1
arr=[r for r in res if cat(r)=='cleanArrival']
out=dict(label=label,episodesScheduled=len(res),categories=dict(C),byCondition={k:dict(v) for k,v in byc.items()},
    arrivals=[dict(runID=r['runID'],distance=r['actualDistanceMetres'],goalError=r['goalErrorMetres'],ticks=r['ticks']) for r in arr],
    movedEpisodes=sum(1 for r in res if r.get('motionExecuted')),meanDistanceOfMovedEpisodes=round(sum(r.get('actualDistanceMetres',0) for r in res if r.get('motionExecuted'))/max(1,sum(1 for r in res if r.get('motionExecuted'))),3),
    invalidStartReasons=dict(Counter(r['status'] for r in res if cat(r)=='invalidStart')),
    contactHeights_m=sorted(round(max(r['firstContact']['firstTriangleHeightRelativeToStartFootRange']),4) for r in res if r.get('firstContact')),
    mapSHA256=meta.get('mapSHA256'),routesSHA256=meta.get('routesSHA256'),worldModel=meta.get('worldModel'),controller=meta.get('controller'))
json.dump(dict(summary=out,results=res),open(os.path.join(d,'GAME_MERGED.json'),'w'),indent=1)
print(json.dumps(out,indent=1))

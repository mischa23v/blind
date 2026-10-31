"""Pure stdlib binding to unchanged authored routes. No native or geometry work."""
import hashlib,json,math,pathlib
from original_schedule import make_schedule
H=pathlib.Path(__file__).resolve().parent
XZ_TOLERANCE_METRES=1e-6  # Frozen Float32 numerical comparison, not physical safety.
BODY_FOOT_OFFSET_METRES=0.0  # Native detail Y is proposed foot datum; no lifting search.
EXPECTED_COUNTS={'conference':2052,'coffee':1644}
CONFERENCE='research/conference-body-source-20261029/ROUTES.json'
COFFEE='research/coffee-room-journey-recovery-20261029/collision-protocol/joint-route-body-candidate/SCHEDULE_0_8.json'
INPUT_SHA={CONFERENCE:'8c576659086d346cfd08cc63cbb40d416b962bc6b4ca45b4cd12a6c9d26dee1e',COFFEE:'19bc3032e46b7218e62c1481d54be9a978c3233cbf19c19d1400ba4234d44d40'}
def encoded(x):return (json.dumps(x,separators=(',',':'),allow_nan=False)+'\n').encode()
def load_schedules(repo):
 repo=pathlib.Path(repo)
 docs={}
 for name,digest in INPUT_SHA.items():
  data=(repo/name).read_bytes()
  if hashlib.sha256(data).hexdigest()!=digest:raise ValueError('Authored source changed: '+name)
  docs[name]=json.loads(data)
 conf=docs[CONFERENCE];selected=next(r for r in conf['paths']if r['name']=='table_120_to_200')
 c=make_schedule(selected['chain'])
 if hashlib.sha256(encoded(c)).hexdigest()!=selected['scheduleSHA256']:raise ValueError('Original Conference schedule differs')
 coffee=docs[COFFEE]['paths']
 if len(coffee)!=1 or(coffee[0]['start'],coffee[0]['goal'])!=(0,8):raise ValueError('Original Coffee selection changed')
 q=coffee[0];reproduced=make_schedule(q['chain'])
 if any(reproduced[k]!=q[k]for k in ('chain','initialYaw','events')):raise ValueError('Original Coffee schedule differs')
 rows=[dict(scene='conference',name=selected['name'],requestedStartXYZ=selected['requestedStartXYZ'],requestedGoalXYZ=selected['requestedGoalXYZ'],**c),dict(scene='coffee',name='0_to_8',requestedStartXYZ=q['chain'][0],requestedGoalXYZ=q['chain'][-1],**reproduced)]
 for r in rows:
  if len(r['events'])!=EXPECTED_COUNTS[r['scene']]:raise ValueError('Original count changed')
  if r['chain'][0]!=r['requestedStartXYZ']or r['chain'][-1]!=r['requestedGoalXYZ']:raise ValueError('Goal association changed')
  for e in r['events']:
   if not all(math.isfinite(v)for key in ('a','b')for v in e[key]):raise ValueError('Nonfinite original')
 return rows

def unchanged_metadata(original,candidate):
 for k in ('kind','yaw','dyaw','edge'):
  if candidate[k]!=original[k]:raise ValueError('Authored event metadata changed: '+k)
 if candidate['valid']:
  for key in ('a','b'):
   if candidate[key][0::2]!=original[key][0::2]:raise ValueError('Desired XZ replaced')
   if len(candidate[key])!=3 or not all(math.isfinite(v)for v in candidate[key]):raise ValueError('Invalid proposed event')
 return True

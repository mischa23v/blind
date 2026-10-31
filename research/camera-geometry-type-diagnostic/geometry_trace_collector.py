"""Bounded synthetic trace reader. No observation alone passes the native audit."""
from pathlib import Path
import json,math,os,re,stat
DYNAMIC={'xSmall','small','medium','large','xLarge','xxLarge','xxxLarge','accessibility1','accessibility2','accessibility3','accessibility4','accessibility5'}
LEGACY={'extraSmall','small','medium','large','extraLarge','extraExtraLarge','extraExtraExtraLarge','accessibilityMedium','accessibilityLarge','accessibilityExtraLarge','accessibilityExtraExtraLarge','accessibilityExtraExtraExtraLarge'}
ROLES={'header','button','footer','container'}
KEYS={'schema','seq','launch','uptime','role','event','dynamic','legacy','appearanceInterval','frame'}
CAP=514*2048

def number(v):return type(v) in (int,float) and math.isfinite(v)

def collect(path,not_before,output,log_summary):
 path,output=Path(path),Path(output)
 if not number(not_before):raise ValueError('Selector never started')
 with os.fdopen(os.open(path,os.O_RDONLY|getattr(os,'O_NOFOLLOW',0)),'rb') as stream:
  s=os.fstat(stream.fileno())
  if not stat.S_ISREG(s.st_mode) or s.st_mtime<not_before or not 0<s.st_size<=CAP:raise ValueError('Missing, stale or oversized regular trace')
  raw=stream.read(CAP+1)
 if len(raw)>CAP or not raw.endswith(b'\n'):raise ValueError('Oversized/incomplete trace')
 lines=raw.splitlines(keepends=True)
 if not 1<=len(lines)<=514 or any(len(x)>2048 for x in lines):raise ValueError('Trace row/count bound')
 rows=[json.loads(x) for x in lines];launch=None;previous=-1
 for i,r in enumerate(rows,1):
  if set(r)!=KEYS or type(r['schema']) is not int or r['schema']!=1 or type(r['seq']) is not int or r['seq']!=i:raise ValueError('Schema/sequence')
  if not isinstance(r['launch'],str) or not re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}',r['launch']):raise ValueError('Launch identity')
  launch=launch or r['launch']
  if launch!=r['launch'] or not number(r['uptime']) or r['uptime']<previous:raise ValueError('Mixed launch/nonmonotonic')
  previous=r['uptime']
  if type(r['appearanceInterval']) is not int or not 0<=r['appearanceInterval']<=512:raise ValueError('Appearance interval')
  if r['role']=='trace':
   if r['event'] not in {'overflow','flushed'} or r['dynamic']!='unknown' or r['legacy']!='unknown' or r['frame'] is not None:raise ValueError('Terminal record')
  elif r['role'] in ROLES:
   if r['event'] not in {'appear','disappear','dynamic-change','legacy-change','geometry'}:raise ValueError('Event')
   if r['dynamic'] not in DYNAMIC|{'unknown'} or r['legacy'] not in LEGACY|{'unknown'}:raise ValueError('Category')
   if r['event']=='geometry':
    f=r['frame']
    if not isinstance(f,list) or len(f)!=4 or not all(number(v) for v in f) or min(f[2:])<0:raise ValueError('Frame')
   elif r['frame'] is not None:raise ValueError('Unexpected frame')
  else:raise ValueError('Role')
 if any(r['event']=='flushed' for r in rows[:-1]):raise ValueError('Records after flush')
 begin=[];end=[];marker_order=[]
 for line in log_summary.get('lines',[]):
  b=re.search(r'ACCESSIBILITY_AUDIT_GEOMETRY_BEGIN phase=camera uptime=([0-9.]+)',line)
  e=re.search(r'ACCESSIBILITY_AUDIT_GEOMETRY_END phase=camera termination=(returned|threw) uptime=([0-9.]+)',line)
  if b:begin.append(float(b[1]));marker_order.append("begin")
  if e:end.append((e[1],float(e[2])));marker_order.append("end")
 markers=marker_order==["begin","end"] and len(begin)==len(end)==1 and begin[0]<end[0][1]
 terminal=rows[-1]['event']=='flushed'
 flushed_after=bool(markers and terminal and rows[-1]['uptime']>=end[0][1])
 overflow=any(r['event']=='overflow' for r in rows)
 unknown=any(r['role'] in ROLES and ('unknown' in (r['dynamic'],r['legacy'])) for r in rows)
 roles={r['role'] for r in rows if r['event']=='geometry'}
 in_audit=[r for r in rows if markers and r['event']=='geometry' and begin[0]<r['uptime']<end[0][1]]
 coverage={role:{'observedCategories':sorted({r['dynamic'] for r in in_audit if r['role']==role}),
                  'missingCategories':sorted(DYNAMIC-{r['dynamic'] for r in in_audit if r['role']==role})}
           for role in sorted(ROLES)}
 geometry_complete=all(not x['missingCategories'] for x in coverage.values())
 complete=flushed_after and roles==ROLES and geometry_complete and not overflow and not unknown
 result={'schema':1,'scope':'buffered synthetic layout/lifecycle; not audit pass or visible glyph proof','launch':launch,'rowCount':len(rows),'status':'complete' if complete else 'partial','overflow':overflow,'unknownCategory':unknown,'geometryRoles':sorted(roles),'auditMarkersComplete':markers,'flushAfterAuditEnd':flushed_after,'auditTermination':end[0][0] if len(end)==1 else 'unknown','inAuditGeometryCount':len(in_audit),'geometryCoverage':coverage,'missingGeometryMeaning':'unknown, not zero size or visibility failure','rows':rows}
 output.write_text(json.dumps(result,separators=(',',':'))+'\n')
 if not complete:raise ValueError('Incomplete/overflow/unknown trace preserved')
 return {k:v for k,v in result.items() if k!='rows'}

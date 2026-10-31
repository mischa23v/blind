"""Strict bounded synthetic app trace collection; missing/overflow stays a failure."""
from pathlib import Path
import json, math, re

KEYS={'schema','seq','launch','uptime','role','event','dynamic','legacy'}
CATEGORIES={
 'dynamic': {'xSmall','small','medium','large','xLarge','xxLarge','xxxLarge',
             'accessibility1','accessibility2','accessibility3','accessibility4','accessibility5'},
 'legacy': {'extraSmall','small','medium','large','extraLarge','extraExtraLarge','extraExtraExtraLarge',
            'accessibilityMedium','accessibilityLarge','accessibilityExtraLarge',
            'accessibilityExtraExtraLarge','accessibilityExtraExtraExtraLarge'},
}


def collect(path, not_before, output):
 path,output=Path(path),Path(output)
 if not isinstance(not_before,(int,float)): raise ValueError('Selector never started')
 if path.is_symlink() or not path.is_file(): raise ValueError('Missing regular app trace')
 stat=path.stat()
 if stat.st_mtime < not_before: raise ValueError('Stale trace predates selector')
 if not 0 < stat.st_size <= 129*1024: raise ValueError('Trace size outside bound')
 raw=path.read_bytes()
 if len(raw)>129*1024: raise ValueError('Trace changed beyond bound')
 lines=raw.splitlines(keepends=True)
 if any(len(line)>1024 for line in lines): raise ValueError('Trace row exceeds 1 KiB including newline')
 rows=[json.loads(line) for line in lines]
 if not 1<=len(rows)<=129: raise ValueError('Invalid trace row count')
 launch=None; previous=-1
 for i,row in enumerate(rows,1):
  if set(row)!=KEYS or row['schema']!=1 or row['seq']!=i: raise ValueError('Invalid trace schema/sequence')
  if not isinstance(row['launch'],str) or not re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}',row['launch']): raise ValueError('Invalid launch identity')
  launch=launch or row['launch']
  if row['launch']!=launch: raise ValueError('Mixed launches')
  if not isinstance(row['uptime'],(float,int)) or not math.isfinite(row['uptime']) or row['uptime']<previous: raise ValueError('Invalid monotonic time')
  previous=row['uptime']
  if row['role'] not in {'header','button','footer'}: raise ValueError('Unknown role')
  if row['event'] not in {'appear','dynamic-change','legacy-change','overflow'}: raise ValueError('Unknown event')
  for key in ('dynamic','legacy'):
   if not isinstance(row[key],str) or row[key] not in CATEGORIES[key] | {'unknown'}: raise ValueError('Non-allowlisted category payload')
 observed={r['role'] for r in rows if r['event']=='appear'}
 overflow=any(r['event']=='overflow' for r in rows)
 unknown=any(r[key]=='unknown' for r in rows for key in CATEGORIES)
 result={'schema':1,'scope':'synthetic app-effective SwiftUI categories; not geometry or audit acceptance',
         'launch':launch,'rowCount':len(rows),'overflow':overflow,'unknownCategory':unknown,'observedRoles':sorted(observed),
         'rows':rows,'status':'complete' if observed=={'header','button','footer'} and not overflow and not unknown else 'partial'}
 output.write_text(json.dumps(result,indent=2)+'\n')
 if result['status']!='complete': raise ValueError('Incomplete/overflow/unknown-category trace retained')
 return {k:v for k,v in result.items() if k!='rows'}

#!/usr/bin/env python3
"""Portable fixtures only: no Apple build, simulator, subprocess harness or model."""
from pathlib import Path
import importlib.util, json, os, shutil, sys, tempfile, time
from instrument import PINS, instrument
from effective_trace_collector import CATEGORIES, collect

source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[2]
checks=[]
def check(name,condition):
 if not condition: raise AssertionError(name)
 checks.append(name)

def rejected(action):
 try: action()
 except (ValueError, FileNotFoundError): return True
 return False

with tempfile.TemporaryDirectory() as tmp:
 root=Path(tmp)/'source';root.mkdir()
 for p in PINS:
  (root/p).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/p,root/p)
 originals={p:(root/p).read_text() for p in PINS}
 receipt=instrument(root)
 check('four pinned files instrumented',set(receipt)==set(PINS))
 check('cannot instrument already changed source',rejected(lambda:instrument(root)))
 app=next(iter(PINS)); changed=(root/app).read_text()
 check('three category probes only',changed.count('.modifier(AuditEffectiveTypeProbe(role:')==3)
 for token in ['GeometryReader','accessibilityElement(','dynamicTypeSize(','environment(\\.sizeCategory','environment(\\.dynamicTypeSize']:
  check('no added '+token,changed.count(token)==originals[app].count(token))
 check('existing font and sizing statements identical',
       [x.strip() for x in changed.splitlines() if any(t in x for t in ('.font(','.lineLimit(','.fixedSize('))]==
       [x.strip() for x in originals[app].splitlines() if any(t in x for t in ('.font(','.lineLimit(','.fixedSize('))])
 for p in list(PINS)[1:3]:
  before=originals[p];after=(root/p).read_text()
  restored=after.replace('"--ui-testing", "--audit-effective-type",','"--ui-testing",')
  restored='\n'.join(x for x in restored.split('\n') if 'ACCESSIBILITY_AUDIT_EFFECTIVE_' not in x)
  check('test assertions/audit unchanged '+p,restored==before)
 runner=root/'tools/ci/camera-audit-scope-control.py'
 compile(runner.read_text(),str(runner),'exec')
 check('runner syntax compiles',True)
 # No runner execution; imported collector is exercised only on synthetic JSON.
 trace=Path(tmp)/'trace.jsonl';output=Path(tmp)/'result.json';started=time.time()-1
 def write(rows):trace.write_text(''.join(json.dumps(r)+'\n' for r in rows))
 def row(i,role='header',event='appear'):
  return dict(schema=1,seq=i,launch='12345678-1234-1234-1234-123456789abc',uptime=float(i),role=role,event=event,dynamic='large',legacy='large')
 valid=[row(i,r) for i,r in enumerate(['header','button','footer'],1)]
 write(valid);check('complete roles retained',collect(trace,started,output)['status']=='complete')
 check('missing file fails',rejected(lambda:collect(Path(tmp)/'absent',started,output)))
 check('selector not run fails',rejected(lambda:collect(trace,None,output)))
 check('stale file fails',rejected(lambda:collect(trace,time.time()+1,output)))
 write(valid[:2]);check('missing role fails but retains partial',rejected(lambda:collect(trace,started,output)) and json.loads(output.read_text())['status']=='partial')
 write(valid+[row(4,event='overflow')]);check('overflow fails and retained',rejected(lambda:collect(trace,started,output)) and json.loads(output.read_text())['overflow'])
 bad=[dict(r) for r in valid];bad[1]['launch']='87654321-1234-1234-1234-123456789abc';write(bad)
 check('mixed launch rejected',rejected(lambda:collect(trace,started,output)))
 bad=[dict(r) for r in valid];bad[1]['seq']=5;write(bad)
 check('sequence gap rejected',rejected(lambda:collect(trace,started,output)))
 bad=[dict(r) for r in valid];bad[1]['dynamic']='private content / text';write(bad)
 check('non-category payload rejected',rejected(lambda:collect(trace,started,output)))
 for key in CATEGORIES:
  for category in CATEGORIES[key]:
   good=[dict(r) for r in valid];good[1][key]=category;write(good)
   check('allowlisted '+key+' '+category,collect(trace,started,output)['status']=='complete')
  bad=[dict(r) for r in valid];bad[1][key]='unknown';write(bad)
  check('unknown '+key+' retained incomplete',rejected(lambda:collect(trace,started,output)) and json.loads(output.read_text())['unknownCategory'] and json.loads(output.read_text())['status']=='partial' and json.loads(output.read_text())['rows'][1][key]=='unknown')
  bad=[dict(r) for r in valid];bad[1][key]='inventedCategory';write(bad)
  check('arbitrary alphanumeric '+key+' rejected',rejected(lambda:collect(trace,started,output)))
 bad=[dict(r) for r in valid];bad[1]['dynamic']='extraLarge';write(bad)
 check('legacy-only tag in dynamic rejected',rejected(lambda:collect(trace,started,output)))
 bad=[dict(r) for r in valid];bad[1]['legacy']='accessibility5';write(bad)
 check('dynamic-only tag in legacy rejected',rejected(lambda:collect(trace,started,output)))
 # A legal record padded with JSON whitespace remains within total cap but exceeds row cap.
 lines=[json.dumps(r).encode() for r in valid]
 trace.write_bytes(lines[0]+b' '*(1024-len(lines[0]))+b'\n'+b'\n'.join(lines[1:])+b'\n')
 check('1025-byte single row rejected below total cap',rejected(lambda:collect(trace,started,output)))
 trace.write_bytes(lines[0]+b' '*(1023-len(lines[0]))+b'\n'+b'\n'.join(lines[1:])+b'\n')
 check('1024-byte row including newline accepted',collect(trace,started,output)['status']=='complete')
 trace.write_bytes(b'x'*(129*1024+1));check('oversize rejected',rejected(lambda:collect(trace,started,output)))
 write(valid);link=Path(tmp)/'link';link.symlink_to(trace);check('symlink rejected',rejected(lambda:collect(link,started,output)))
print(json.dumps({'scope':'portable synthetic instrument/collector checks only','passed':len(checks),'checks':checks},indent=2))

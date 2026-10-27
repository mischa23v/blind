#!/usr/bin/env python3
from pathlib import Path
import copy,hashlib,json,os,shutil,sys,tempfile,time
from instrument import PINS,instrument
from geometry_trace_collector import collect,ROLES,CAP,DYNAMIC
source=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[2]
checks=[]
def check(n,c):
 if not c:raise AssertionError(n)
 checks.append(n)
def rejects(fn):
 try:fn()
 except (ValueError,OSError):return True
 return False
with tempfile.TemporaryDirectory() as tmp:
 root=Path(tmp)/'source';root.mkdir()
 for p in PINS:
  (root/p).parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source/p,root/p)
 old={p:(root/p).read_text() for p in PINS};receipt=instrument(root)
 check('exact four pinned sources',set(receipt)==set(PINS))
 check('refuse reinstrumentation',rejects(lambda:instrument(root)))
 app,full,typed,runner=PINS
 new=(root/app).read_text()
 check('four probes',new.count('.modifier(AuditGeometryProbe(role:')==4)
 for token in ['GeometryReader','accessibilityElement(','.id(','.frame(','.font(','.lineLimit(','.fixedSize(']:
  if token=='.frame(':continue # public proxy.frame is observation, not View.frame modifier
  check('unchanged production '+token,new.count(token)==old[app].count(token))
 check('no layout-state writer','@State' not in new[len(old[app]):] and '@Published' not in new[len(old[app]):])
 check('onGeometryChange used','.onGeometryChange(for: AuditGeometrySample.self)' in new)
 check('global geometry carries immutable categories','dynamic: dynamicName, legacy: legacyName)' in new)
 transform=new.split('.onGeometryChange(for: AuditGeometrySample.self) { proxy in')[1].split('} action:')[0]
 check('sendable transform avoids actor helper calls','dynamicLabel(' not in transform and 'legacyLabel(' not in transform and 'dynamicName' in transform and 'legacyName' in transform)
 check('sample explicitly Sendable','AuditGeometrySample: Equatable, Sendable' in new)
 check('no serialization/write in emit',all(x not in new.split('    static func emit(')[1].split('    private static func append')[0] for x in ['JSONSerialization','write(to:','print(']))
 check('buffer limit and overflow','rows.count < 512' in new and 'if !overflow' in new and '514 * 2048' in new)
 for p in [full,typed]:
  t=(root/p).read_text()
  check('original audit invocations '+p,[x.strip() for x in t.splitlines() if 'try app.performAccessibilityAudit' in x]==[x.strip() for x in old[p].splitlines() if 'try app.performAccessibilityAudit' in x])
  check('original issue filtering '+p,'guard issue.auditType == .contrast, let element = issue.element else { return false }' in t and 'return element.identifier == "retrace-session" && !element.isEnabled' in t)
  check('restores continue setting '+p,'continueAfterFailure = previousContinueAfterFailure' in t)
  check('bounded fixed notification '+p,'CFNotificationName(rawValue: "org.blindassist.synthetic.geometry.flush" as CFString)' in t)
 compile((root/runner).read_text(),runner,'exec');check('runner syntax',True)
 trace=Path(tmp)/'trace';out=Path(tmp)/'out';start=time.time()-1
 def r(i,role,event,frame=None):return dict(schema=1,seq=i,launch='12345678-1234-1234-1234-123456789abc',uptime=float(i),role=role,event=event,dynamic='unknown' if role=='trace' else 'large',legacy='unknown' if role=='trace' else 'large',appearanceInterval=0,frame=frame)
 valid=[]
 for role in sorted(ROLES):
  for category in sorted(DYNAMIC):
   row=r(len(valid)+1,role,'geometry',[0,0,100,20]);row['dynamic']=category;valid.append(row)
 valid.append(r(49,'trace','flushed'))
 logs={'lines':['ACCESSIBILITY_AUDIT_GEOMETRY_BEGIN phase=camera uptime=0.1','ACCESSIBILITY_AUDIT_GEOMETRY_END phase=camera termination=threw uptime=48.5']}
 def write(rows):trace.write_text(''.join(json.dumps(x)+'\n' for x in rows))
 def run(rows=valid,log=logs):write(rows);return collect(trace,start,out,log)
 check('complete trace from failed audit',run()['status']=='complete' and run()['auditTermination']=='threw')
 for name,mutate in [
 ('unknown category',lambda x:x[0].update(dynamic='unknown')),
 ('missing geometry role',lambda x:x[0].update(role='footer')),
 ('missing flush',lambda x:x[-1].update(event='overflow')),
 ('flush precedes end',lambda x:x[-1].update(uptime=48.1)),
 ]:
  rows=copy.deepcopy(valid);mutate(rows);check(name+' retained partial',rejects(lambda:run(rows)) and json.loads(out.read_text())['status']=='partial')
 for name,mutate in [
 ('NaN frame',lambda x:x[0]['frame'].__setitem__(0,float('nan'))),
 ('negative width',lambda x:x[0]['frame'].__setitem__(2,-1)),
 ('bool time',lambda x:x[0].update(uptime=True)),
 ('bool sequence',lambda x:x[0].update(seq=True)),
 ('mixed launch',lambda x:x[0].update(launch='87654321-1234-1234-1234-123456789abc')),
 ('bad event',lambda x:x[0].update(event='private text')),
 ('unknown role',lambda x:x[0].update(role='private text')),
 ('extra payload',lambda x:x[0].update(extra='private text')),
 ('category domain',lambda x:x[0].update(dynamic='extraLarge')),
 ('negative interval',lambda x:x[0].update(appearanceInterval=-1)),
 ('nonmonotonic time',lambda x:x[1].update(uptime=0.5)),
 ]:
  rows=copy.deepcopy(valid);mutate(rows);check(name+' rejected',rejects(lambda:run(rows)))
 no_sweep=copy.deepcopy(valid);no_sweep[-1]['uptime']=102
 no_sweep_log={'lines':['ACCESSIBILITY_AUDIT_GEOMETRY_BEGIN phase=camera uptime=100','ACCESSIBILITY_AUDIT_GEOMETRY_END phase=camera termination=returned uptime=101']}
 check('preaudit geometry cannot complete',rejects(lambda:run(no_sweep,no_sweep_log)) and json.loads(out.read_text())['inAuditGeometryCount']==0)
 check('preaudit missing coverage explicit',all(len(x['missingCategories'])==12 for x in json.loads(out.read_text())['geometryCoverage'].values()))
 partial=copy.deepcopy(valid);partial[0]['uptime']=0
 check('missing one swept sample stays partial',rejects(lambda:run(partial)) and json.loads(out.read_text())['status']=='partial')
 check('missing markers partial' ,rejects(lambda:run(log={'lines':[]})))
 check('reversed marker log order partial',rejects(lambda:run(log={'lines':list(reversed(logs['lines']))})))
 check('duplicate markers partial',rejects(lambda:run(log={'lines':logs['lines']*2})))
 check('returned audit explicitly separate',run(log={'lines':[logs['lines'][0],logs['lines'][1].replace('threw','returned')]})['auditTermination']=='returned')
 write(valid);check('stale file',rejects(lambda:collect(trace,time.time()+1,out,logs)))
 link=Path(tmp)/'link';link.symlink_to(trace);check('symlink rejected',rejects(lambda:collect(link,start,out,logs)))
 trace.write_bytes(b'x'*(CAP+1));check('byte bound',rejects(lambda:collect(trace,start,out,logs)))
 write(valid);trace.write_bytes(trace.read_bytes().rstrip(b'\n'));check('truncated record',rejects(lambda:collect(trace,start,out,logs)))
print(json.dumps({'scope':'portable synthetic source/collector checks, not Swift compilation or native audit','passed':len(checks),'checks':checks},indent=2))

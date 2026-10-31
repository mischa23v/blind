from pathlib import Path
import tempfile,json,sys,hashlib,os,subprocess,signal,time
from unittest.mock import patch
from endpoint_receipt import verify_endpoint,SELECTORS,CATEGORIES
from run import PINS
base=Path(__file__).resolve().parent;root=Path(sys.argv[1]) if len(sys.argv)>1 else base.parents[1]
checks=[]
def check(n,c):
 if not c:raise AssertionError(n)
 checks.append(n)
def reject(fn):
 try:fn()
 except ValueError:return True
 return False
for p,sha in PINS.items():check('source pin '+p,hashlib.sha256((root/p).read_bytes()).hexdigest()==sha)
for f in base.glob('*.py'):compile(f.read_text(),str(f),'exec')
check('Python syntax',True)
s=(base/'runner.py').read_text()
check('two endpoint selectors only',s.count("'BlindAssistUITests/LaunchTests/testPracticeLayoutAt")==2 and 'performAccessibilityAudit' not in s)
check('original build budget600',"'build', 600" in s)
check('original selector budget300','name, 300, test=True' in s)
check('explicit endpoint optin',"env['TEST_RUNNER_BLIND_LAYOUT_DIAGNOSTIC'] = '1'" in s)
check('requested category verified',"if observed != name" in s)
check('process group termination preserved','os.killpg' in s and 'start_new_session=True' in s)
check('four images per size','len(paths) != 4' in s and 'len(paths) + len(existing) > 8' in s)
with tempfile.TemporaryDirectory() as t:
 p=Path(t)/'log'
 for size,selector in SELECTORS.items():
  good=[f"Test Case '-[BlindAssistUITests.LaunchTests {selector}]' started.",f'PRACTICE_LAYOUT category={CATEGORIES[size]} expected={CATEGORIES[size]} runnerBodyPoints=17']+[f'PRACTICE_LAYOUT afterReveal category={CATEGORIES[size]} role={role} label=synthetic' for role in ['button','header','footer']]+[f'PRACTICE_LAYOUT footerEnd size={size} endVisible=true',f"Test Case '-[BlindAssistUITests.LaunchTests {selector}]' passed (1.0 seconds)."]
  def write(lines):p.write_text('\n'.join(lines)+'\n')
  write(good);check('passed '+size,verify_endpoint(p,size)['status']=='passed')
  for name,lines in [('no-start',good[1:]),('skipped',[x.replace(' passed (',' skipped (') for x in good]),('failed',[x.replace(' passed (',' failed (') for x in good]),('duplicate-end',good+[good[-2]]),('unreachable',[x.replace('endVisible=true','endVisible=false') for x in good]),('missing-role',[x for x in good if 'role=footer' not in x]),('wrong-category',[x.replace('expected='+CATEGORIES[size],'expected=wrong') for x in good])]:
   write(lines);check(name+' '+size,reject(lambda:verify_endpoint(p,size)))
os.environ['BLIND_ENDPOINT_SOURCE_ROOT']=str(root.resolve())
from runner import publish_staged_images, stop_owned_group, recover_owned_uuid
uid='12345678-1234-1234-1234-123456789abc'
check('recovery exact owned only',recover_owned_uuid({'devices':{'runtime':[{'name':'other','udid':uid},{'name':'owned','udid':uid}]}},'owned')==uid)
check('recovery absent remains unknown',recover_owned_uuid({'devices':{'runtime':[{'name':'other','udid':uid}]}},'owned') is None)
for name,data in [('duplicate',{'devices':{'runtime':[{'name':'owned','udid':uid}]*2}}),('invalid-id',{'devices':{'runtime':[{'name':'owned','udid':'bad'}]}}),('bad-root',[]),('bad-group',{'devices':{'runtime':None}}),('bad-entry',{'devices':{'runtime':[None]}})]:
 check('recovery rejects '+name,reject(lambda:recover_owned_uuid(data,'owned')))
with tempfile.TemporaryDirectory() as t:
 d=Path(t); artifacts=d/'artifacts';artifacts.mkdir()
 def stage(name,bytes_each):
  p=d/name;p.mkdir()
  for role in ['button','header','footer','footer-end']:
   f=p/('large-'+role+'.png')
   with f.open('wb') as h:h.write(b'\x89PNG\r\n\x1a\n');h.truncate(bytes_each)
  return p
 rejected=stage('oversize',7*1024*1024);record={}
 check('28MiB staging rejected before upload',reject(lambda:publish_staged_images(rejected,artifacts,'large',record)))
 check('oversize upload empty',list(artifacts.iterdir())==[] and not record['staging']['published'])
 good=stage('good',3*1024*1024);record={}
 check('12MiB atomic stage published',len(publish_staged_images(good,artifacts,'large',record))==4 and record['staging']['published'] and not good.exists())
 bad=stage('aggregate',4*1024*1024)
 for f in list(bad.iterdir()):f.rename(bad/f.name.replace('large-','accessibility-extra-extra-extra-large-',1))
 record={}
 check('aggregate28MiB rejected',reject(lambda:publish_staged_images(bad,artifacts,'accessibility-extra-extra-extra-large',record)))
 check('existing evidence retained',len(list(artifacts.glob('*/*.png')))==4 and record['staging']['combinedBytes']==28*1024*1024)
 # Real leader exits while its descendant ignores SIGTERM. Helper must still
 # send SIGKILL to the owned group, regardless of leader.returncode.
 child=d/'pid'
 code="import os,signal,time,sys; p=os.fork(); " + "\nif p==0:\n signal.signal(signal.SIGTERM,signal.SIG_IGN);open(sys.argv[1],'w').write(str(os.getpid()));time.sleep(60)\nelse:\n time.sleep(.2);sys.exit(0)"
 process=subprocess.Popen([sys.executable,'-c',code,str(child)],start_new_session=True,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
 pid=None
 try:
  process.wait(timeout=3);pid=int(child.read_text());record={}
  stop_owned_group(process,record,grace=.1)
  check('exited leader descendant SIGKILL issued',record.get('sentSIGTERM') and record.get('sentSIGKILL') and record['leaderReaped'])
  check('group cleanup evidence explicit',record['ownedGroupCleanup'] in ['absent','unknown_remaining_group'])
 finally:
  try:os.killpg(process.pid,signal.SIGKILL)
  except ProcessLookupError:pass
  process.wait(timeout=3)
 # Mock stable absence proves ordinary fully reaped command returns clean.
 with patch('runner.owned_group_exists',return_value=False):
  record={};check('absent group clean',stop_owned_group(process,record,grace=.01) and record['ownedGroupCleanup']=='absent')
print(json.dumps({'scope':'portable source/receipt fixtures only','passed':len(checks),'checks':checks},indent=2))

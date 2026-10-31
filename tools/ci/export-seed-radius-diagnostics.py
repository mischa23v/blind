"""Bounded failure-preserving evidence for fourteen fixed public fixture tests only."""
import hashlib,importlib.util,json,os,re,sys
from pathlib import Path
sys.dont_write_bytecode=True
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
s=importlib.util.spec_from_file_location('seed_collector',H/'collect-seed-radius.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
EXPECTED=set(m.EXPECTED)
FIXTURE_SHA='df12572e95906fb794606e42cecd678d230e204c016ef88b15b17ea1f0d7fde3'

def identity(raw):
 if type(raw) is not str:return None
 raw=raw.removesuffix('()').removeprefix('BlindAssistTests/')
 if raw in EXPECTED:return raw
 match=re.fullmatch(r'-\[(?:BlindAssistTests\.)?(SavedRoomStrictEndpointTests|SeedRadiusVetoAppleTests|SeedRadiusEnvelopeAppleTests) (test\w+)\]',raw)
 if match and '/'.join(match.groups()) in EXPECTED:return '/'.join(match.groups())
 return None

def message(raw):
 if type(raw) is not str:return None
 # Public synthetic assertion text only; arrays and arbitrary paths are not needed.
 value=re.sub(r'\[[^\]\n]*\]','[values omitted]',raw)
 value=re.sub(r'(?:/[A-Za-z0-9_.-]+){2,}', '[path omitted]',value)
 value=''.join(c if 32<=ord(c)<=126 else ' ' for c in value)
 return {'message':value[:768],'truncated':len(value)>768}

def summarize(cases,summary,log,command):
 result={'expectedIdentities':sorted(EXPECTED),'commandExit':command.get('exit_code') if type(command.get('exit_code')) is int else None,'cases':[],'unexpectedCaseCount':0,'assertionFailures':[],'unparsedFailureRecordCount':0,'scope':'fixed public fixture tests only; diagnostic receipt never authorizes pass'}
 if cases is not None:
  for row in cases[:64]:
   name=identity(row.get('identifier'))
   if name:result['cases'].append({'identifier':name,'result':row['result']})
   else:result['unexpectedCaseCount']+=1
  result['casesTruncated']=len(cases)>64
 result['summarySchemaUnavailable']=not isinstance(summary,dict)
 if isinstance(summary,dict):
  result['aggregateCounts']={k:summary[k] for k in ['totalTestCount','passedTests','failedTests','skippedTests','expectedFailures'] if type(summary.get(k)) is int and summary[k]>=0}
  failures=summary.get('testFailures')
  if isinstance(failures,list):
   for row in failures[:32]:
    if not isinstance(row,dict):result['unparsedFailureRecordCount']+=1;continue
    name=identity(row.get('testIdentifier')) or identity(row.get('testName'))
    text=message(row.get('failureText',row.get('message')))
    if name and text:result['assertionFailures'].append({'identifier':name,'origin':'xcresult-summary',**text})
    else:result['unparsedFailureRecordCount']+=1
   result['summaryFailuresTruncated']=len(failures)>32
  else:result['failureSchemaUnavailable']=True
 # Only fixed fixture filename and exact test identity; never general compiler/app logs.
 if log is not None:
  pattern=r'.*\bSavedRoomStrictEndpointTests\.swift:(\d{1,9}): error: (-\[(?:BlindAssistTests\.)?(?:SavedRoomStrictEndpointTests|SeedRadiusVetoAppleTests|SeedRadiusEnvelopeAppleTests) test\w+\]) : (.*)'
  for line in log.splitlines():
   if len(line)>4096:continue
   match=re.fullmatch(pattern,line)
   if not match:continue
   line_no,raw,text=match.groups();name=identity(raw)
   if name and len(result['assertionFailures'])<32:result['assertionFailures'].append({'identifier':name,'origin':'fixed-fixture-log','line':int(line_no),**message(text)})
 result['assertionFailures']=result['assertionFailures'][:32]
 return result

def main():
 out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=True)
 result={'status':'unavailable','sourceVerified':False,'expectedCommit':os.environ.get('GITHUB_SHA'),'errors':{}}
 command={};cases=summary=log=None
 try:
  command=json.loads((out/'seed-radius-unit-exit.json').read_text())
  if type(command) is not dict:raise ValueError('unsupported command receipt schema')
 except (OSError,ValueError) as e:command={};result['errors']['command']=type(e).__name__
 result['commandExit']=command.get('exit_code') if type(command.get('exit_code')) is int else None
 try:
  before=m.native.provenance(ROOT,os.environ.get('GITHUB_SHA'))
  fixture=ROOT/'ios/BlindAssistTests/SavedRoomStrictEndpointTests.swift'
  if hashlib.sha256(fixture.read_bytes()).hexdigest()!=FIXTURE_SHA:raise ValueError('fixture identity changed')
  bundle=out/'seed-radius-unit.xcresult'
  for label,kind in [('cases','tests'),('summary','summary')]:
   try:
    value=json.loads(m.native.query(['xcrun','xcresulttool','get','test-results',kind,'--path',str(bundle),'--compact']))
    if label=='cases':cases=m.native.cases_from(value)
    else:summary=value
   except (OSError,ValueError,RecursionError,__import__('subprocess').SubprocessError) as e:result['errors'][label]=type(e).__name__
  try:
   p=out/'seed-radius-unit.log'
   if p.stat().st_size>64*1024*1024:raise ValueError('log bound')
   log=p.read_text(errors='replace')
  except (OSError,ValueError) as e:result['errors']['log']=type(e).__name__
  after=m.native.provenance(ROOT,os.environ.get('GITHUB_SHA'))
  if before!=after:raise ValueError('source changed')
  result.update(summarize(cases,summary,log,command));result.update(status='diagnostic-only',sourceVerified=True,sourceCommit=before['actual_head'],fixtureSHA256=FIXTURE_SHA)
 except (OSError,ValueError,RecursionError,__import__('subprocess').SubprocessError) as e:result['errors']['source']=type(e).__name__
 encoded=json.dumps(result,indent=2)+'\n'
 if len(encoded.encode())>65536:raise ValueError('bounded diagnostic output exceeded')
 (out/'seed-radius-diagnostics.json').write_text(encoded)
 print('SEED_RADIUS_DIAGNOSTICS='+json.dumps(result,separators=(',',':')))
 return 0 # Evidence only: original native step and strict collector retain failure.
if __name__=='__main__':raise SystemExit(main())

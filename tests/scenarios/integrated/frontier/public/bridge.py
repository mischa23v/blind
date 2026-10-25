#!/usr/bin/env python3
"""File-mailbox IPC only: actual Swift process owns state; records requests/responses verbatim."""
import sys,json,subprocess,pathlib,hashlib,datetime,os,time,uuid
mode=sys.argv[1]
if mode=='serve':
    build=pathlib.Path(sys.argv[2]).resolve(); sockpath=sys.argv[3]; log=pathlib.Path(sys.argv[4]).resolve()
    mailbox=pathlib.Path(sockpath);mailbox.mkdir(exist_ok=False)
    env=dict(os.environ)
    if not env.get('BLIND_DATASET_ROOT'): raise SystemExit('Set BLIND_DATASET_ROOT to your separately obtained dataset root; do not invent or substitute source assets')
    proc=subprocess.Popen([str(build/'package/.build/debug/FrontierRunner'),str(build/'episodes.json')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,bufsize=1,env=env)
    
    previous='0'*64; seq=0
    print(json.dumps({'ready':sockpath,'source_manifest_sha256':hashlib.sha256((build/'source-sha256.txt').read_bytes()).hexdigest()}),flush=True)
    try:
      while True:
        pending=sorted(mailbox.glob('*.request'))
        if not pending: time.sleep(0.05);continue
        for request_path in pending:
          request=request_path.read_bytes()
          action=json.loads(request)
          proc.stdin.write(json.dumps(action)+'\n');proc.stdin.flush()
          raw=proc.stdout.readline()
          if not raw: raise RuntimeError('Swift runner ended unexpectedly')
          result=json.loads(raw);seq+=1
          entry={'sequence':seq,'utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'request':action,'response':result,'previous_sha256':previous,'scope':'frontier model + actual source modules; no iPhone/audio/perception'}
          canonical=json.dumps(entry,sort_keys=True,separators=(',',':')).encode();previous=hashlib.sha256(canonical).hexdigest();entry['entry_sha256']=previous
          with log.open('a') as f:f.write(json.dumps(entry,sort_keys=True)+'\n')
          response_path=request_path.with_suffix('.response')
          response_path.write_text(json.dumps(result)+'\n')
          request_path.rename(request_path.with_suffix('.processed'))
    finally:proc.terminate()
elif mode=='call':
    mailbox=pathlib.Path(sys.argv[2]);ident=uuid.uuid4().hex
    temp=mailbox/(ident+'.tmp');request=mailbox/(ident+'.request');response=mailbox/(ident+'.response')
    temp.write_text(sys.argv[3]);temp.rename(request)
    deadline=time.monotonic()+60
    while not response.exists():
      if time.monotonic()>deadline: raise SystemExit('Outcome uncertain: request remains in mailbox; inspect before retrying')
      time.sleep(0.05)
    print(response.read_text(),end='')
else:raise SystemExit('serve BUILD MAILBOX LOG | call MAILBOX JSON')

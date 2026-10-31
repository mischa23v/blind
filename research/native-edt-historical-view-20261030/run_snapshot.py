#!/usr/bin/env python3
"""Exact historical EDT input view; actual workflow checkout remains authoritative."""
import ast, hashlib, json, os, pathlib, subprocess, sys, time
HERE=pathlib.Path(__file__).resolve().parent
LANE='research/native-floor-import-repair-20261028/edt-navigation-probe'
HISTORICAL_COMMIT='5a6ad0ad5c64879a9e95bae9212054ab9daf950d'
PIN_SHA='3e1f7d07cf3b70cc04ecb6e55694bdc01cca95738f7781e554cfbb1f66aaea3b'
RUNNER_SHA='92eb8c0f99e005175fe0da96ff6c521d6430aaa3aec7246b5cf79bc7dcf5460f'

def digest(b): return hashlib.sha256(b).hexdigest()
def require(ok, message):
    if not ok: raise ValueError(message)
def safe_file(root,name):
    rel=pathlib.PurePosixPath(name)
    require(not rel.is_absolute() and '..' not in rel.parts and bool(rel.parts),'Unsafe input path')
    path=root.joinpath(*rel.parts)
    for parent in [path,*path.parents]:
        if parent==root: break
        require(not parent.is_symlink(),'Symlink input rejected: '+name)
    require(path.is_file(),'Missing input: '+name)
    require(path.resolve().is_relative_to(root.resolve()),'Input outside view')
    return path

def verify_packet():
    manifest=json.loads((HERE/'MANIFEST.json').read_text())
    for name,h in manifest['files'].items():
        require(digest(safe_file(HERE,name).read_bytes())==h,'Adapter packet mismatch: '+name)

def load_pins():
    b=(HERE/'baseline/NATIVE_SOURCE_PINS.json').read_bytes()
    require(digest(b)==PIN_SHA,'Historical pin manifest changed')
    pins=json.loads(b)['files'];require(len(pins)==58,'Historical inventory changed')
    return b,pins

def authorize_checkout(repo,env,git):
    require(env.get('GITHUB_REPOSITORY')=='mischa23v/blind','Wrong actual workflow repository')
    require(env.get('GITHUB_REF') in ('refs/heads/master','refs/heads/codex/recovery-hazard-order-20261027'),'Wrong actual workflow ref')
    head=git(['rev-parse','HEAD'])
    require(len(head)==40 and head==env.get('GITHUB_SHA'),'Wrong actual workflow checkout commit')
    git(['diff','--exit-code'])
    return head

def verify_view(view,pins):
    expected=set(pins)|{LANE+'/NATIVE_SOURCE_PINS.json'}
    actual={p.relative_to(view).as_posix() for p in view.rglob('*') if p.is_file() or p.is_symlink()}
    require(actual==expected,'Unexpected or missing staged input')
    for name,h in pins.items():
        require(digest(safe_file(view,name).read_bytes())==h,'Staged input mismatch: '+name)
    require(digest(safe_file(view,LANE+'/NATIVE_SOURCE_PINS.json').read_bytes())==PIN_SHA,'Staged pin manifest mismatch')

def stage_view(repo,view,pins,pin_bytes):
    overrides=json.loads((HERE/'OVERRIDES.json').read_text())
    require(len(overrides)==3 and set(overrides)<=set(pins),'Override inventory changed')
    view.mkdir(exist_ok=False)
    for name,h in pins.items():
        current=safe_file(repo,name).read_bytes()
        if name in overrides:
            o=overrides[name]
            require(digest(current)==o['currentSHA256'],'Current override source drift: '+name)
            require(o['historicalSHA256']==h,'Override expected identity differs')
            b=safe_file(HERE,o['file']).read_bytes()
        else: b=current
        require(digest(b)==h,'Unchanged historical input drift: '+name)
        dest=view/name;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(b)
    dest=view/LANE/'NATIVE_SOURCE_PINS.json';dest.write_bytes(pin_bytes)
    verify_view(view,pins)
    return overrides

def transform_runner(original):
    require(digest(original)==RUNNER_SHA,'Original runner identity changed')
    replacements=[
      ('START=time.monotonic();DEADLINE=START+300','START=_view_started;DEADLINE=START+300'),
      ('cwd=ROOT,stdout=out,stderr=err','cwd=_workflow_checkout,stdout=out,stderr=err'),
      ('def command(args,label,limit=90):\n','def command(args,label,limit=90):\n    _verify_historical_view()\n'),
      ("receipt['sourcePins']=pins;save()","receipt['sourcePins']=pins;receipt['historicalSourceView']=_view_provenance;save()"),
      ("    save()\n    print(json.dumps({'status':receipt['status']", "    _verify_historical_view()\n    save()\n    print(json.dumps({'status':receipt['status']")]
    text=original.decode()
    for old,new in replacements:
        require(text.count(old)==1,'Historical runner adaptation site changed');text=text.replace(old,new,1)
    reversed_text=text
    for old,new in reversed(replacements):
        require(reversed_text.count(new)==1,'Runner reversal site changed');reversed_text=reversed_text.replace(new,old,1)
    require(reversed_text.encode()==original,'Runner reverse differs');ast.parse(text)
    return text,replacements

def main():
    started=time.monotonic();repo=HERE.parents[1]
    require(sys.flags.optimize==0,'Original assertions must remain enabled')
    require(sys.platform=='darwin','Apple host required; source controls are separate')
    verify_packet();pin_bytes,pins=load_pins()
    def git(args):
        remaining=300-(time.monotonic()-started);require(remaining>0,'Original deadline exhausted')
        return subprocess.check_output(['git',*args],cwd=repo,timeout=min(15,remaining),text=True).strip()
    head=authorize_checkout(repo,os.environ,git)
    # No git tree/HEAD is created in this directory. It is a source view, not a checkout.
    view=pathlib.Path(os.environ['RUNNER_TEMP'])/'blind-edt-historical-source-view'
    overrides=stage_view(repo,view,pins,pin_bytes)
    original=(view/LANE/'run_native.py').read_bytes();text,_=transform_runner(original)
    identity=digest(json.dumps(pins,sort_keys=True,separators=(',',':')).encode())
    provenance={'schema':1,'actualWorkflowCommit':head,'historicalProtocolCommit':HISTORICAL_COMMIT,
        'historicalPinManifestSHA256':PIN_SHA,'historicalInputViewSHA256':identity,
        'historicalRunnerSHA256':RUNNER_SHA,'generatedRunnerSHA256':digest(text.encode()),
        'historicalInputCount':58,'checkoutMatchedInputCount':55,'historicalOverrideCount':3,
        'allHistoricalInputsVerified':True,'verifyAllInputsBeforeEveryCommand':True,
        'runnerReverseByteIdentical':True,'actualCheckoutAuthorizationPreserved':True,
        'originalControlsRequired':50,'candidateRequestsUnchanged':25,'nativeHookChecksRequired':51,
        'compileFlagAdded':False,'appActivation':False,'physicalAuthority':False,
        'currentNativeSourceCompared':False}
    # Closed public source identity receipt, no rows, geometry, errors or private paths.
    print('EDT_HISTORICAL_SOURCE_VIEW '+json.dumps(provenance,sort_keys=True),flush=True)
    def verify(): verify_view(view,pins)
    ns={'__name__':'__main__','__file__':str(view/LANE/'run_native.py'),
        '_workflow_checkout':repo,'_view_started':started,'_view_provenance':provenance,
        '_verify_historical_view':verify}
    # Exact original repository/ref/HEAD/clean checks execute against actual checkout.
    # Exact original 58 pin checks, 50 controls, 25 candidates and limits remain intact.
    exec(compile(text,str(view/LANE/'run_native.py'),'exec'),ns)
if __name__=='__main__': main()

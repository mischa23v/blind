#!/usr/bin/env python3
"""Offline source regression only; never import/execute upstream or native runner."""
import argparse, ast, difflib, hashlib, json
from pathlib import Path

p=argparse.ArgumentParser();p.add_argument('--upstream-script',type=Path,required=True);a=p.parse_args()
d=Path(__file__).resolve().parent;r=d.parents[1];e=json.loads((d/'PROVENANCE.json').read_text());checks=[]
def check(name,condition):
    if not condition: raise AssertionError(name)
    checks.append(name)
b=a.upstream_script.read_bytes()
check('canonical upstream byte count',len(b)==e['upstreamBytes'])
check('canonical Git blob identity',hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()==e['upstreamBlobSHA1'])
check('canonical SHA256 rejects old pin',hashlib.sha256(b).hexdigest()==e['actualSHA256']!=e['wrongExpectedSHA256'])
check('byte mutation rejected',hashlib.sha256(b+b'\n').hexdigest()!=e['actualSHA256'])
diff=''
for path,sha in e['baseFiles'].items():
    source=(r/path).read_bytes();check('unchanged preimage '+path,hashlib.sha256(source).hexdigest()==sha)
    text=source.decode();check('single replacement '+path,text.count(e['wrongExpectedSHA256'])==1)
    changed=text.replace(e['wrongExpectedSHA256'],e['actualSHA256'])
    diff+=''.join(difflib.unified_diff(text.splitlines(True),changed.splitlines(True),fromfile='a/'+path,tofile='b/'+path))
    if path.endswith('.py'):
        old=ast.parse(text);new=ast.parse(changed)
        for tree in (old,new):
            for node in tree.body:
                if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='INSTALL_SHA' for t in node.targets):node.value=ast.Constant('PIN')
        check('runner AST otherwise identical',ast.dump(old)==ast.dump(new))
check('patch exact two pin substitutions',(d/'proposed-pin-only.patch').read_text()==diff)
workflow=(r/'.github/workflows/native-rtab-grid.yml').read_bytes()
check('RTAB workflow untouched',hashlib.sha256(workflow).hexdigest()==e['workflowSHA256'])
check('RTAB push path remains workflow only',b"paths: ['.github/workflows/native-rtab-grid.yml']" in workflow)
runner=(r/'tools/ci/native-rtab-grid.py').read_text()
check('guard retained before archive acquisition',runner.index('require(sha(script) == INSTALL_SHA')<runner.index('extract_archive(x.download()'))
check('failure receipt is precompile provenance stop',json.loads((d/'failed-run-summary.json').read_text())['error']=='pinned install recipe drift')
print(json.dumps({'scope':'offline source/pin checks, not backend execution','passed':len(checks),'failed':0,'checks':checks},indent=2))

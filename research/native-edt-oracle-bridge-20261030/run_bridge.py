#!/usr/bin/env python3
"""Additive provenance adapter; the historical EDT runner and pins stay immutable.
No algorithm/protocol changes. Native execution only through the original Apple gate.
"""
import argparse, ast, difflib, hashlib, json, pathlib, sys
HERE=pathlib.Path(__file__).resolve().parent
ORACLE='ios/BlindAssistTests/SavedRoomRouteCollisionOracle.swift'
LANE='research/native-floor-import-repair-20261028/edt-navigation-probe'
OLD_ORACLE='30941a88fda667560962fc1baca7f980ba534f613d093b79662b3951e0da5fd9'
NEW_ORACLE='9581e63244f89a5183d752124d306e6808bf114dfc5cb3eecf809b03183e9b53'
OLD_RUNNER='92eb8c0f99e005175fe0da96ff6c521d6430aaa3aec7246b5cf79bc7dcf5460f'
OLD_PINS='3e1f7d07cf3b70cc04ecb6e55694bdc01cca95738f7781e554cfbb1f66aaea3b'
GUARD=b'#if (DEBUG && BLIND_MESH_CANDIDATE_DIAGNOSTICS) || BLIND_COLLISION_ORACLE_TESTS\n'
TRAILER=b'\n#endif\n'
OLD_HEADER=b'/// Test-only, independently queried Apple physics shapes. Not a planner, sensor,\n/// support verifier or physical-output owner. The app target must not include it.\n'
NEW_HEADER=b'/// Shared independent Apple diagnostic kernel. App compilation is DEBUG + explicit\n/// diagnostic flag only; tests compile this same source with their dedicated flag.\n/// Not a planner, sensor, support verifier or physical-output owner.\n'
def digest(b): return hashlib.sha256(b).hexdigest()
def require(ok,message):
    if not ok: raise ValueError(message)
def reverse_oracle(current):
    require(digest(current)==NEW_ORACLE,'Current guarded oracle identity mismatch')
    require(current.startswith(GUARD) and current.endswith(TRAILER),'Exact guard boundary mismatch')
    body=current[len(GUARD):-len(TRAILER)]
    require(body.count(NEW_HEADER)==1,'Exact shared header mismatch')
    restored=body.replace(NEW_HEADER,OLD_HEADER,1)
    require(digest(restored)==OLD_ORACLE,'Historical oracle kernel not byte-identical')
    return restored

def transform_runner(original):
    require(digest(original)==OLD_RUNNER,'Historical runner changed')
    text=original.decode()
    replacements=[
      ("assert path.is_file() and sha(path)==digest,('source pin mismatch',name)",
       "_bridge_verify_pin(path,digest) # explicit reversible oracle provenance"),
      ("assert name in pins and sha(path)==pins[name],('unreviewed runtime input',name)",
       "assert name in pins,('unreviewed runtime input',name)\n        _bridge_verify_pin(path,pins[name])"),
      ("receipt['sourcePins']=pins;save()",
       "receipt['sourcePins']=pins;receipt['sourcePinInterpretation']='historical expectations; current oracle verified by exact reversal';receipt['oracleBridgeProvenance']=_bridge_provenance;save()"),
      ("command(['xcrun','swiftc','-j','1','-num-threads','1','-swift-version','5','-parse-as-library',",
       "command(['xcrun','swiftc','-D','BLIND_COLLISION_ORACLE_TESTS','-j','1','-num-threads','1','-swift-version','5','-parse-as-library',")]
    for old,new in replacements:
        require(text.count(old)==1,'Historical instrumentation site changed')
        text=text.replace(old,new,1)
    # Explicit exact reverse receipt: every other byte of the runner is preserved.
    reversed_text=text
    for old,new in reversed(replacements):
        require(reversed_text.count(new)==1,'Adapter reverse site mismatch')
        reversed_text=reversed_text.replace(new,old,1)
    require(reversed_text.encode()==original,'Runner reversal differs')
    ast.parse(text)
    return text

def verify_packet():
    m=json.loads((HERE/'MANIFEST.json').read_text())
    for name,h in m['files'].items():
        rel=pathlib.PurePosixPath(name)
        require(not rel.is_absolute() and '..' not in rel.parts,'Invalid manifest path')
        require(digest((HERE/name).read_bytes())==h,'Adapter packet changed: '+name)

def prepare(repo):
    original=(repo/LANE/'run_native.py').read_bytes();pins=(repo/LANE/'NATIVE_SOURCE_PINS.json').read_bytes()
    require(digest(pins)==OLD_PINS,'Historical pin manifest changed')
    require(original==(HERE/'baseline/run_native.py.txt').read_bytes(),'Baseline runner snapshot differs')
    require(pins==(HERE/'baseline/NATIVE_SOURCE_PINS.json').read_bytes(),'Baseline pins snapshot differs')
    current=(repo/ORACLE).read_bytes();restored=reverse_oracle(current)
    require(restored==(HERE/'baseline/SavedRoomRouteCollisionOracle.swift.txt').read_bytes(),'Baseline oracle snapshot differs')
    text=transform_runner(original)
    provenance={'schema':1,'historicalRunnerSHA256':OLD_RUNNER,'historicalPinManifestSHA256':OLD_PINS,
      'historicalOracleSHA256':OLD_ORACLE,'currentOracleSHA256':NEW_ORACLE,
      'reversedOracleSHA256':digest(restored),'oracleKernelByteIdentical':True,
      'generatedRunnerSHA256':digest(text.encode()),'runnerReverseByteIdentical':True,
      'compileFlagAdded':'BLIND_COLLISION_ORACLE_TESTS','physicalAuthority':False,
      'algorithmChanged':False,'originalControlsRequired':50,'nativeHookChecksRequired':51,
      'candidateRequestsUnchanged':25,'historicalSourceFilesModified':False}
    def pin(path,expected):
        relative=path.relative_to(repo).as_posix()
        if relative==ORACLE:
            require(expected==OLD_ORACLE,'Unknown historical oracle pin')
            reverse_oracle(path.read_bytes())
        else:
            require(path.is_file() and digest(path.read_bytes())==expected,'Source pin mismatch: '+relative)
    return original,text,provenance,pin

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--verify-only',action='store_true');args=ap.parse_args()
    require(sys.flags.optimize==0,'Historical assertions require ordinary Python execution')
    verify_packet();repo=HERE.parents[1]
    original,text,provenance,pin=prepare(repo)
    if args.verify_only:
        print(json.dumps({'status':'adapter-source-provenance-verified-only','nativeExecuted':False,**provenance},sort_keys=True));return
    # Original runner owns Apple/repository/ref/commit checks, resource limits,
    # complete native controls and failure receipts. No bypass or new executor.
    ns={'__file__':str(repo/LANE/'run_native.py'),'__name__':'__main__',
        '_bridge_verify_pin':pin,'_bridge_provenance':provenance}
    exec(compile(text,str(repo/LANE/'run_native.py'),'exec'),ns)
if __name__=='__main__': main()

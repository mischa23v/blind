#!/usr/bin/env python3
"""Standard-library source/data freeze only. No imports of scientific/native code.
Run after exact extraction and source review; this does not authorize native replay.
"""
import argparse, hashlib, json, pathlib, sys
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--source-dir',type=pathlib.Path,required=True);ap.add_argument('--work-root',type=pathlib.Path,required=True);ap.add_argument('--manifest',type=pathlib.Path,required=True);a=ap.parse_args()
    source=a.source_dir.resolve();work=a.work_root.resolve();source.relative_to(W);work.relative_to(W)
    if a.manifest.resolve()!=H/'SOURCE_PINS.json': raise ValueError('guard requires this protocol SOURCE_PINS.json')
    if work.exists(): raise ValueError('fresh replay output required')
    expected={'textured.obj':'79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1','transformations.json':'c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'}
    for name,digest in expected.items():
        if sha(source/name)!=digest: raise ValueError('wrong source asset: '+name)
    receipt=json.loads((source/'EXTRACTION.json').read_text())
    if receipt['status']!='COMPLETE_EXACT_OBJ_AND_ORIGINAL_POSES' or receipt['selectedBytes']!=3705297: raise ValueError('incomplete extraction')
    inputs={}
    def add(p):
        key=str(p.relative_to(R)) if p.is_relative_to(R) else ('@WORKSPACE@/'+str(p.relative_to(W)) if p.is_relative_to(W) else str(p))
        inputs[key]=sha(p)
    for name in ('extract_source.py','run_comparison.py','freeze.py','run_aggregate.py'):add(H/name)
    for name in ('textured.obj','transformations.json','EXTRACTION.json'):add(source/name)
    inventory=R/'research/conference-replay-input-inventory-20261029'
    for name in ('TARGETS.json','evidence/REGISTRATION_RESULT.json','evidence/MESH_INPUT_RECEIPT.json','evidence/LOOP_FROZEN.json','evidence/REVERSE_FROZEN.json'):add(inventory/name)
    # Reuse exact current Coffee adapter closure; never choose historical alternative binaries.
    coffee=json.loads((R/'research/clearance-first-coffee-source-20261029/SOURCE_PINS.json').read_text())
    suffixes=('libblind_detour.so','native_exclusion.py','blind_detour_exclusion.cpp','clearance_adapter.cpp','planner.py','native025/detour_engine.py','selector.py','fixtures.py')
    for name,digest in coffee['inputs'].items():
        if name.endswith(suffixes) or (name.startswith('/') and ('/numpy-' in name or '/scipy-' in name or name.endswith('/bin/python3.12'))):
            expanded=name.replace('@WORKSPACE@',str(W));p=pathlib.Path(expanded) if expanded.startswith('/') else R/expanded
            if sha(p)!=digest:raise ValueError('current Coffee dependency differs: '+name)
            add(p)
    py=pathlib.Path(sys.executable).resolve()
    if py!=pathlib.Path(coffee['controlsCommand'][0]).resolve(): raise ValueError('use the same Python runtime as the admitted Coffee comparator')
    add(py)
    result={'status':'SOURCE_FROZEN_AWAITING_ROOT_ADMISSION','inputs':inputs,'sourceDirectory':'@WORKSPACE@/'+str(source.relative_to(W)),'workRoot':'@WORKSPACE@/'+str(work.relative_to(W)),'comparisonDirectory':'@WORKSPACE@/'+str(work.relative_to(W))+'/comparison','controlsCommand':[str(py),'@REPO@/research/clearance-first-coffee-source-20261029/fixtures.py'],'comparisonCommand':[str(py),'@PROTOCOL@/run_comparison.py','--pins','@PROTOCOL@/SOURCE_PINS.json','--pins-sha256','@PINS_SHA256@'],'limits':{'cpuSeconds':120,'wallSeconds':180,'observedAggregateRSSBytes':1024**3,'outputBytes':16*1024**2},'runtimeClosureNotHermetic':True,'nativeExecuted':False,'manualExclusionAllowed':False,'physicalAuthority':False}
    with a.manifest.open('x') as f:json.dump(result,f,indent=2);f.write('\n')
    print(json.dumps({'inputs':len(inputs),'manifest':str(a.manifest),'sha256':sha(a.manifest),'nativeExecuted':False}))
if __name__=='__main__':main()

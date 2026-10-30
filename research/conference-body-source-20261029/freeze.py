#!/usr/bin/env python3
"""Stdlib-only source/route freeze; does not execute geometry/native libraries."""
import argparse, hashlib, json, pathlib, sys
from contracts import PROPOSAL_SHA,MESH_SHA,select_routes
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
def sha(p):
    with pathlib.Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--work-root',type=pathlib.Path,required=True);a=ap.parse_args()
    work=a.work_root.resolve();work.relative_to(W)
    if work.exists():raise ValueError('fresh aggregate output required')
    proposal=W/'conference-native-comparison-attempt-002/comparison/PROPOSALS.json'
    guard_receipt=W/'conference-native-comparison-attempt-002/GUARD_RUN/RESULT.json'
    mesh=W/'conference-source-recovery/extracted-001/textured.obj'
    if sha(proposal)!=PROPOSAL_SHA or sha(mesh)!=MESH_SHA:raise ValueError('actual input mismatch')
    actual=json.loads(guard_receipt.read_text())
    if actual['sourceCommit']!='719ec504901639f65767b717f7f7dc817a482640' or actual['status']!='completed-zero-exit':
        raise ValueError('wrong source proposal execution')
    frozen=select_routes(json.loads(proposal.read_text()))
    if frozen['totalEvents']!=13704 or len(frozen['paths'])!=7:raise ValueError('source count changed')
    data=json.dumps(frozen,indent=2)+'\n'
    routes=H/'ROUTES.json'
    if routes.exists():
        if routes.read_text()!=data:raise ValueError('existing route freeze differs')
    else:routes.write_text(data)
    inputs={}
    def add(p):
        key=str(p.relative_to(R)) if p.is_relative_to(R) else '@WORKSPACE@/'+str(p.relative_to(W)) if p.is_relative_to(W) else str(p)
        inputs[key]=sha(p)
    for name in ('contracts.py','schedule_source.py','run_comparison.py','run_controls.py',
                 'test_source_contract.py','test_raw_floor.py','run_aggregate.py','freeze.py','ROUTES.json'):
        add(H/name)
    for p in (proposal,guard_receipt,mesh):add(p)
    scene=R/'research/conference-replay-source-20261029'
    for name in ('run_comparison.py','SOURCE_PINS.json'):add(scene/name)
    inventory=R/'research/conference-replay-input-inventory-20261029'
    for name in ('TARGETS.json','evidence/REGISTRATION_RESULT.json','evidence/MESH_INPUT_RECEIPT.json'):add(inventory/name)
    old=R/'research/coffee-room-journey-recovery-20261029/collision-protocol'
    old_pins=json.loads((old/'SOURCE_PINS.json').read_text())
    suffixes=('oriented_container.py','oriented_ground_container.py','ground_support.py',
              'reference_geometry.py','reference_band_box.py','test_oriented_container.py',
              'test_oriented_ground_container.py')
    for name,digest in old_pins['files'].items():
        if name.startswith('upstream/') and name.endswith(suffixes):
            p=old/name
            if sha(p)!=digest:raise ValueError('frozen upstream differs: '+name)
            add(p)
    # Carry only Python/scientific runtime receipt pins, not native planner/wrapper.
    runtime=json.loads((old/'joint-route-body-candidate/JOINT_ROUTE_RUN_PINS.json').read_text())
    for name,digest in runtime['inputs'].items():
        if name.startswith('/opt/') and any(s in name for s in ('/bin/python3.12','/vtk-','/numpy-','/scipy-')):
            p=pathlib.Path(name)
            if sha(p)!=digest:raise ValueError('runtime receipt differs: '+name)
            add(p)
    py=pathlib.Path(sys.executable).resolve();add(py)
    pins={'status':'SOURCE_FROZEN_AWAITING_ROOT_ADMISSION','inputs':inputs,
      'proposalPath':'@WORKSPACE@/'+str(proposal.relative_to(W)),
      'meshPath':'@WORKSPACE@/'+str(mesh.relative_to(W)),
      'registrationPath':str((inventory/'evidence/REGISTRATION_RESULT.json').relative_to(R)),
      'workRoot':'@WORKSPACE@/'+str(work.relative_to(W)),
      'comparisonDirectory':'@WORKSPACE@/'+str(work.relative_to(W))+'/comparison',
      'sourceControlsCommand':[str(py),'@PROTOCOL@/test_source_contract.py'],
      'controlsCommand':[str(py),'@PROTOCOL@/run_controls.py','--pins','@PROTOCOL@/SOURCE_PINS.json','--pins-sha256','@PINS_SHA256@'],
      'comparisonCommand':[str(py),'@PROTOCOL@/run_comparison.py','--pins','@PROTOCOL@/SOURCE_PINS.json','--pins-sha256','@PINS_SHA256@'],
      'limits':{'cpuSeconds':120,'wallSeconds':180,'observedAggregateRSSBytes':1024**3,'outputBytes':64*1024**2},
      'workerQueryCaps':{'boxes':55000,'triangleCandidates':30000000,'logicalOutputBytes':64*1024**2},
      'sourceEstimate':{'events':13704,'boxQueries':27408,'allSevenSelected':True,
        'sameQueryCostAsCoffeeWorkerWallSeconds':20.206761793000624*27408/6618,
        'estimateNotMeasured':True,'meshDensityAndFloorContactsMayChangeCost':True,'fitWithinBudgetNotEstablished':True},
      'runtimeClosureNotHermetic':True,'nativePlannerExecuted':False,'bodyComparisonExecuted':False,
      'groundExemptedFaceCount':0,'floorContactExclusionMetres':.002,'physicalAuthority':False}
    with (H/'SOURCE_PINS.json').open('x') as f:json.dump(pins,f,indent=2);f.write('\n')
    print(json.dumps({'manifestSHA256':sha(H/'SOURCE_PINS.json'),'sourceEstimate':pins['sourceEstimate'],
                      'sourceOnly':True,'nativeExecuted':False}))
if __name__=='__main__':main()

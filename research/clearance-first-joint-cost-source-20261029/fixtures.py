"""Small authored graphs only; no Coffee/native planner imports or requests."""
import copy
import json
import math
import pathlib
import sys
import contextlib
import io
import tempfile
from unittest.mock import patch
R = pathlib.Path(__file__).resolve().parents[2]
for directory in ('clearance-first-coffee-source-20261029',
                  'clearance-first-coffee-repair-source-20261029',
                  'independent-2d-route-validator-20261029'):
    sys.path.insert(0,str(R/'research'/directory))
from selector import select
from manual_filter import prune, select_with_frozen_cap
from proposal_windows import diagnose_manual_windows
from validator import RADIUS, GUARD
from joint_cost import node_channels, select_joint


def corridor(bottom=-1., top=1., lanes=(-.5,0.,.5), transform=lambda x,z:(x,z)):
    points = [[-2.,0.,0.],[2.,0.,0.]]; adj = [[],[]]; paths = []
    def link(u,v): adj[u].append((v,1.)); adj[v].append((u,1.))
    for z in lanes:
        ids = []
        for i in range(31):
            ids.append(len(points)); points.append([-1.5+i*.1,0.,z]); adj.append([])
        chain = [0]+ids+[1]; paths.append(chain)
        for u,v in zip(chain,chain[1:]): link(u,v)
    native = [2.,2.]+[1.5-abs(z+.5) for z in lanes for _ in range(31)]
    windows = {'bottom':[-1.,1.,bottom-.25,bottom],
               'top':[-1.,1.,top,top+.25]}
    for p in points: p[0],p[2] = transform(p[0],p[2])
    for name,(a,b,c,d) in list(windows.items()):
        q = [transform(x,z) for x,z in ((a,c),(a,d),(b,c),(b,d))]
        windows[name] = [min(x for x,z in q),max(x for x,z in q),
                         min(z for x,z in q),max(z for x,z in q)]
    return points,native,adj,windows,paths


def main():
    passed = []
    def check(name, ok):
        if not ok: raise AssertionError(name)
        passed.append(name)
    def refuses(name, callback):
        try: callback()
        except (ValueError,TypeError): passed.append(name)
        else: raise AssertionError(name)
    transforms = [lambda x,z:(x,z),lambda x,z:(-x,z),
                  lambda x,z:(z+3.,-x-2.),lambda x,z:(-z-4.,x+5.)]
    for k,transform in enumerate(transforms):
        points,native,adj,windows,paths = corridor(transform=transform)
        before = copy.deepcopy((points,native,adj,windows))
        connectors = [[points[0],points[0]],[points[1],points[1]]]
        filtered,_ = prune(points,adj,windows,connectors)
        baseline = select_with_frozen_cap(select,points,native,filtered,0,1,[0,1],6.5)
        result = select_joint(select,points,native,adj,0,1,[0,1],6.5,windows,connectors)
        check(f'transform_{k}_native_only_prefers_hugging_lane',baseline['clearanceGrid']['nodeIDs']==paths[0])
        check(f'transform_{k}_joint_prefers_middle_lane',result['clearanceGrid']['nodeIDs']==paths[1])
        check(f'transform_{k}_whole_route_manual_check',not diagnose_manual_windows(result['clearanceGrid']['pointsXYZ'],windows)['manual_exclusion_contact'])
        check(f'transform_{k}_immutable_inputs',(points,native,adj,windows)==before)
    check('same_endpoints',result['clearanceGrid']['nodeIDs'][::len(result['clearanceGrid']['nodeIDs'])-1]==[0,1])
    check('same_frozen_cap',result['lengthCapMetres']==6.5 and result['clearanceGrid']['lengthMetres']<=6.5)
    check('joint_not_mislabeled_native_wall','minimumResidualWallProxyMetres' not in result['clearanceGrid'])
    check('two_channels_retained',all(key in result['clearanceGrid'] for key in ('nativeErodedWallProxyChannel','manualBodyCircleResidualChannel')))
    check('no_physical_authority',result['physicalAuthority'] is False and result['clearanceGrid']['jointPhysicalClearanceEstablished'] is False)
    check('native_inflation_not_reconstructed',result['rankingChannels']['nativeInflationAddedOrSubtractedMetres']==0.)
    points,native,adj,windows,paths = corridor(top=1.4,lanes=(-.5,0.,.2,.7))
    result = select_joint(select,points,[2.]*len(points),adj,0,1,[0,1],6.5,windows,[])
    check('unequal_gap_prefers_actual_authored_middle',result['clearanceGrid']['nodeIDs']==paths[2])
    # Native proxy remains a separate preference: manual windows far away do
    # not erase the original wall-only preference or invent a shared offset.
    far = {'remote':[20.,21.,20.,21.]}
    result = select_joint(select,points,native,adj,0,1,[0,1],6.5,far,[])
    check('native_channel_still_matters',result['clearanceGrid']['nodeIDs']==paths[0])
    _,manual,joint,_ = node_channels([[0,0,0],[1,0,0]],[.2,.2],{'w':[3.,4.,-1.,1.]})
    check('body_offset_applied_to_manual_only',math.isclose(manual[0],3.-RADIUS) and joint==[.2,.2])
    blocked = select_joint(select,points,native,adj,0,1,[0,1],6.5,windows,[[[0,0,1.5],points[0]]])
    check('requested_connector_hard_veto',blocked['status']=='manualConnectorBlocked')
    over = select_joint(select,points,native,adj,0,1,[0,1],3.,windows,[])
    check('no_budget_widening',over['status']=='manualRepairExceedsFrozenDetourCap')
    p = [[-2,0,0],[2,0,0]]; a = [[(1,1.)],[(0,1.)]]; w = {'barrier':[-.1,.1,-1.,1.]}
    disconnected = select_joint(select,p,[2.,2.],a,0,1,[0,1],10.,w,[])
    check('crossing_edge_cannot_be_rescued_by_cost',disconnected['status']=='disconnected')
    g = RADIUS+GUARD*.5
    near = [[-2,0,1.+g],[2,0,1.+g]]
    check('inside_numerical_guard_refused',select_joint(select,near,[2.,2.],a,0,1,[0,1],10.,w,[])['status']=='disconnected')
    refuses('missing_windows_refused',lambda: node_channels(p,[2.,2.],{}))
    refuses('nonfinite_native_refused',lambda: node_channels(p,[2.,float('nan')],w))
    refuses('nonfinite_node_refused',lambda: node_channels([[0,0,0],[0,float('nan'),0]],[2.,2.],w))
    refuses('degenerate_window_refused',lambda: node_channels(p,[2.,2.],{'w':[0.,0.,1.,2.]}))
    refuses('invalid_frozen_cap_refused',lambda: select_joint(select,p,[2.,2.],a,0,1,[0,1],float('nan'),w,[]))
    import run_controls
    with tempfile.TemporaryDirectory() as directory:
        out = pathlib.Path(directory)/'timeout.json'
        failure = run_controls.subprocess.TimeoutExpired(['authored'],20,output=b'partial',stderr=b'timeout')
        with patch.object(sys,'argv',['run_controls.py',str(out)]), \
             patch.object(run_controls.subprocess,'run',side_effect=failure), \
             contextlib.redirect_stdout(io.StringIO()):
            try: run_controls.main()
            except SystemExit as error:
                if error.code != 1: raise
            else: raise AssertionError('timeout must fail')
        receipt = json.loads(out.read_text())
        check('authored_timeout_preserves_failure_receipt',receipt['status']=='failed' and receipt['timedOut'] is True and receipt['controls']=='partial')
    print(json.dumps({'status':'passed','count':len(passed),'controls':passed,
                      'scope':'authored GEOS/SciPy controls only; no actual Coffee native run',
                      'physicalAuthority':False},indent=2))


if __name__ == '__main__': main()

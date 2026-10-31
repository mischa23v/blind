"""Bounded authored GEOS filter + unchanged SciPy selector controls."""
import json,pathlib,sys
R=pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0,str(R/'research/clearance-first-coffee-source-20261029'))
sys.path.insert(0,str(R/'research/independent-2d-route-validator-20261029'))
from selector import select
from proposal_windows import diagnose_manual_windows
from manual_filter import prune,select_with_frozen_cap


def graph(points,links):
    a=[[]for _ in points]
    for u,v in links:a[u].append((v,1));a[v].append((u,1))
    return a


def main():
    passed=[]
    def check(name,ok):
        if not ok:raise AssertionError(name)
        passed.append(name)
    points=[[-2,0,0],[-2,0,1],[2,0,1],[2,0,0]]
    adj=graph(points,[(0,3),(0,1),(1,2),(2,3)]);windows={'authored':[-.5,.5,-.5,.5]}
    before=[list(row)for row in adj];connectors=[[points[0],points[0]],[points[3],points[3]]]
    filtered,r=prune(points,adj,windows,connectors)
    check('input_graph_unchanged',adj==before)
    check('direct_centerline_crossing_removed',r['directedEdgesRemoved']==2 and (3,1)not in filtered[0])
    repair=select_with_frozen_cap(select,points,[2.]*4,filtered,0,3,[0,3],6.5)
    chain=repair['clearanceGrid']['pointsXYZ']
    check('existing_solver_routes_around',repair['clearanceGrid']['nodeIDs']==[0,1,2,3])
    check('independent_final_no_intersection',not diagnose_manual_windows(chain,windows)['manual_exclusion_contact'])
    check('same_detour_cap',repair['lengthCapMetres']==6.5 and repair['clearanceGrid']['lengthMetres']==6.)
    check('physical_unknown',repair['physicalAuthority'] is False and diagnose_manual_windows(chain,windows)['physical_clearance']=='unknown')
    cap=select_with_frozen_cap(select,points,[2.]*4,filtered,0,3,[0,3],5.)
    check('overlong_repair_refused',cap['status']=='manualRepairExceedsFrozenDetourCap')
    blocked,r=prune(points,adj,windows,[[[0,0,0],points[0]]])
    check('requested_connector_never_exempt',blocked is None and r['status']=='manualConnectorBlocked')
    grazing=[[-2,0,.8],[2,0,.8]]
    f,r=prune(grazing,graph(grazing,[(0,1)]),windows,[])
    check('body_margin_not_only_centerline',r['directedEdgesRemoved']==2 and not f[0])
    d=select_with_frozen_cap(select,grazing,[2.,2.],f,0,1,[0,1],10.)
    check('disconnected_after_prune',d['status']=='disconnected')
    p=[[-2,0,2],[-2,0,2],[2,0,2]]
    f,r=prune(p,graph(p,[(0,1),(1,2)]),windows,[])
    check('zero_length_edges_supported',r['directedEdgesKept']==4)
    try:prune(points,adj,{},[])
    except ValueError:passed.append('empty_windows_refused')
    else:raise AssertionError('empty windows')
    print(json.dumps({'status':'passed','controls':passed,'count':len(passed),
        'scope':'authored manual-window geometry only; no actual Coffee native query','physicalAuthority':False}))

if __name__=='__main__':main()

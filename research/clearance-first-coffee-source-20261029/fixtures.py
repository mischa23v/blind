"""Small pure-SciPy graph controls, not geometric/body validation."""
import json
from selector import select, acceptance


def graph(points, links):
    adj=[[] for _ in points]
    for a,b in links: adj[a].append((b,1));adj[b].append((a,1))
    return adj


def main():
    passed=[]
    def check(name,condition):
        if not condition:raise AssertionError(name)
        passed.append(name)
    # Interior edges distinguish wide-tier routing from mere endpoint weighting.
    p=[[0,0,0],[.1,0,0],[1,0,0],[2,0,0],[2.1,0,0],[1,0,.5]]
    links=[(0,1),(1,2),(2,3),(1,5),(5,3),(3,4)];a=graph(p,links)
    r=select(p,[1.,1.,.1,1.,1.,1.],a,0,4,[0,4])
    check('wider_interior_tier',5 in r['clearanceGrid']['nodeIDs'] and r['clearanceGrid']['thresholdMetres']>0)
    check('reasonable_detour',r['clearanceGrid']['lengthMetres']<=r['lengthCapMetres'])
    r=select(p,[0.,.6,.1,.6,0.,1.],a,0,4,[0,4])
    check('zero_endpoint_does_not_disable_centering',5 in r['clearanceGrid']['nodeIDs'] and r['clearanceGrid']['minimumResidualWallProxyMetres']==0)
    r=select(p,[1.,1.,.1,1.,1.,1.],a,0,4,[0,4],ratio=1.,allowance=0.)
    check('strict_detour_ceiling',r['clearanceGrid']['nodeIDs']==[0,1,2,3,4])
    check('disconnected',select(p,[1.]*6,graph(p,[(0,1)]),0,4,[0,4])['status']=='disconnected')
    # Must initially move away from the goal: no greedy/local potential field.
    u=[[0,0,0],[-1,0,0],[-1,0,2],[2,0,2],[2,0,0]]
    r=select(u,[1.]*5,graph(u,[(0,1),(1,2),(2,3),(3,4)]),0,4,[0,4])
    check('u_shape_global_connectivity',r['clearanceGrid']['nodeIDs']==[0,1,2,3,4])
    # No diagonal/corner connection supplied: solver must not invent one.
    q=[[0,0,0],[1,0,1],[2,0,0]]
    check('no_invented_corner_cut',select(q,[1.]*3,graph(q,[(0,1)]),0,2,[0,2])['status']=='disconnected')
    q=[[0,0,0],[0,0,0],[1,0,0]]
    r=select(q,[1.]*3,graph(q,[(0,1),(1,2)]),0,2,[0,2])
    check('coincident_anchor_zero_edge',r['clearanceGrid']['nodeIDs']==[0,1,2] and r['clearanceGrid']['lengthMetres']==1.)
    r=select(p,[1.]*6,a,0,4,[0,4,2,5])
    check('other_anchors_not_shortcuts',r['status']=='disconnected')
    valid=select(q,[1.]*3,graph(q,[(0,1),(1,2)]),0,2,[0,2])
    kwargs=dict(endpoint_association=True,swept_body=True,swept_margin=True,
                full_footprint_support=True,observed_coverage=True,fresh_depth_veto=True)
    for field in kwargs:
        for bad in (False,None):
            changed=dict(kwargs);changed[field]=bad
            check(field+'_'+str(bad)+'_veto',not acceptance(valid,**changed)['sourceModelAccepted'])
    check('empty_candidate_veto',not acceptance({},**kwargs)['sourceModelAccepted'])
    check('disconnected_candidate_veto',not acceptance({'status':'disconnected'},**kwargs)['sourceModelAccepted'])
    for name,change in [('nan_policy',{'ratio':float('nan')}),('invalid_start',{'start':-1})]:
        args=dict(points=q,clearance=[1.]*3,adj=graph(q,[(0,1),(1,2)]),start=0,goal=2,anchor_nodes=[0,2]);args.update(change)
        try:select(**args)
        except ValueError:passed.append(name)
        else:raise AssertionError(name)
    dup=graph(q,[(0,1),(0,1),(1,2)])
    try:select(q,[1.]*3,dup,0,2,[0,2])
    except ValueError:passed.append('duplicate_edge_refused')
    else:raise AssertionError('duplicate edge')
    print(json.dumps({'status':'passed','controls':passed,'count':len(passed),
        'scope':'pure graph/control adapter only; not geometric collision/support tests','physicalAuthority':False}))

if __name__=='__main__':main()

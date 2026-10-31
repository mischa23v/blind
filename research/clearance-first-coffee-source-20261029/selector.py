"""Source-only candidate ranking, not a full-body planner or safety authority.

SciPy owns graph search. Domain adapter supplies geometry and validation.
No imports/native execution are permitted until the outer run is admitted.
"""
import numpy as np
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra


def select(points, clearance, adj, start, goal, anchor_nodes,
           *, ratio=1.5, allowance=.5):
    """Return proposals; all distances are residual NAVMESH-wall proxies.

    Threshold only optimizes edges not incident on start/goal. Those connector
    edges remain present, measured and subject to the unchanged hard validator.
    Every other anchor is removed to prevent endpoint shortcuts.
    """
    p=np.asarray(points,float); c=np.asarray(clearance,float); n=len(p)
    if (p.shape!=(n,3) or c.shape!=(n,) or not np.isfinite(p).all()
            or not np.isfinite(c).all() or np.any(c<0) or n>100010
            or not np.isfinite([ratio,allowance]).all() or ratio<1 or allowance<0
            or len(adj)!=n):
        raise ValueError('invalid graph or policy')
    if any(not isinstance(i,(int,np.integer)) or not 0<=i<n for i in [start,goal,*anchor_nodes]) or start==goal:
        raise ValueError('invalid endpoint indices')
    excluded=set(anchor_nodes)-{start,goal}; edges=[]; seen=set()
    for u, row in enumerate(adj):
        if u in excluded: continue
        for v,_ in row:
            if not isinstance(v,(int,np.integer)) or not 0<=v<n or v==u or (u,v) in seen:
                raise ValueError('invalid/duplicate edge')
            seen.add((u,v))
            if v in excluded: continue
            length=float(np.linalg.norm(p[v]-p[u]))
            # This lower estimate is a diagnostic proxy, not proof that Detour
            # distance over layered/filtered navmesh is globally Lipschitz.
            proxy=max(0.,min(c[u],c[v])-length*.5)
            edges.append((u,v,length,proxy,u in (start,goal) or v in (start,goal)))
    if len(edges)>900000: raise ValueError('edge budget')
    def solve(threshold, weighted):
        chosen=[e for e in edges if e[4] or e[3]+1e-12>=threshold]
        rows=[e[0] for e in chosen]; cols=[e[1] for e in chosen]
        weights=[e[2]*(1+(.30/(e[3]+.05))**2 if weighted else 1) for e in chosen]
        graph=csr_matrix((weights,(rows,cols)),shape=(n,n))
        dist,pred=dijkstra(graph,directed=True,indices=start,return_predecessors=True)
        if not np.isfinite(dist[goal]): return None
        ids=[goal]
        for _ in range(n):
            if ids[-1]==start: break
            prev=int(pred[ids[-1]])
            if prev<0: raise RuntimeError('broken predecessor chain')
            ids.append(prev)
        else: raise RuntimeError('predecessor cycle')
        ids=ids[::-1]; lookup={(e[0],e[1]):e for e in chosen}
        used=[lookup[a,b] for a,b in zip(ids,ids[1:])]
        return {'nodeIDs':ids,'lengthMetres':sum(e[2] for e in used),
                'minimumResidualWallProxyMetres':min(e[3] for e in used),
                'interiorMinimumResidualWallProxyMetres':min((e[3] for e in used if not e[4]),default=None),
                'clearanceExposureCost':sum(e[2]*(1+(.30/(e[3]+.05))**2) for e in used),
                'thresholdMetres':threshold,'weighted':weighted}
    baseline=solve(0.,False)
    if baseline is None: return {'status':'disconnected','physicalAuthority':False}
    cap=baseline['lengthMetres']*ratio+allowance
    # Fixed, preregistered 2.5 cm tiers, not an exact continuous widest-path claim.
    best=baseline; tier=0.
    for threshold in np.arange(.025,1.50001,.025):
        candidate=solve(float(threshold),False)
        if candidate is None or candidate['lengthMetres']>cap+1e-9: break
        best=candidate; tier=float(threshold)
    centered=solve(tier,True)
    if centered is not None and centered['lengthMetres']<=cap+1e-9: best=centered
    # No shortcutting/string pulling: it could undo the clearance improvement.
    baseline['pointsXYZ']=p[baseline['nodeIDs']].tolist()
    best['pointsXYZ']=p[best['nodeIDs']].tolist()
    return {'status':'proposalOnlyAwaitingHardValidation','distanceGrid':baseline,
            'clearanceGrid':best,'lengthCapMetres':cap,
            'hardBodyValidation':'notEstablished','fullFootprintSupport':'notEstablished',
            'physicalAuthority':False}


def acceptance(candidate, *, endpoint_association, swept_body, swept_margin,
               full_footprint_support, observed_coverage, fresh_depth_veto):
    """No unknown/no-hit result may silently become a pass. Not live admission."""
    valid_candidate=(isinstance(candidate,dict) and
                     candidate.get('status')=='proposalOnlyAwaitingHardValidation' and
                     len(candidate.get('clearanceGrid',{}).get('pointsXYZ',[]))>=2)
    checks=(endpoint_association,swept_body,swept_margin,full_footprint_support,
            observed_coverage,fresh_depth_veto)
    return {'sourceModelAccepted':valid_candidate and all(value is True for value in checks),
            'physicalAuthority':False,'candidate':candidate}

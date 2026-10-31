"""Offline manual-window graph pruning; GEOS predicate, no search algorithm.

Conservative orientation-independent body half-diagonal + separate .15m margin.
Manual diagnostic windows are not measured table boundaries or source coverage.
"""
import math
from validator import GEOS,polygon,coords,RADIUS,GUARD


def prune(points,adj,windows,connectors):
    if len(points)!=len(adj) or len(points)>100010:raise ValueError('graph bound')
    g=GEOS()
    try:
        shapes=[(name,polygon(g,[[a,c],[b,c],[b,d],[a,d]]))
                for name,(a,b,c,d) in windows.items()]
        if not shapes:raise ValueError('empty manual exclusion evidence')
        count=0
        def check(a,b):
            nonlocal count
            a=[float(a[0]),float(a[2])];b=[float(b[0]),float(b[2])]
            coords([a,b]);count+=1
            if count>450020:raise ValueError('GEOS query budget')
            geom=g.geometry('POINT('+coords([a])+')' if a==b else 'LINESTRING('+coords([a,b])+')')
            try:
                minimum=min(g.distance(geom,s)for _,s in shapes)
                return minimum>RADIUS+GUARD,minimum
            finally:
                if g.owned[-1]!=geom:raise RuntimeError('geometry ownership changed')
                g.owned.pop();g.free(g.ctx,geom)
        connector_checks=[]
        for a,b in connectors:
            clear,d=check(a,b);connector_checks.append({'manualNoIntersection':clear,'distanceMetres':d})
        if not all(c['manualNoIntersection']for c in connector_checks):
            return None,{'status':'manualConnectorBlocked','connectorChecks':connector_checks,'physicalAuthority':False}
        result=[[]for _ in points];cache={};removed=kept=0
        for u,row in enumerate(adj):
            for v,cost in row:
                if not isinstance(v,int)or not 0<=v<len(points):raise ValueError('bad edge')
                key=tuple(sorted((u,v)))
                if key not in cache:cache[key]=check(points[u],points[v])[0]
                if cache[key]:result[u].append((v,cost));kept+=1
                else:removed+=1
        return result,{'status':'manualEdgesPruned','directedEdgesKept':kept,
            'directedEdgesRemoved':removed,'uniqueEdgeQueries':len(cache),
            'connectorChecks':connector_checks,'bodyCircumscribedRadiusPlusMarginMetres':RADIUS,
            'numericalGuardMetres':GUARD,'scope':'MANUAL_DIAGNOSTIC_EXCLUSIONS_NOT_MEASURED_TABLES',
            'physicalAuthority':False}
    finally:g.close()


def select_with_frozen_cap(select,points,clearance,adj,start,goal,anchors,cap):
    """Reuse existing selector twice; keep pre-filter detour budget unchanged."""
    if not math.isfinite(cap)or cap<=0:raise ValueError('invalid frozen cap')
    shortest=select(points,clearance,adj,start,goal,anchors,ratio=1.,allowance=0.)
    if shortest['status']=='disconnected':return shortest
    length=shortest['distanceGrid']['lengthMetres']
    if length>cap:return {'status':'manualRepairExceedsFrozenDetourCap','shortestFilteredLengthMetres':length,'lengthCapMetres':cap,'physicalAuthority':False}
    result=select(points,clearance,adj,start,goal,anchors,ratio=1.,allowance=cap-length)
    if result.get('clearanceGrid',{}).get('lengthMetres',0)>cap+1e-9:raise RuntimeError('frozen cap violated')
    result['detourPolicy']='same pre-filter 1.5*shortest+.5m cap; internal ratio=1 realizes that fixed cap'
    return result

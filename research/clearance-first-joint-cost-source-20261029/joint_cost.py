"""Two-channel ranking adapter for the unchanged SciPy selector, not authority.

Native channel: distance to the already-eroded NAVMESH boundary (proxy only).
Manual channel: GEOS point/window distance minus circumscribed body+margin.
The minimum is a ranking preference, NOT one physical clearance measurement.
Never add native erosion back, or subtract body inflation from native distance.
"""
import copy
import math
from validator import GEOS, polygon, coords, RADIUS, GUARD
from manual_filter import prune, select_with_frozen_cap


def node_channels(points, native_wall_proxy, windows):
    if len(points) != len(native_wall_proxy) or not 2 <= len(points) <= 100010:
        raise ValueError('invalid node count')
    if not isinstance(windows, dict) or not 1 <= len(windows) <= 16:
        raise ValueError('missing or excessive manual exclusions')
    if len(points)*len(windows) > 450020:
        raise ValueError('GEOS point-distance budget')
    native = [float(value) for value in native_wall_proxy]
    if any(not math.isfinite(value) or value < 0 for value in native):
        raise ValueError('invalid native wall proxy')
    xz = []
    for p in points:
        if len(p) != 3 or any(not math.isfinite(float(v)) for v in p):
            raise ValueError('invalid node coordinates')
        q = [float(p[0]), float(p[2])]; coords([q]); xz.append(q)
    rectangles = []
    for bounds in windows.values():
        if len(bounds) != 4 or any(not math.isfinite(float(v)) for v in bounds):
            raise ValueError('invalid manual rectangle')
        a,b,c,d = [float(v) for v in bounds]
        if a >= b or c >= d: raise ValueError('degenerate manual rectangle')
        q = [[a,c],[b,c],[b,d],[a,d]]; coords(q); rectangles.append(q)
    g = GEOS()
    try:
        shapes = [polygon(g, q) for q in rectangles]
        manual = []
        for q in xz:
            point = g.geometry('POINT('+coords([q])+')')
            try:
                manual.append(min(g.distance(point, shape) for shape in shapes)-RADIUS)
            finally:
                if g.owned[-1] != point: raise RuntimeError('geometry ownership changed')
                g.owned.pop(); g.free(g.ctx, point)
        # Nodes inside an exclusion can remain in the input graph, but the hard
        # whole-segment filter removes their edges. Zero is only a rank floor.
        joint = [max(0., min(a,b)) for a,b in zip(native,manual)]
        return native, manual, joint, {
            'status':'twoSeparateChannelsForRankingOnly',
            'geosVersion':g.version, 'pointDistanceQueries':len(points)*len(shapes),
            'manualBodyCirclePlusMarginMetres':RADIUS,
            'hardFilterNumericalGuardMetres':GUARD,
            'nativeInflationAddedOrSubtractedMetres':0.,
            'jointMeaning':'min(native-eroded-boundary proxy, manual body-circle residual); not physical midpoint',
            'physicalAuthority':False}
    finally:
        g.close()


def annotate(result, points, native, manual):
    """Rename legacy selector labels so joint ranking is never called wall data."""
    result = copy.deepcopy(result)
    for name in ('distanceGrid', 'clearanceGrid'):
        if name not in result: continue
        arm = result[name]
        arm['minimumJointRankingProxyMetres'] = arm.pop('minimumResidualWallProxyMetres')
        arm['interiorMinimumJointRankingProxyMetres'] = arm.pop('interiorMinimumResidualWallProxyMetres')
        arm['jointExposureCost'] = arm.pop('clearanceExposureCost')
        arm['jointRankingThresholdMetres'] = arm.pop('thresholdMetres')
        ids = arm['nodeIDs']; edges = list(zip(ids,ids[1:]))
        def channel(values):
            estimates = [max(0., min(values[u],values[v])-math.dist(points[u],points[v])*.5)
                         for u,v in edges]
            interior = [value for (u,v),value in zip(edges,estimates)
                        if u not in (ids[0],ids[-1]) and v not in (ids[0],ids[-1])]
            return {'minimumEdgeLowerEstimateMetres':min(estimates),
                    'interiorMinimumEdgeLowerEstimateMetres':min(interior,default=None)}
        arm['nativeErodedWallProxyChannel'] = channel(native)
        arm['manualBodyCircleResidualChannel'] = channel(manual)
        arm['jointPhysicalClearanceEstablished'] = False
    result['costPolicy'] = 'unchanged selector tiers/exposure on two-channel minimum; ranking only'
    result['physicalAuthority'] = False
    return result


def select_joint(select, points, native_wall_proxy, adj, start, goal, anchors,
                 cap, windows, connectors):
    """No endpoint changes, new search, smoothing or route-specific constants."""
    native,manual,joint,channels = node_channels(points,native_wall_proxy,windows)
    filtered,filter_receipt = prune(points,adj,windows,connectors)
    result = ({'status':'manualConnectorBlocked','physicalAuthority':False}
              if filtered is None else
              select_with_frozen_cap(select,points,joint,filtered,start,goal,anchors,cap))
    result = annotate(result,points,native,manual)
    result['rankingChannels'] = channels
    result['edgeFilter'] = filter_receipt
    return result

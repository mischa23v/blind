"""Offline independent 2D rejection/diagnostic adapter; never live guidance."""
import ctypes as C
import ctypes.util
import math

HEIGHT = 1.60
WIDTH = .45
DEPTH = .30
BODY_RADIUS = math.hypot(WIDTH, DEPTH) / 2
MARGIN = .15
RADIUS = BODY_RADIUS + MARGIN
GUARD = 1e-8  # metres; fixed conservative rejection guard, not an accuracy proof

class GEOS:
    def __init__(self):
        self.lib = C.CDLL(ctypes.util.find_library('geos_c'))
        def bind(name, args, result):
            f = getattr(self.lib, name); f.argtypes = args; f.restype = result
            return f
        p = C.c_void_p
        self.init = bind('GEOS_init_r', [], p)
        self.finish = bind('GEOS_finish_r', [p], None)
        self.reader_new = bind('GEOSWKTReader_create_r', [p], p)
        self.reader_free = bind('GEOSWKTReader_destroy_r', [p,p], None)
        self.read = bind('GEOSWKTReader_read_r', [p,p,C.c_char_p], p)
        self.free = bind('GEOSGeom_destroy_r', [p,p], None)
        self.valid = bind('GEOSisValid_r', [p,p], C.c_byte)
        self.dist = bind('GEOSDistance_r', [p,p,p,C.POINTER(C.c_double)], C.c_int)
        self.contains = bind('GEOSContains_r', [p,p,p], C.c_byte)
        self.boundary = bind('GEOSBoundary_r', [p,p], p)
        self.version = bind('GEOSversion', [], C.c_char_p)().decode()
        self.ctx = self.init(); self.reader = self.reader_new(self.ctx); self.owned = []
    def geometry(self, wkt):
        g = self.read(self.ctx,self.reader,wkt.encode())
        if not g: raise ValueError('GEOS rejected WKT')
        self.owned.append(g)
        if self.valid(self.ctx,g) != 1: raise ValueError('invalid geometry')
        return g
    def distance(self,a,b):
        value = C.c_double()
        if self.dist(self.ctx,a,b,C.byref(value)) != 1 or not math.isfinite(value.value):
            raise ValueError('distance failed')
        return value.value
    def close(self):
        for g in self.owned: self.free(self.ctx,g)
        self.reader_free(self.ctx,self.reader); self.finish(self.ctx)


def coords(points):
    if not isinstance(points,list) or not points: raise ValueError('empty coordinates')
    for p in points:
        if not isinstance(p,list) or len(p)!=2 or any(isinstance(v,bool) or not isinstance(v,(int,float)) or not math.isfinite(v) or abs(v)>1e6 for v in p):
            raise ValueError('invalid metric coordinates')
    return ','.join(f'{p[0]:.17g} {p[1]:.17g}' for p in points)


def polygon(g, points):
    if len(points)<3: raise ValueError('polygon needs three vertices')
    closed = points if points[0]==points[-1] else points+[points[0]]
    return g.geometry('POLYGON(('+coords(closed)+'))')


def validate(route, scene, now):
    """Segment indices are zero-based; x,z metres. No repair or path generation."""
    result = dict(status='unknown', live_guidance_allowed=False, blockers=[], segments=[],
                  profile=dict(width=WIDTH,depth=DEPTH,height=HEIGHT,body_radius=BODY_RADIUS,margin=MARGIN,
                               sweep_radius=RADIUS,numerical_guard=GUARD),
                  detour_contract='External maintained planner proposes; recheck here AND in 3D before acceptance.')
    g = None
    try:
        points = route['points']; coords(points)
        if len(points)<2: raise ValueError('route needs at least two points')
        if not scene.get('frame') or route.get('frame')!=scene['frame']: result['blockers'].append('frame_mismatch_or_missing')
        if not scene.get('revision') or route.get('revision')!=scene['revision']: result['blockers'].append('revision_mismatch_or_missing')
        if scene.get('units')!='metres': result['blockers'].append('unsupported_units')
        age = now-scene['captured_at']; limit=scene['max_age_seconds']
        if not all(math.isfinite(x) for x in [now,age,limit]) or limit<=0 or age<0 or age>limit: result['blockers'].append('not_current')
        if scene.get('source_kind')!='authored_fixture': result['blockers'].append('non_authored_geometry_not_verified_by_this_demo')
        for layer in ('floor','body','head'):
            provenance = scene.get('projection',{}).get(layer,{})
            if (provenance.get('coverage')!='complete' or not provenance.get('source') or
                provenance.get('frame')!=scene.get('frame') or provenance.get('revision')!=scene.get('revision')):
                result['blockers'].append(layer+'_projection_unknown')
        # Do not evaluate geometries in incompatible frames/revisions/times.
        if any(x in result['blockers'] for x in ('frame_mismatch_or_missing','revision_mismatch_or_missing','unsupported_units','not_current')): return result
        g=GEOS(); result['geos_version']=g.version
        coverage=polygon(g,scene['coverage'])
        edge=g.boundary(g.ctx,coverage)
        if not edge: raise ValueError('coverage boundary failed')
        g.owned.append(edge)
        obstacles=[]
        for ob in scene['obstacles']:
            if ob.get('source_kind')!='authored_fixture': result['blockers'].append('obstacle_'+ob['id']+'_not_measured_or_authored_fixture')
            if ob.get('layer') not in ('floor','body','head'): result['blockers'].append('obstacle_'+ob['id']+'_layer_unknown')
            obstacles.append((ob['id'],polygon(g,ob['polygon'])))
        for i,(a,b) in enumerate(zip(points,points[1:])):
            line=g.geometry(('POINT('+coords([a])+')') if a==b else ('LINESTRING('+coords([a,b])+')'))
            covered = g.contains(g.ctx,coverage,line)==1 and g.distance(line,edge)>RADIUS+GUARD
            if not covered: result['blockers'].append('segment_'+str(i)+'_whole_body_coverage_unknown')
            hits=[]; distances=[]
            for ident,ob in obstacles:
                d=g.distance(line,ob); distances.append(d)
                if d<=RADIUS+GUARD: hits.append(dict(obstacle_id=ident,distance_metres=d,whole_body_margin_deficit_metres=max(0,RADIUS-d)))
            result['segments'].append(dict(index=i,start=a,end=b,coverage_known=covered,contacts=hits,
                minimum_clearance_after_body_and_margin_metres=min(distances)-RADIUS if distances else None))
        result['status']='rejected' if any(s['contacts'] for s in result['segments']) else ('unknown' if result['blockers'] else 'clear_in_authored_fixture_only')
    except (KeyError,TypeError,ValueError,OverflowError) as exc:
        result['status']='unknown'; result['blockers'].append('invalid_input:'+str(exc))
    finally:
        if g: g.close()
    return result

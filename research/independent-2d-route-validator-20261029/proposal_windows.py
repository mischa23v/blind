"""Prepared adapter for externally generated proposals; no route search.
Source-only at preparation; distinct from executed check.py evidence.
"""
from validator import GEOS, polygon, coords, RADIUS, GUARD

def diagnose_manual_windows(points_xyz, windows):
    """windows maps ID to [xmin,xmax,zmin,zmax]; these are NOT measured tables."""
    g=GEOS()
    try:
        shapes=[]
        for name,(xmin,xmax,zmin,zmax) in windows.items():
            shapes.append((name,polygon(g,[[xmin,zmin],[xmax,zmin],[xmax,zmax],[xmin,zmax]])))
        pts=[[p[0],p[2]] for p in points_xyz]
        coords(pts)
        if len(pts)<2: raise ValueError('proposal has fewer than two points')
        segments=[]
        for i,(a,b) in enumerate(zip(pts,pts[1:])):
            geom=g.geometry('POINT('+coords([a])+')' if a==b else 'LINESTRING('+coords([a,b])+')')
            distances=[{'id':name,'distance_metres':g.distance(geom,shape)} for name,shape in shapes]
            for d in distances:
                d['body_margin_contact']=d['distance_metres']<=RADIUS+GUARD
                d['clearance_after_body_and_margin_metres']=d['distance_metres']-RADIUS
            segments.append({'index_zero_based':i,'windows':distances})
        return {'manual_exclusion_contact':any(d['body_margin_contact'] for s in segments for d in s['windows']),
                'physical_clearance':'unknown','live_guidance_allowed':False,
                'scope':'MANUAL_DIAGNOSTIC_EXCLUSIONS_NOT_MEASURED_TABLES','segments':segments}
    finally: g.close()

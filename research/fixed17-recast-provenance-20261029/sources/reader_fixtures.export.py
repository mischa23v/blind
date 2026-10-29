# EXPORT VARIANT, NOT EXECUTED. Uses withheld private fixture configuration.
import private_fixture_config as fixture
"""Prospective small fixtures; execute only inside the admitted one-shot budget."""
import numpy as np

def run(compact,raster):
    checks=[]
    # All expected square distances are analytic; no reference mesh is loaded.
    for side in (1,9,15):
        rows=[]
        for z in range(40,40+side):
            for x in range(40,40+side):
                d=2*min(x-40,z-40,39+side-x,39+side-z)
                rows.append([x,z,10,11,63,63,63,63 if d>=12 else 0,0])
        a=np.array(rows,np.int32);got,events=compact(a)
        expected=[2*min(r[0]-40,r[1]-40,39+side-r[0],39+side-r[1])for r in rows]
        if got[:,6].tolist()!=expected:raise RuntimeError('fixture-square-distance')
        checks.append({'squareSide':side,'allAnalyticDistancesMatch':True})
    # Two stacked walkable spans must remain distinct; null ceiling must survive restoration.
    a=np.array([[40,40,10,11,63,63,63,0,0],[40,40,100,101,63,63,63,0,0],
                [41,40,10,11,63,0,0,0,0],[41,40,30,31,0,0,0,0,0]],np.int32)
    got,_=compact(a)
    if got[:,2].tolist()!=[11,101] or got[:,3].tolist()!=[89,255]:raise RuntimeError('fixture-null-multilayer')
    # Fixed native cell, one upward and reversed copy. Full bounds stay unchanged.
    x=np.float32(fixture.synthetic_triangle_x)
    z=np.float32(fixture.synthetic_triangle_z)
    v=np.array([[x+.005,-1.3,z+.005],[x+.005,-1.3,z+.035],[x+.035,-1.3,z+.005]],np.float32)
    output,marks=raster(np.array([v,v[[0,2,1]]],np.float32))
    if marks.tolist()!=[63,0]:raise RuntimeError('fixture-signed-winding')
    union=output[(output[:,0]==-1)&(output[:,1]==fixture.synthetic_cell_ordinal)]
    if len(union)!=1 or union[0,4]!=63:raise RuntimeError('fixture-merge-walkable-null')
    checks.append({'stackedAndNullRestoration':True,'signedWinding':True,'mergedWalkableNull':True})
    return checks

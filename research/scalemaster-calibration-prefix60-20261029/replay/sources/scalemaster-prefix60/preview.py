"""Private, fixed-view preview of native geometry; no semantic floor/stair labels."""
import json,sys
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d.art3d import Poly3DCollection


def main():
    out=Path(sys.argv[1]);result=json.loads((out/'RESULT.json').read_text())
    with np.load(out/'geometry-for-preview.npz',allow_pickle=False) as data:
        vertices=data['vertices'];triangles=data['triangles'];points=data['endpoints'];trajectory=data['trajectory']
    # Deterministic rendering-only subsets; native mesh/endpoint ledger unchanged.
    triidx=np.linspace(0,len(triangles)-1,min(15000,len(triangles)),dtype=int) if len(triangles) else []
    vidx=np.linspace(0,len(vertices)-1,min(30000,len(vertices)),dtype=int) if len(vertices) else []
    pidx=np.linspace(0,len(points)-1,min(30000,len(points)),dtype=int) if len(points) else []
    fig=plt.figure(figsize=(12,9),layout='constrained')
    ax=fig.add_subplot(2,2,1,projection='3d')
    if len(triidx):
        ax.add_collection3d(Poly3DCollection(vertices[triangles[triidx]],facecolor='#83a9bc',edgecolor='none',alpha=.75))
    if len(pidx):ax.scatter(*points[pidx].T,s=.3,c='#c57835',alpha=.2)
    ax.plot(*trajectory.T,c='#a22459',linewidth=1.5)
    sets=[trajectory]+([vertices] if len(vertices) else [])+([points] if len(points) else [])
    bounds=np.vstack([np.stack((p.min(axis=0),p.max(axis=0))) for p in sets])
    lo=bounds.min(axis=0);hi=bounds.max(axis=0);span=max(float((hi-lo).max()),.1);center=(lo+hi)/2
    for axis,k in [('x',0),('y',1),('z',2)]:
        getattr(ax,'set_'+axis+'lim')(center[k]-span*.55,center[k]+span*.55)
        getattr(ax,'set_'+axis+'label')(axis.upper()+' (conditional m)')
    ax.view_init(elev=25,azim=-60);ax.set_title('Native TSDF + observed endpoints\nFixed arbitrary world-axis view')
    for n,(a,b) in enumerate(((0,1),(0,2),(1,2)),2):
        panel=fig.add_subplot(2,2,n)
        if len(vidx):panel.scatter(vertices[vidx,a],vertices[vidx,b],s=.35,c='#4e8dab',label='native mesh vertices')
        if len(pidx):panel.scatter(points[pidx,a],points[pidx,b],s=.2,c='#c57835',alpha=.3,label='observed endpoint centroids')
        panel.plot(trajectory[:,a],trajectory[:,b],c='#a22459',linewidth=1,label='raw-pose path')
        panel.set(xlabel='XYZ'[a]+' (conditional m)',ylabel='XYZ'[b]+' (conditional m)')
        panel.set_aspect('equal',adjustable='datalim');panel.grid(alpha=.2)
        if n==2:panel.legend(markerscale=5,fontsize=7,loc='best')
    fig.suptitle('Stairs_02 fixed frames 0–59 — depth-only Open3D replay\n'
                 'Inferred calibration; no independent GT. Missing geometry is UNKNOWN, not free floor.',fontsize=12)
    fig.savefig(out/'private-geometry-preview.png',dpi=120);plt.close(fig)
    with (out/'PREVIEW.json').open('x') as f:
        json.dump({'source':'actual native output; not generated illustration','mesh_vertices':len(vertices),
                   'mesh_triangles':len(triangles),'rendered_triangle_subset':len(triidx),
                   'rendered_vertex_subset':len(vidx),'rendered_endpoint_subset':len(pidx),
                   'native_geometry_modified':False,'world_axes_gravity_verified':False,
                   'view_selection':'fixed elev25 azim-60; orthogonal XY/XZ/YZ panels, no visual frame selection',
                   'no_surface':result['status']=='completed_no_surface','private':True},f,indent=2)
    print('preview_completed')


if __name__=='__main__':main()

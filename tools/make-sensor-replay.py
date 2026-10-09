"""Generate labelled ideal geometry and conditional replays of real stair point clouds.
Real data uses an explicitly ASSUMED gravity convention and three camera heights.
It is a sensitivity experiment, not an independently calibrated accuracy benchmark.
"""
import json
from pathlib import Path
import numpy as np
from plyfile import PlyData

root = Path(__file__).resolve().parents[1]
out = root / "artifacts" / "stairs"
out.mkdir(parents=True, exist_ok=True)
cases = []
def add(name, group, expected, points, height=1.2, assumptions="Ideal synthetic geometry; known calibration, no physical sensor model."):
    cases.append(dict(id=name, group=group, expected=expected, camera=dict(x=0,y=height,z=0),
                      forward=dict(x=0,y=0,z=-1), floor=0, points=np.round(points,5).tolist(), assumptions=assumptions))
x,z = np.meshgrid(np.arange(-0.36,0.37,0.04), np.arange(0.31,2.2,0.04))
base = np.column_stack([x.ravel(),np.zeros(x.size),-z.ravel()])
for cm in [4,8,10,12,18,25,40]:
    for sign in [-1,1]:
        for distance in [0.7,1.2,1.8]:
            points = base.copy(); points[-points[:,2]>=distance,1] = sign*cm/100
            # Target requirement is a specific warning for every nonzero step.
            # This deliberately exposes thresholds/range limitations instead of
            # labelling unknown as a successful specific detection.
            add(f"{'up' if sign>0 else 'down'}-{cm}cm-{distance}m", "synthetic-step",
                "obstacle" if sign>0 else "drop", points)
add("level-floor", "synthetic-control", "observing", base)
add("no-returns", "synthetic-unknown", "uncertain", np.empty((0,3)))
add("missing-middle-floor", "synthetic-unknown", "uncertain", base[(base[:,2]>-0.9)|(base[:,2]<-1.3)])
for h in [0.12,0.6,1.7]:
    wall=np.array([[a,b,-1.0] for a in np.arange(-0.3,0.31,0.04) for b in np.arange(h,h+0.16,0.03)])
    add(f"room-obstacle-{h}m", "synthetic-obstacle", "overhead" if h>1.5 else "obstacle", np.vstack([base,wall]))

# Human visual labels assigned from the fixed 12 RGB frames before core scoring.
# 112 is an oblique landing: not treated as a confirmed forward drop.
labels = {0:"obstacle",14:"obstacle",28:"drop",42:"obstacle",56:"obstacle",70:"obstacle",
          84:"obstacle",98:"drop",112:"unscored-oblique",126:"drop",140:"drop",153:"drop"}
for i, expected in labels.items():
    v=PlyData.read(out / f"pointcloud_{i}.ply")["vertex"]
    p=np.column_stack([v[k] for k in "xyz"])
    p=p[np.isfinite(p).all(axis=1)]
    # The last three extrinsics values have magnitudes near g and are treated
    # as a gravity-direction candidate. This convention is NOT independently
    # verified by publisher documentation. Report that caveat with every result.
    values=np.loadtxt(out / f"Extrinsics_{i}.txt")
    g=values[-3:]; up=-g/np.linalg.norm(g)
    view=np.array([0.,0.,-1.]); forward=view-up*np.dot(view,up); forward/=np.linalg.norm(forward)
    right=np.cross(forward,up); right/=np.linalg.norm(right)
    p=np.column_stack([p@right,p@up,-p@forward])
    p=p[(np.abs(p[:,0])<0.6)&(-p[:,2]>0.1)&(-p[:,2]<2.5)][::3]
    for height in [0.9,1.2,1.5]:
        world=p.copy();world[:,1]+=height
        add(f"real-{i}-height-{height}","real-stair-sensitivity",expected,world,height,
            "Real D435i points; gravity convention inferred, not verified; camera height assumed; ideal prior calibration; confidence set high; not a validated accuracy score.")
(out / "replay-input.json").write_text(json.dumps(cases,separators=(",",":")),encoding="utf-8")
print(f"Prepared {len(cases)} cases; 12 real frames at 3 assumed heights, plus labelled synthetic tests.")

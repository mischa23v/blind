"""Read-only distances to saved geometry and fixed-envelope accounting.

No map/pose/path changes, no FARO, no modified-body route trial. OctoMap is used
ONLY for its native coordinate-key conversion; saved leaf boxes own geometry.
SciPy cKDTree bounds the exact point-to-axis-aligned-square distance calculation.
"""
from pathlib import Path
import hashlib,json,math,sys,time
import numpy as np
from scipy.spatial import cKDTree
ROOT=Path(__file__).resolve().parent;WS=ROOT.parents[1]
sys.path.insert(0,str(ROOT.parent));from game_model import sha,BODY_RADIUS,MARGIN,HALF_EXTENT
sys.path.insert(0,str(WS/'blind-octomap-reuse-08'));from octomap_engine import OctoMap


def packed(keys):
    k=np.asarray(keys,dtype=np.uint64)
    return (k[:,0]<<32)|(k[:,1]<<16)|k[:,2]


def square_distances(points,centres,side):
    p=np.asarray(points,dtype=float);c=np.asarray(centres,dtype=float)
    if p.ndim!=2 or p.shape[1]!=2 or c.ndim!=2 or c.shape[1]!=2 or not len(c) or not np.isfinite(p).all() or not np.isfinite(c).all() or not 0<side<=1:raise ValueError('invalid square-distance input')
    tree=cKDTree(c);nearest,_=tree.query(p,k=1);result=[]
    # The nearest-centre box is at most nearest metres away. Any centre more
    # than nearest+halfDiagonal away cannot yield a closer box surface.
    for point,d in zip(p,nearest):
        candidates=tree.query_ball_point(point,float(d+side/math.sqrt(2)+1e-10))
        delta=np.maximum(np.abs(c[candidates]-point)-side*.5,0)
        result.append(float(np.hypot(delta[:,0],delta[:,1]).min()))
    return np.asarray(result)


def quantiles(a):
    return {str(q):float(np.quantile(a,q))for q in [0,.25,.5,.75,.95,1]}


def main():
    target=ROOT/'CLEARANCE_CONSERVATISM.json'
    if target.exists():raise ValueError('refuse diagnostic overwrite')
    pins={
        ROOT/'run-01/map/SURFACE.json':'7421a58b88a3f80c0b10501854be6e49ff29a78b0ef51eceeb113a0b36343129',
        ROOT/'run-01/map/SURFACE_EVIDENCE.npz':'c4b80a0305a82fd7dfe1e7de8d8a5da6396634dd8afd832663f5eb31baffdfd8',
        ROOT/'run-01/map/RAW_NATIVE_ASSOCIATIONS.npz':'d425972314a56981909b87ffd64cc0a045bddb8c066eb4c296562ce606595ed5',
        ROOT/'run-01/map/OCTOMAP_LEAVES.npz':'1c3731371fd20c325d3b30e10475796aca96c0eb19a0dcb156af97e0851d8977'}
    for p,digest in pins.items():
        if sha(p)!=digest:raise ValueError('saved geometry changed')
    started=time.monotonic();s=json.loads((ROOT/'run-01/map/SURFACE.json').read_bytes());w=s['width'];h=s['depth'];r=s['resolution'];o=s['origin']
    with np.load(ROOT/'run-01/map/SURFACE_EVIDENCE.npz')as f:
        raw_positive=f['rawObstacle'].copy();missing=f['surfaceMissingSupport'].copy();occupied=f['surfacePositiveOccupied'].copy()
    with np.load(ROOT/'run-01/map/RAW_NATIVE_ASSOCIATIONS.npz')as f:
        raw_index=f['rawIndex'];q=f['nativeQueryIndex']
        if not np.array_equal(q,np.arange(len(q))):raise ValueError('recorded pair/query association changed')
        select=(f['known']==1)&(f['occupied']==1)&raw_positive[raw_index]
        occupied_keys=np.unique(f['nativeKeys'][select],axis=0)
    with np.load(ROOT/'run-01/map/OCTOMAP_LEAVES.npz')as f:leaves=f['xyzSizeProbability'].copy()
    # Use upstream conversion rather than reconstructing key-centre coordinates.
    with OctoMap(.05)as key_converter:leaf_keys=key_converter.keys(leaves[:,:3])
    codes=packed(leaf_keys);order=np.argsort(codes);sorted_codes=codes[order];wanted=packed(occupied_keys);at=np.searchsorted(sorted_codes,wanted)
    if np.any(at>=len(codes))or not np.array_equal(sorted_codes[at],wanted)or np.any(sorted_codes[1:]==sorted_codes[:-1]):raise ValueError('saved native leaf association mismatch')
    selected_leaves=leaves[order[at]]
    if not np.all(selected_leaves[:,3]==.05):raise ValueError('expected unpruned 5 cm native leaves')
    native_xz=np.unique(selected_leaves[:,[0,2]],axis=0)
    eligible=np.array([not c['blocked'] and c['floor']==0 and c['clearance']==1.75 for c in s['cells']])
    def centres(mask):
        index=np.flatnonzero(mask)
        return np.column_stack((o['x']+(index%w+.5)*r,o['z']+(index//w+.5)*r))
    points=centres(eligible)
    distances={'nativeOccupiedPositiveVoxelBoxes':square_distances(points,native_xz,.05),
               'projectedOccupiedSurfaceCells':square_distances(points,centres(occupied),r),
               'missingSupportSurfaceCells':square_distances(points,centres(missing),r)}
    raw_radius=math.hypot(.45,.30)/2;double_radius=math.sqrt(2)*raw_radius;requested=double_radius+.15;eroded=math.ceil(requested/.1)*.1
    stages=[{'stage':'original body circumscribed yaw-independent circle','radius':raw_radius,'diameter':2*raw_radius},
            {'stage':'current square player container circumscribed again by native cylinder','radius':double_radius,'diameter':2*double_radius,'extraRadiusFromDoubleBound':double_radius-raw_radius},
            {'stage':'unchanged declared planning margin','radius':requested,'diameter':2*requested,'addedMargin':.15},
            {'stage':'Recast cell-quantized erosion','radius':eroded,'diameter':2*eroded,'additionalQuantization':eroded-requested}]
    result={'scope':'Read-only offline geometry clearance and representation diagnosis; no alternative route or game outcomes','eligibleCandidateCentres':len(points),
        'nativeOccupiedKeysAssociatedWithPositiveRawHits':len(occupied_keys),'distinctNativeOccupiedHorizontalSquares':len(native_xz),
        'distanceQuantilesModelMetres':{k:quantiles(v)for k,v in distances.items()},
        'distanceMeaning':'Shortest horizontal distance to saved box/cell boundaries. Native boxes selected only by saved upstream occupied flags associated with original positive raw hits; supporting-floor-only keys are not added. These are model distances, not physical or sensor uncertainty guarantees.',
        'envelopeStages':stages,'stationarySwiftRadius':BODY_RADIUS+MARGIN,'nominal2cmStepSwiftRadius':BODY_RADIUS+MARGIN+.01,
        'hypotheticalSingleBoundCylinder':{'radiusBeforeMargin':raw_radius,'unchangedMargin':.15,'requestedRadius':raw_radius+.15,'same10cmRecastErosionRadius':math.ceil((raw_radius+.15)/.1)*.1,
            'status':'Representation proposal only, NOT rerun and NOT a claim that any route would fit','constraint':'It encloses the original declared rectangle at every yaw, but not the larger historical square-container corners. A new independently tested evaluator/container variant would be required; old failures stay unchanged.'},
        'inputs':{str(p.relative_to(ROOT)):digest for p,digest in pins.items()},'sourceSHA256':sha(Path(__file__)),
        'wallSeconds':time.monotonic()-started,'FAROUsed':False,'mapOrBodyChanged':False,'gameEpisodesExecuted':0,'physicalAuthority':False}
    for p,digest in pins.items():
        if sha(p)!=digest:raise ValueError('saved geometry changed after diagnostic')
    target.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':main()

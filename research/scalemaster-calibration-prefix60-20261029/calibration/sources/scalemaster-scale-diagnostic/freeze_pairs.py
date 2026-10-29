"""Metadata-only selection. Must run before extraction/estimation; never opens depth."""
import argparse, csv, hashlib, json, math
from pathlib import Path

def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('poses');ap.add_argument('output');ap.add_argument('--source-freeze',required=True);ap.add_argument('--camera-matrix',required=True);a=ap.parse_args()
    source_freeze=json.loads(Path(a.source_freeze).read_text())
    for name,expected in source_freeze['scripts_sha256'].items():
        if sha(Path(__file__).resolve().parent/name)!=expected:raise ValueError('Source changed after review freeze')
    if sha(a.poses)!=source_freeze['metadata_sha256']['metadata/Stairs_02/odometry.csv']:raise ValueError('Pose metadata changed after review freeze')
    if sha(a.camera_matrix)!=source_freeze['metadata_sha256']['metadata/Stairs_02/camera_matrix.csv']:raise ValueError('Camera matrix changed after review freeze')
    K_raw=[[float(v.strip()) for v in row] for row in csv.reader(open(a.camera_matrix))]
    if len(K_raw)!=3 or any(len(row)!=3 for row in K_raw) or not all(math.isfinite(v) for row in K_raw for v in row):raise ValueError('Invalid camera matrix')
    if K_raw[0][0]<=0 or K_raw[1][1]<=0 or K_raw[2]!=[0.,0.,1.]:raise ValueError('Unsupported camera matrix')
    # Dimensions were previously observed in decoded samples; no new depth read here.
    scale_x,scale_y=256/1920,192/1440
    K_depth=[[v*scale_x for v in K_raw[0]],[v*scale_y for v in K_raw[1]],K_raw[2][:]]
    dst=Path(a.output)
    if dst.exists(): raise SystemExit('Refusing to overwrite a frozen split')
    rows=list(csv.DictReader(open(a.poses),skipinitialspace=True));parsed=[];norm_errors=[]
    for r in rows:
        q=[float(r[k]) for k in ('qx','qy','qz','qw')];n=math.sqrt(sum(v*v for v in q))
        t=float(r['timestamp']);xyz=[float(r[k]) for k in ('x','y','z')]
        if not n or not all(math.isfinite(v) for v in q+[t]+xyz) or abs(n-1)>1e-3:raise ValueError('Invalid/nonfinite pose or quaternion norm deviation>0.001')
        norm_errors.append(abs(n-1));parsed.append((int(r['frame']),t,xyz,[v/n for v in q]))
    if len({r[0] for r in parsed})!=len(parsed) or any(b[1]<=a[1] for a,b in zip(parsed,parsed[1:])):
        raise ValueError('Duplicate IDs/nonmonotonic timestamps')
    pairs=[]
    for bin_id in range(6):
        lo=len(parsed)*bin_id//6;hi=len(parsed)*(bin_id+1)//6;center=(lo+hi)//2;chosen=None
        for i in sorted(range(lo,max(lo,hi-31)),key=lambda i:(abs(i-center),i)):
            options=[]
            for j in range(i+3,min(i+31,hi)):
                x,y=parsed[i],parsed[j];dt=y[1]-x[1]
                d=math.dist(x[2],y[2]);dot=min(1.,abs(sum(u*v for u,v in zip(x[3],y[3]))))
                angle=math.degrees(2*math.acos(dot))
                if .05<=d<=.30 and angle<=10 and .09<=dt<=1.01:
                    options.append((abs(d-.15)+.002*angle,j,d,angle,dt))
            if options:
                _,j,d,angle,dt=min(options);chosen={'i':parsed[i][0],'j':parsed[j][0],
                    'baseline_m':d,'rotation_degrees':angle,'dt_seconds':dt};break
        if chosen is None:raise SystemExit(f'No eligible metadata-only pair in bin {bin_id}; do not silently relax criteria')
        chosen.update(bin=bin_id,split='holdout' if bin_id in (2,5) else 'development');pairs.append(chosen)
    result={'schema':'scalemaster-frozen-pairs-v1','pose_path':str(Path(a.poses).resolve()),'pose_sha256':sha(a.poses),
        'source_freeze_path':str(Path(a.source_freeze).resolve()),'source_freeze_sha256':sha(a.source_freeze),
        'source_identities':source_freeze,
        'camera_matrix_path':str(Path(a.camera_matrix).resolve()),'camera_matrix_sha256':sha(a.camera_matrix),
        'quaternion_normalization':{'rule':'divide each quaternion by its Euclidean norm; fixed representation correction, not pose fitting','max_allowed_norm_deviation':1e-3,'max_observed_norm_deviation':max(norm_errors),'mean_observed_norm_deviation':sum(norm_errors)/len(norm_errors)},
        'selector_sha256':sha(__file__),'selection_reads':'pose CSV only; no depth/confidence/RGB values',
        'criteria':{'baseline_m':[.05,.30],'rotation_deg_max':10,'temporal_bins':6,'holdout_bins':[2,5]},
        'depth_assumptions':{'shape_hw':[192,256],'dtype':'uint16','confidence_code':2,'meters_per_unit':'UNVERIFIED; inferred diagnostic only'},
        'geometry_assumptions':{'K':K_depth,'released_K':K_raw,'source_image_wh':[1920,1440],'depth_wh':[256,192],
            'K_source':'exact pinned camera_matrix.csv left-scaled by observed dimension ratios1/7.5, no pixel-center adjustment; conditional association',
            'pose_direction':'world_from_arkit_camera, assumed','optical_to_arkit_camera':[[1,0,0],[0,-1,0],[0,0,-1]]},
        'pairs':pairs}
    dst.parent.mkdir(parents=True,exist_ok=True)
    with dst.open('x') as f:json.dump(result,f,indent=2)
    print(dst)

if __name__=='__main__':main()

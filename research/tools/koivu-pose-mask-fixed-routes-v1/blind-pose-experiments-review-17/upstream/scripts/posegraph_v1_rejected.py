"""Joint pose refinement with released Open3D pose-graph optimisation (multiway registration recipe).

- Registration uses ONLY non-floor geometry (0.20-2.2 m above the initial floor plane). The floor is held
  out so that floor consistency afterwards is an independent check, not something the optimiser fitted.
- Odometry edges: consecutive frames, point-to-plane ICP initialised from the RECORDED relative pose.
- Loop edges: frames with nearby cameras and similar viewing direction, ICP from recorded relative pose,
  marked uncertain so the optimiser's line process can prune bad ones.
- Acceptance (decided before running): per-frame floor offset |median| and spread improve, the number of
  previously-consistent frames that become inconsistent is <= 2 % of them, and the edge pruning keeps
  >= 80 % of loop edges.
Outputs a new transformations.json (same format, refined OpenGL camera-to-world) in a directory whose
depth/ is a symlink to the original, so the unchanged pipelines can run on it.

usage: posegraph.py <long_capture_dir> <out_dir>
"""
import sys,os,json,time,math
import numpy as np,open3d as o3d
from PIL import Image
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import pipeline as PL
reg=o3d.pipelines.registration
P=dict(voxel=.03,icp_dist=.08,loop_cam_dist=1.5,loop_view_deg=50,loop_min_gap=5,loop_max_per_frame=6,
       nonfloor=(.20,2.2),max_range=4.0,edge_prune=.25,info_min_fitness=.3)

def cam_points(d,f):
    dep=np.array(Image.open(os.path.join(d,f['depth_file_path'][2:]))).astype(np.float64)*.001
    h,w=dep.shape;rr=np.arange(h);cc=np.arange(w);rs=rr[(rr+15)%4==2];cs=cc[(cc+15)%4==2]
    dd=dep[np.ix_(rs,cs)];R_,C_=np.meshgrid(rs.astype(float),cs.astype(float),indexing='ij')
    rays=np.stack(((C_+.5-f['cx'])/f['fl_x'],-(R_+.5-f['cy'])/f['fl_y'],-np.ones_like(R_)),-1)
    p=(rays*dd[...,None]).reshape(-1,3);r=dd.reshape(-1);return p[(r>0)&(r<P['max_range'])]

def main():
    d,out=sys.argv[1:3];os.makedirs(out,exist_ok=True);PL.T0=time.time()
    J=json.load(open(os.path.join(d,'transformations.json')));T=J['frames'];n=len(T)
    C0=np.array([f['transform_matrix'] for f in T])
    # initial level frame from the recorded poses (same routine as the mapping pipeline)
    Pall,Fall,_=PL.lidar_samples(d,T);R,t=PL.level_frame(Pall,C0[:,:3,3]);L=np.eye(4);L[:3,:3]=R;L[:3,3]=t
    clouds=[]
    for i,f in enumerate(T):
        pc=cam_points(d,f);hw=(pc@C0[i,:3,:3].T+C0[i,:3,3])@R.T+t
        keep=(hw[:,2]>P['nonfloor'][0])&(hw[:,2]<P['nonfloor'][1])
        c=o3d.geometry.PointCloud(o3d.utility.Vector3dVector(pc[keep])).voxel_down_sample(P['voxel'])
        c.estimate_normals(o3d.geometry.KDTreeSearchParamHybrid(radius=P['voxel']*3,max_nn=30));clouds.append(c)
    PL.log(stage='clouds',frames=n,median_points=int(np.median([len(c.points) for c in clouds])))
    def pair(s,tg):
        init=np.linalg.inv(C0[tg])@C0[s]
        r=reg.registration_icp(clouds[s],clouds[tg],P['icp_dist'],init,reg.TransformationEstimationPointToPlane(),reg.ICPConvergenceCriteria(max_iteration=40))
        info=reg.get_information_matrix_from_point_clouds(clouds[s],clouds[tg],P['icp_dist'],r.transformation)
        return r,info,init
    pg=reg.PoseGraph()
    for i in range(n):pg.nodes.append(reg.PoseGraphNode(C0[i].copy()))
    odo=[];loops=[]
    for i in range(n-1):
        r,info,init=pair(i,i+1)
        if r.fitness<P['info_min_fitness']:  # weak overlap: keep the recorded relative pose as the odometry constraint
            pg.edges.append(reg.PoseGraphEdge(i,i+1,init,np.eye(6)*10,uncertain=False));odo.append(('recorded',i,r.fitness))
        else:
            pg.edges.append(reg.PoseGraphEdge(i,i+1,r.transformation,info,uncertain=False));odo.append(('icp',i,r.fitness))
    cams=C0[:,:3,3];fwd=-C0[:,:3,2]
    for i in range(n):
        cand=[j for j in range(i+P['loop_min_gap'],n) if np.linalg.norm(cams[i]-cams[j])<P['loop_cam_dist'] and np.degrees(np.arccos(np.clip(fwd[i]@fwd[j],-1,1)))<P['loop_view_deg']]
        if not cand:continue
        for j in np.array(cand)[np.linspace(0,len(cand)-1,min(len(cand),P['loop_max_per_frame'])).astype(int)]:
            r,info,init=pair(i,int(j))
            if r.fitness<P['info_min_fitness']:continue
            pg.edges.append(reg.PoseGraphEdge(i,int(j),r.transformation,info,uncertain=True));loops.append((i,int(j),r.fitness))
    PL.log(stage='graph',odometryEdges=len(odo),odometryRecordedFallback=sum(1 for o in odo if o[0]=='recorded'),loopEdges=len(loops))
    opt=reg.GlobalOptimizationOption(max_correspondence_distance=P['icp_dist'],edge_prune_threshold=P['edge_prune'],preference_loop_closure=1.0,reference_node=0)
    with o3d.utility.VerbosityContextManager(o3d.utility.VerbosityLevel.Error):
        reg.global_optimization(pg,reg.GlobalOptimizationLevenbergMarquardt(),reg.GlobalOptimizationConvergenceCriteria(),opt)
    kept_loops=sum(1 for e in pg.edges if e.uncertain)
    C1=np.array([nd.pose for nd in pg.nodes])
    dT=[np.linalg.norm(C1[i,:3,3]-C0[i,:3,3]) for i in range(n)];dR=[np.degrees(np.arccos(np.clip((np.trace(C0[i,:3,:3].T@C1[i,:3,:3])-1)/2,-1,1))) for i in range(n)]
    PL.log(stage='optimised',loopEdgesKept=kept_loops,loopEdgesBefore=len(loops),poseChange_cm_p50_p90_max=[round(float(np.percentile(dT,50)*100),2),round(float(np.percentile(dT,90)*100),2),round(float(np.max(dT)*100),2)],rotChange_deg_p50_p90_max=[round(float(np.percentile(dR,50)),2),round(float(np.percentile(dR,90)),2),round(float(np.max(dR)),2)])
    J2=dict(J);J2['frames']=[dict(f,transform_matrix=C1[i].tolist()) for i,f in enumerate(T)];J2['pose_refinement']=dict(tool='Open3D '+o3d.__version__+' PoseGraph + GlobalOptimizationLevenbergMarquardt',params=P)
    json.dump(J2,open(os.path.join(out,'transformations.json'),'w'))
    for sub in ('depth','images'):
        if not os.path.exists(os.path.join(out,sub)):os.symlink(os.path.join(os.path.abspath(d),sub),os.path.join(out,sub))
    json.dump(dict(params=P,log=PL.LOG,odometry=odo,loops=loops),open(os.path.join(out,'POSEGRAPH_RECEIPT.json'),'w'),default=str)
if __name__=='__main__':main()

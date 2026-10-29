"""Released Open3D fixed-pose, depth-only TSDF replay; no mapping accuracy claim."""
import argparse,json,math,sys,time
from pathlib import Path
import numpy as np
from PIL import Image
import open3d as o3d
from common import (INDICES,VOXEL,SDF_TRUNC,DEPTH_TRUNC,DEPTH_SCALE,digest,save,
                    read_metadata,mask_depth,make_rgbd,make_volume,verify_backend)

if not __debug__:raise RuntimeError('Assertions must remain enabled')


def software_controls(out):
    # Numeric/mask fixture is software input-contract validation, not sensor proof.
    d=np.full((192,256),2000,np.uint16);c=np.full(d.shape,2,np.uint8)
    d[0,:5]=[0,65535,4000,4001,3999];c[1,:3]=[0,1,3]
    masked,reason,stats=mask_depth(d,c)
    assert list(masked[0,:5])==[0,0,0,0,3999]
    assert list(masked[1,:3])==[0,0,0]
    assert reason[0,0]&1 and reason[0,1]&2 and reason[1,0]&4 and reason[1,1]&8 and reason[1,2]&16
    native=np.asarray(make_rgbd(o3d,masked).depth)
    assert np.allclose(native,masked.astype(np.float32)/1000.,rtol=0,atol=3e-7)
    wrong_units=o3d.geometry.RGBDImage.create_from_color_and_depth(
        o3d.geometry.Image(np.zeros((*d.shape,3),np.uint8)),o3d.geometry.Image(masked),
        depth_scale=1.,depth_trunc=4.,convert_rgb_to_intensity=False)
    assert np.count_nonzero(np.asarray(wrong_units.depth))==0
    # Native integration of a known plane tests world_from_camera -> inverse
    # extrinsic, including rotation/translation; wrong direction is a negative control.
    theta=math.radians(20);R=np.array([[math.cos(theta),0,math.sin(theta)],[0,1,0],[-math.sin(theta),0,math.cos(theta)]])
    T=np.eye(4);T[:3,:3]=R;T[:3,3]=[.4,-.2,.3]
    probe=np.array([.2,.3,2.,1.]);assert np.allclose(np.linalg.inv(T)@(T@probe),probe,atol=1e-12)
    rgbd=make_rgbd(o3d,np.full((48,64),2000,np.uint16))
    intrinsic=o3d.camera.PinholeCameraIntrinsic(64,48,60.,60.,31.5,23.5)
    distances={}
    for name,E in [('correct_inverse',np.linalg.inv(T)),('wrong_pose_direction',T)]:
        volume=make_volume(o3d);volume.integrate(rgbd,intrinsic,E)
        mesh=volume.extract_triangle_mesh();v=np.asarray(mesh.vertices)
        assert len(v)>20 and np.isfinite(v).all()
        errors=np.abs((v-T[:3,3])@(R@np.array([0.,0.,1.]))-2.)
        distances[name]={'vertices':len(v),'median_plane_error_m':float(np.median(errors)),
                         'p95_plane_error_m':float(np.quantile(errors,.95))}
    assert distances['correct_inverse']['p95_plane_error_m']<=.08
    assert distances['wrong_pose_direction']['median_plane_error_m']>.1
    save(out/'SOFTWARE_CONTROLS.json',{'status':'passed','native_depth_unit_and_invalid_mask_fixture':'passed',
         'wrong_depth_scale_all_clipped':'passed','native_pose_direction_plane_fixture':distances,
         'meaning':'software convention/units controls only; does not verify real sensor calibration'})


def selected_contract(freeze):
    contract=json.loads(Path(freeze['input_paths']['selected_calibration']).read_text())
    result=json.loads(Path(freeze['input_paths']['axis_result']).read_text())
    lock=json.loads(Path(freeze['input_paths']['axis_lock']).read_text())
    receipt=json.loads(Path(freeze['input_paths']['axis_receipt']).read_text())
    candidate=result['family_search_development_only']['candidate']
    if (candidate!=lock['candidate'] or candidate['optical_to_recorded_camera']!=[[1,0,0],[0,1,0],[0,0,1]]
        or candidate['scale_m_per_unit']!=.001 or contract['optical_to_recorded_camera']!=candidate['optical_to_recorded_camera']
        or contract['meters_per_raw_unit']!=candidate['scale_m_per_unit']
        or result['diagnostic_decision']['status']!='candidate_survives_preregistered_internal_checks'
        or not receipt['all_stages_completed'] or receipt['resource_violations']):
        raise ValueError('Selected calibration evidence mismatch')
    # Never consume result.geometry_assumptions.optical_to_arkit_camera: that is
    # the intentionally retained ORIGINAL-F control, not the selected convention.
    return contract


def replay(freeze,out):
    contract=selected_contract(freeze)
    K,poses,times,norms=read_metadata(freeze)
    if not np.array_equal(K,np.asarray(contract['K_depth'])):raise ValueError('Exact K mismatch')
    receipt=json.loads((out/'images/receipt.json').read_text())
    if receipt['indices']!=INDICES or receipt['compressed_sha256']!=freeze['archive']['sha256']:
        raise ValueError('Extraction receipt mismatch')
    masks=out/'masks';masks.mkdir();prepared=[];frames=[]
    for i in INDICES:
        arrays=[]
        for kind in ('depth','confidence'):
            path=out/'images'/f'{kind}_{i:06d}.png'
            if digest(path)!=receipt['files'][path.name]:raise ValueError('Extracted image changed')
            with Image.open(path) as im:arrays.append(np.asarray(im).copy())
        masked,reason,stats=mask_depth(*arrays)
        Image.fromarray(reason).save(masks/f'mask_{i:06d}.png')
        if stats['unrecognized_confidence_codes']:
            save(out/'PREFLIGHT_FAILURE.json',{'frame':i,'reason':'unrecognized confidence codes',
                 'counts':stats,'real_TSDF_volume_created':False,'mask_saved':True})
            raise ValueError('Unknown confidence codes: preflight stops before real TSDF')
        actual=np.asarray(make_rgbd(o3d,masked).depth)
        if not np.allclose(actual,masked.astype(np.float32)/1000,rtol=0,atol=3e-7):
            raise ValueError('Native scale/truncation differs from explicit mask')
        T=poses[i];E=np.linalg.inv(T)
        expected=np.eye(4);expected[:3,:3]=T[:3,:3].T;expected[:3,3]=-T[:3,:3].T@T[:3,3]
        if not np.allclose(E,expected,atol=1e-12):raise ValueError('Extrinsic inversion mismatch')
        prepared.append(masked);frames.append({'frame':i,'timestamp':times[i],**stats})
    preflight={'status':'passed','frames':60,'K':K.tolist(),'selected_calibration':contract,
               'quaternion_normalization':norms,'timestamp_span_seconds':times[59]-times[0],
               'frame_audits':frames,'all_real_input_checks_before_volume_creation':True,
               'mask_bits':{'1':'raw0 unknown/missing','2':'raw65535 conservatively excluded',
                            '4':'confidence0 excluded, geometry unknown','8':'confidence1 not selected','16':'unrecognized confidence code -> preflight failure',
                            '32':'raw>=4000 below65535 excluded by fixed4m range'},
               'mask_bit_counts_may_overlap':True,'no_RGB_or_optimized_poses_used':True}
    save(out/'PREFLIGHT.json',preflight)
    intrinsic=o3d.camera.PinholeCameraIntrinsic(256,192,K[0,0],K[1,1],K[0,2],K[1,2])
    volume=make_volume(o3d);hit_cells={};started=time.monotonic()
    with (out/'INTEGRATION.jsonl').open('x') as log:
        for i,depth in zip(INDICES,prepared):
            T=poses[i]
            volume.integrate(make_rgbd(o3d,depth),intrinsic,np.linalg.inv(T))
            # Separate measured ENDPOINT ledger. It is neither TSDF weight nor a
            # ray-carved free-space map; absent cells stay unobserved/unknown.
            v,u=np.nonzero(depth)
            z=depth[v,u].astype(float)/1000.
            camera=np.column_stack(((u-K[0,2])*z/K[0,0],(v-K[1,2])*z/K[1,1],z))
            world=camera@T[:3,:3].T+T[:3,3]
            if not np.isfinite(world).all():raise ValueError('Nonfinite observed endpoints')
            if np.any(np.abs(world/VOXEL)>np.iinfo(np.int64).max-1024):raise ValueError('Endpoint-cell index overflow')
            cells,inverse,count=np.unique(np.floor(world/VOXEL).astype(np.int64),axis=0,return_inverse=True,return_counts=True)
            sums=np.zeros((len(cells),3));np.add.at(sums,inverse,world)
            for cell,n,xyz in zip(cells,count,sums):
                key=tuple(int(x) for x in cell)
                if key not in hit_cells:hit_cells[key]=[0,0,0.,0.,0.]
                row=hit_cells[key];row[0]+=int(n);row[1]+=1
                row[2]+=float(xyz[0]);row[3]+=float(xyz[1]);row[4]+=float(xyz[2])
            if len(hit_cells)>250000:raise RuntimeError('Endpoint cell cap250000, no automatic thinning')
            log.write(json.dumps({'frame':i,'accepted_endpoints':len(world),'unique_hit_cells_this_frame':len(cells),
                                  'cumulative_unique_hit_cells':len(hit_cells),'elapsed_wall_seconds':time.monotonic()-started})+'\n');log.flush()
    # Native unfiltered mesh, no cleanup, hole filling, normal-driven plane fit or ICP.
    mesh=volume.extract_triangle_mesh();vertices=np.asarray(mesh.vertices);triangles=np.asarray(mesh.triangles)
    if len(vertices)>500000 or len(triangles)>1000000:raise RuntimeError('Mesh output count cap')
    if not np.isfinite(vertices).all() or (len(triangles) and (triangles.min()<0 or triangles.max()>=len(vertices))):
        raise ValueError('Invalid native mesh')
    if len(vertices) and not o3d.io.write_triangle_mesh(str(out/'native-unfiltered-tsdf.ply'),mesh,write_ascii=False):
        raise RuntimeError('Mesh write failed')
    keys=sorted(hit_cells);rows=np.asarray([hit_cells[k] for k in keys],dtype=float).reshape((-1,5))
    points=rows[:,2:]/rows[:,0,None] if len(rows) else np.empty((0,3))
    if len(points):
        cloud=o3d.geometry.PointCloud();cloud.points=o3d.utility.Vector3dVector(points)
        if not o3d.io.write_point_cloud(str(out/'observed-endpoint-centroids.ply'),cloud,write_ascii=False):raise RuntimeError('Observed endpoint output failed')
    trajectory=np.asarray([poses[i][:3,3] for i in INDICES])
    np.savez(out/'geometry-for-preview.npz',vertices=vertices,triangles=triangles,endpoints=points,trajectory=trajectory)
    np.savez(out/'observed-hit-ledger.npz',cell_indices=np.asarray(keys,dtype=np.int64).reshape((-1,3)),
             endpoint_pixel_hits=rows[:,0].astype(np.int64),distinct_frame_hits=rows[:,1].astype(np.int64),
             endpoint_centroids=points,cell_width_m=np.array(VOXEL))
    totals={key:sum(row[key] for row in frames) for key in frames[0] if key not in ('frame','timestamp')}
    result={'status':'completed_with_surface' if len(vertices) else 'completed_no_surface',
            'scope':'fixed Stairs_02 frames0..59, depth-only released Open3D provided-pose replay',
            'integrated_frames':60,'prefix_may_be_landing_or_approach_not_entire_staircase':True,
            'conditional_selected_calibration':contract,'parameters':{'voxel_m':VOXEL,'sdf_trunc_m':SDF_TRUNC,
            'depth_trunc_m':DEPTH_TRUNC,'depth_scale':DEPTH_SCALE,'color':'NoColor; zero placeholder ignored',
            'volume_unit_resolution':16,'depth_sampling_stride':4},'raster_totals':totals,
            'accepted_endpoint_fraction_of_all_raster_pixels':totals['accepted_endpoint_pixels']/totals['raster_pixels'],
            'vertices':len(vertices),'triangles':len(triangles),
            'mesh_bounds':None if not len(vertices) else [vertices.min(axis=0).tolist(),vertices.max(axis=0).tolist()],
            'unique_endpoint_cells':len(keys),'endpoint_cells_seen_in_at_least2_frames':int((rows[:,1]>=2).sum()),
            'endpoint_cells_seen_in_at_least5_frames':int((rows[:,1]>=5).sum()),
            'observed_endpoint_pixel_hits':int(rows[:,0].sum()),
            'endpoint_cells_are_TSDF_weights':False,'full_volume_unknown_free_observed_coverage_exported':False,
            'raster_hits_are_independent_measurements':False,'missing_mesh_implies_free_floor':False,
            'stair_detection_executed':False,'independent_ground_truth_used':False,'metric_accuracy_measured':False,
            'RGB_synchronization':'unresolved; RGB not read','physical_navigation_authority':False,
            'raw_and_derived_data_private':True,
            'declared_baseline_adapter_changes':['NoColor/no actual RGB because sync unknown','confidence2 and numeric masks before native integration',
            'selected identity optical axes; no original ARKit sign flip','no author-style cumulative random cloud, retain native final mesh and separate endpoint ledger'],
            'geometry_output_sha256':{p.name:digest(p) for p in out.iterdir() if p.suffix in ('.ply','.npz')}}
    save(out/'RESULT.json',result)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--freeze',required=True);parser.add_argument('--output-root',required=True)
    parser.add_argument('--software-only',action='store_true');args=parser.parse_args()
    freeze=json.loads(Path(args.freeze).read_text());out=Path(args.output_root)
    modules=verify_backend(o3d,freeze)
    if args.software_only:software_controls(out)
    else:replay(freeze,out)
    verify_backend(o3d,freeze)
    save(out/('SOFTWARE_MODULES.json' if args.software_only else 'REPLAY_MODULES.json'),modules)
    print('software_controls_completed' if args.software_only else 'replay_completed')


if __name__=='__main__':main()

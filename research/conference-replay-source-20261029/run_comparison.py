#!/usr/bin/env python3
"""SOURCE ONLY. Requires separately reviewed aggregate guard and root admission.
Scene-input mapping only: unchanged current Coffee Native/build_graph/selector.
No manual exclusions, repaired floor, FARO, trajectory controller or body clearance.
"""
import argparse, dataclasses, hashlib, json, math, os, pathlib, sys
H=pathlib.Path(__file__).resolve().parent; R=H.parents[1]; W=R.parent
INVENTORY=R/'research/conference-replay-input-inventory-20261029'
MESH_SHA='79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1'
POSE_SHA='c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'

def sha(p): return hashlib.sha256(pathlib.Path(p).read_bytes()).hexdigest()
def safe(x):
    if isinstance(x,float) and not math.isfinite(x): return None
    if isinstance(x,dict): return {k:safe(v)for k,v in x.items()}
    if isinstance(x,(list,tuple)): return [safe(v)for v in x]
    return x

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--pins',type=pathlib.Path,required=True);ap.add_argument('--pins-sha256',required=True);cli_args=ap.parse_args()
    if sha(cli_args.pins)!=cli_args.pins_sha256: raise ValueError('admitted manifest SHA mismatch')
    pins=json.loads(cli_args.pins.read_text())
    if pins['status']!='SOURCE_FROZEN_AWAITING_ROOT_ADMISSION': raise ValueError('unexpected manifest schema')
    def expand(p):
        value=p.replace('@WORKSPACE@',str(W)).replace('@REPO@',str(R))
        return value if value.startswith('/') else str(R/value)
    def verify():
        if sha(cli_args.pins)!=cli_args.pins_sha256: raise ValueError('manifest changed')
        for name,digest in pins['inputs'].items():
            if sha(expand(name))!=digest: raise ValueError('source/input pin mismatch: '+name)
    verify(); source=pathlib.Path(expand(pins['sourceDirectory'])); out=pathlib.Path(expand(pins['comparisonDirectory']))
    out.mkdir(exist_ok=False)
    if sha(source/'textured.obj')!=MESH_SHA or sha(source/'transformations.json')!=POSE_SHA: raise ValueError('original scene bytes mismatch')
    extract=json.loads((source/'EXTRACTION.json').read_text())
    if extract['status']!='COMPLETE_EXACT_OBJ_AND_ORIGINAL_POSES': raise ValueError('source extraction incomplete')
    requests=json.loads((INVENTORY/'TARGETS.json').read_text())['primaryPairs']
    if [q['name']for q in requests]!=['table_92_to_120','table_120_to_200','table_200_to_220','table_220_to_20','table_20_to_92','varpu_130_to_160','varpu_160_to_130']: raise ValueError('fixed objective set changed')
    registration=json.loads((INVENTORY/'evidence/REGISTRATION_RESULT.json').read_text())
    receipt=json.loads((INVENTORY/'evidence/MESH_INPUT_RECEIPT.json').read_text())
    if registration['scale']!=1 or not registration['acceptedForComparator'] or registration['referenceUsed']: raise ValueError('registration contract')
    original_vertices=[]; faces=[]
    for line in (source/'textured.obj').open():
        q=line.split()
        if not q: continue
        if q[0]=='v':
            if len(q)!=4: raise ValueError('unsupported OBJ vertex')
            xyz=[float(v)for v in q[1:]]
            if not all(math.isfinite(v)for v in xyz): raise ValueError('nonfinite source')
            original_vertices.append(xyz)
        elif q[0]=='f':
            if len(q)!=4: raise ValueError('nontriangular OBJ face')
            face=[int(v.split('/')[0])-1 for v in q[1:]]
            if min(face)<0: raise ValueError('negative/relative OBJ face index unsupported')
            faces.append(face)
    if (len(original_vertices),len(faces))!=(18398,29366) or max(max(f)for f in faces)>=18398: raise ValueError('original cardinality/index mismatch')
    # Imports/native calls are deliberately after whole-input pin and schema checks.
    for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS'): os.environ[k]='1'
    sys.dont_write_bytecode=True
    import numpy as np
    sys.path.insert(0,str(R/'research/clearance-first-coffee-source-20261029'))
    from selector import select
    replay=W/'coffee-native-replay-prepared-002'
    sys.path.insert(0,str(replay/'blind-tabletop-exclusion-planner-66'))
    from native_exclusion import Native
    from planner import build_graph
    obj=np.asarray(original_vertices,dtype=np.float64); tri=np.asarray(faces,dtype=np.int32)
    Q=np.asarray(registration['rotationOBJToLevel'],dtype=np.float64); translation=np.asarray(registration['translationOBJToLevel'],dtype=np.float64)
    if not np.allclose(Q@Q.T,np.eye(3),atol=1e-12,rtol=0) or abs(float(np.linalg.det(Q))-1)>1e-12: raise ValueError('not preserved proper rigid transform')
    level=obj@Q.T+translation; vertices=np.c_[level[:,0],level[:,2],-level[:,1]]
    actual_v=hashlib.sha256(np.ascontiguousarray(vertices,dtype='<f4').tobytes()).hexdigest()
    actual_t=hashlib.sha256(np.ascontiguousarray(tri,dtype='<i4').tobytes()).hexdigest()
    if actual_v!=receipt['transformedFloat32VertexBytesSHA'] or actual_t!=receipt['triangleBytesSHA']: raise ValueError('registered mesh byte receipt mismatch; no Recast engine created')
    model={'status':'started','sourceMeshSHA256':MESH_SHA,'sourceMeshTrianglesUnmodified':True,'registrationAuthority':'historicalEstimatedComparatorOnlyNotOfficialCameraMeshCalibration','historicalEstimatedLevelFrameUsed':True,'correctedOccupancyConsumed':False,'validatedCameraMeshAlignment':False,'registeredFloat32VerticesSHA256':actual_v,'trianglesInt32SHA256':actual_t,'bodyWidthDepthHeightMetres':[.45,.30,1.60],'horizontalMarginMetres':.15,'proposalRadiusMetres':.225,'proposalHeightMetres':1.75,'nativeExclusionEnabled':False,'physicalAuthority':False,'fullBodyValidation':'notEstablished','floorSupport':'unknown','manualRepairArm':'inputUnavailableNoKoivuPhysicalExclusionContract','movementExecuted':False,'paths':[]}
    def save():
        encoded=json.dumps(safe(model),indent=2,allow_nan=False)+'\n'
        if len(encoded.encode())>15*1024**2: raise RuntimeError('proposal output cap')
        (out/'PROPOSALS.json').write_text(encoded)
    def association(requested,projected):
        a=np.asarray(requested);b=np.asarray(projected); finite=bool(np.isfinite(b).all());d=b-a
        return {'finite':finite,'horizontalMetres':float(np.linalg.norm(d[[0,2]]))if finite else None,'verticalMetres':float(d[1])if finite else None,'passes10cmHorizontal':bool(finite and np.linalg.norm(d[[0,2]])<=.1),'actorSnapped':False}
    native=None
    try:
        native=Native(vertices,tri,exclusion=False)
        cfg=dataclasses.asdict(native.engine.config)
        expected={'radius':.225,'height':1.75,'cell_size':.025,'cell_height':.025,'max_climb':.025,'max_slope':15,'max_cells':250000,'max_nodes':4096}
        if cfg!=expected or native.marked_span_count!=0: raise ValueError('unchanged native configuration/exclusion contract')
        model['nativeConfig']=cfg
        # Keep every baseline result, including partial/invalid and explicit associations.
        for req in requests:
            a,b=req['requestedStartXYZ'],req['requestedGoalXYZ'];native_result=native.engine.route(a,b,query_half_extents=(.2,.3,.2),max_points=256)
            aa,bb=association(a,native_result.projected_start),association(b,native_result.projected_goal)
            row={'name':req['name'],'requestedStartXYZ':a,'requestedGoalXYZ':b,'sourcePoseIndices':req['sourcePoseIndices'],'baselineNative':dataclasses.asdict(native_result),'baselineStartAssociation':aa,'baselineGoalAssociation':bb,'baselineCompleteAndAssociated':bool(native_result.complete and len(native_result.points)>=2 and aa['passes10cmHorizontal'] and bb['passes10cmHorizontal']),'baselineRequestedConnectorChainXYZ':([a]+list(native_result.points)+[b]) if (native_result.complete and len(native_result.points)>=2 and aa['passes10cmHorizontal'] and bb['passes10cmHorizontal']) else None,'cameraAnchorsNotBodyPose':True,'gridStatus':'notYetEvaluated','physicalAuthority':False}
            model['paths'].append(row);save();print(json.dumps({'pair':row['name'],'baselineCompleteAndAssociated':row['baselineCompleteAndAssociated']}),flush=True)
        anchors=[]
        for req in requests:
            for key in ('requestedStartXYZ','requestedGoalXYZ'):
                if req[key] not in anchors: anchors.append(req[key])
        if len(anchors)!=7: raise ValueError('seven unique original requested anchors required')
        try:
            points,clearance,adj,nodes,associations=build_graph(native,vertices,anchors+[anchors[0]])
        except (ValueError,AssertionError) as exc:
            # Do not drop a difficult endpoint to make the remainder look like a full pass.
            for row in model['paths']: row['gridStatus']='unavailableWholeBatchAnchorOrGraphFailure'
            model.update(status='SOURCE_BASELINES_RETAINED_GRID_UNAVAILABLE',gridFailure=type(exc).__name__+': '+str(exc));save();return
        # Preserve the native requested/projected association for the same endpoints.
        by_requested={tuple(v['requestedXYZ']):v for v in associations}
        for row in model['paths']:
            for requested_key,projection_key in (('requestedStartXYZ','projected_start'),('requestedGoalXYZ','projected_goal')):
                before=np.asarray(row['baselineNative'][projection_key],dtype=float)
                after=np.asarray(by_requested[tuple(row[requested_key])]['projectedXYZ'],dtype=float)
                if np.isfinite(before).all() and not np.array_equal(before,after):
                    raise ValueError('grid projection changed from native baseline: '+row['name'])
        nodes=nodes[:-1];mapping={tuple(anchor):node for anchor,node in zip(anchors,nodes)}
        model.update(anchorAssociations=associations,graphNodes=len(points),graphDirectedEdges=sum(map(len,adj)))
        for row in model['paths']:
            a,b=row['requestedStartXYZ'],row['requestedGoalXYZ'];selected=select(points,clearance,adj,mapping[tuple(a)],mapping[tuple(b)],nodes)
            for arm in ('distanceGrid','clearanceGrid'):
                if arm in selected:
                    chain=[a]+selected[arm]['pointsXYZ']+[b]
                    selected[arm]['requestedConnectorChainXYZ']=chain
                    selected[arm]['connectorInclusiveLengthMetres']=sum(float(np.linalg.norm(np.asarray(y)-x))for x,y in zip(chain[:-1],chain[1:]))
            row.update(gridStatus=selected['status'],gridSelection=selected);save();print(json.dumps({'pair':row['name'],'gridStatus':row['gridStatus']}),flush=True)
        model['status']='SEVEN_SOURCE_OBJECTIVES_EVALUATED_NOT_BODY_VALIDATED';save()
    except BaseException as exc:
        model.update(status='FAILED_PARTIAL_RETAINED',error=type(exc).__name__+': '+str(exc));save();raise
    finally:
        if native is not None: native.close()
        verify()
    verify()

if __name__=='__main__': main()

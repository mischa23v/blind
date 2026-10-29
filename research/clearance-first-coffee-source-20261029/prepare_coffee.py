"""SOURCE ONLY. Requires separately admitted native run; never builds/installs.

Produces 20 goal-connected candidate proposals on the unchanged Coffee mesh.
Hard validation is deliberately NOT fabricated from navmesh clearance.
"""
import argparse, hashlib, importlib.util, json, pathlib, sys

MESH_SHA='f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a'
RESULT_SHA='4d8ed568da8497e1e39e14b08918616107e54192676389bcee3b1c5dec7c5558'
CANONICAL_SHA='52d100633b60e1d9063d3e7dcfb27d37473d5953026a89c2c30e53a6adb965a2'

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--replay-root',required=True)
    ap.add_argument('--canonical-paths',required=True);ap.add_argument('--out',required=True)
    ap.add_argument('--pins-sha256',required=True)
    args=ap.parse_args();root=pathlib.Path(args.replay_root).resolve()
    here=pathlib.Path(__file__).resolve().parent;repo=here.parents[1]
    manifest=here/'SOURCE_PINS.json'
    if hashlib.sha256(manifest.read_bytes()).hexdigest()!=args.pins_sha256: raise ValueError('manifest pin mismatch')
    pins=json.loads(manifest.read_text())
    for name,expected in pins['inputs'].items():
        expanded=name.replace('@WORKSPACE@',str(repo.parent)).replace('@PROTOCOL@',str(here))
        file=pathlib.Path(expanded) if expanded.startswith('/') else repo/expanded
        if hashlib.sha256(file.read_bytes()).hexdigest()!=expected: raise ValueError('import/input pin mismatch: '+name)
    if root!=repo.parent/'coffee-native-replay-prepared-002': raise ValueError('unfrozen replay root')
    mesh=root/'blind-coffee-source-readiness/selected/room_datasets/coffee_room/iphone/long_capture/polycam_mesh/textured.obj'
    result=root/'blind-coffee-native-topology/RESULT.json'
    for file,expected in ((mesh,MESH_SHA),(result,RESULT_SHA)):
        if hashlib.sha256(file.read_bytes()).hexdigest()!=expected: raise ValueError('source pin mismatch')
    canonical=pathlib.Path(args.canonical_paths)
    if hashlib.sha256(canonical.read_bytes()).hexdigest()!=CANONICAL_SHA: raise ValueError('canonical hash mismatch')
    frozen=json.loads(canonical.read_text())
    if frozen['sourceMeshSHA256']!=MESH_SHA or len(frozen['paths'])!=20: raise ValueError('canonical identity')
    import numpy as np
    from selector import select
    diagnostic=repo/'research/independent-2d-route-validator-20261029'
    sys.path.insert(0,str(diagnostic))
    from proposal_windows import diagnose_manual_windows
    manual_windows=json.loads((diagnostic/'actual-coffee-0-to-8-attempt002/INPUT_FREEZE.json').read_text())['windows']
    sys.path.insert(0,str(root/'blind-tabletop-exclusion-planner-66'))
    from native_exclusion import Native
    from planner import build_graph
    baseline=json.loads(result.read_text()); ids=sorted({p[k] for p in frozen['paths'] for k in ('start','goal')})
    anchors=[baseline['endpoints'][i]['requestedXYZ'] for i in ids]
    for path in frozen['paths']:
        for key in ('start','goal'):
            if path['requested'+key.title()+'XYZ']!=baseline['endpoints'][path[key]]['requestedXYZ']:
                raise ValueError('requested endpoint changed')
    vertices=[];faces=[]
    for line in mesh.open():
        q=line.split()
        if not q: continue
        if q[0]=='v':vertices.append([float(x) for x in q[1:]])
        elif q[0]=='f':faces.append([int(x.split('/')[0])-1 for x in q[1:]])
    if len(vertices)!=51965 or len(faces)!=87370: raise ValueError('source cardinality')
    def sampled_wall_metrics(native, chain):
        # Independent resampling of both arms at <=2.5 cm; not body clearance.
        values=[]; missing=0; max_shift=0.; max_vertical=0.; total=0
        chain=np.asarray(chain,float); lengths=np.linalg.norm(np.diff(chain,axis=0),axis=1)
        cumulative=np.r_[0.,np.cumsum(lengths)]; length=float(cumulative[-1])
        count=max(1,int(np.ceil(length/.025)))
        if count+1>4096: raise ValueError('route sampling budget')
        for distance in np.linspace(0.,length,count+1):
            index=min(int(np.searchsorted(cumulative,distance,side='right'))-1,len(lengths)-1)
            index=max(0,index); alpha=0. if lengths[index]==0 else (distance-cumulative[index])/lengths[index]
            q=chain[index]+(chain[index+1]-chain[index])*alpha
            sample=native.sample(q,(.001,.3,.001));total+=1
            if sample is None: missing+=1;continue
            projected,wall=sample;shift=float(np.linalg.norm((projected-q)[[0,2]]))
            max_shift=max(max_shift,shift);max_vertical=max(max_vertical,abs(float(projected[1]-q[1])))
            if shift>1e-4:missing+=1;continue
            values.append(wall)
        return {'status':'sampledDiagnostic' if missing==0 else 'incompleteUnknown',
                'samples':total,'missingSamples':missing,
                'minimumSampledResidualWallMetres':min(values) if values else None,
                'p10SampledResidualWallMetres':float(np.quantile(values,.1)) if values else None,
                'maximumHorizontalProjectionMetres':max_shift,
                'maximumVerticalProjectionMetres':max_vertical,
                'continuousBodyClearanceEstablished':False}
    native=Native(np.array(vertices),np.array(faces),exclusion=False)
    try:
        if native.marked_span_count!=0: raise ValueError('exclusions forbidden')
        points,clearance,adj,nodes,associations=build_graph(native,np.array(vertices),anchors+[anchors[0]])
        for i,association in zip(ids,associations):
            if association['projectedXYZ']!=baseline['endpoints'][i]['projectedXYZ']:raise ValueError('endpoint projection changed')
        nodes=nodes[:-1]; mapping=dict(zip(ids,nodes)); rows=[]
        for path in frozen['paths']:
            i,j=path['start'],path['goal']
            row=select(points,clearance,adj,mapping[i],mapping[j],nodes)
            row.update(start=i,goal=j,originalNativePoints=path['nativePoints'],
                       originalRequestedConnectorChainXYZ=[path['requestedStartXYZ']]+path['nativePoints']+[path['requestedGoalXYZ']],
                       requestedStartXYZ=path['requestedStartXYZ'],requestedGoalXYZ=path['requestedGoalXYZ'])
            # Preserve the actual requested connector geometry for downstream
            # full-body/turn/support validation, not just the projected anchors.
            for arm in ('distanceGrid','clearanceGrid'):
                if arm in row:
                    row[arm]['requestedConnectorChainXYZ']=[path['requestedStartXYZ']]+row[arm]['pointsXYZ']+[path['requestedGoalXYZ']]
            row['originalSampledWallDiagnostic']=sampled_wall_metrics(native,path['nativePoints'])
            for arm in ('distanceGrid','clearanceGrid'):
                if arm in row: row[arm]['sampledWallDiagnostic']=sampled_wall_metrics(native,row[arm]['pointsXYZ'])
            if (i,j)==(0,8):
                row['manualWindowDiagnostics']={'original':diagnose_manual_windows(row['originalRequestedConnectorChainXYZ'],manual_windows)}
                for arm in ('distanceGrid','clearanceGrid'):
                    row['manualWindowDiagnostics'][arm]=(diagnose_manual_windows(row[arm]['requestedConnectorChainXYZ'],manual_windows) if arm in row else {'status':'candidateUnavailable','physical_clearance':'unknown'})
            rows.append(row)
            print(json.dumps({'pair':[i,j],'status':row['status']}),flush=True)
    finally: native.close()
    out=pathlib.Path(args.out);out.mkdir(exist_ok=False)
    (out/'PROPOSALS.json').write_text(json.dumps({'status':'sourceCandidatesNotBodyValidated',
        'meshSHA256':MESH_SHA,'bodyWidthDepthHeightMetres':[.45,.30,1.60],
        'horizontalMarginMetres':.15,'associations':associations,'paths':rows,
        'physicalAuthority':False},indent=2,allow_nan=False)+'\n')

if __name__=='__main__':main()

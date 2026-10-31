"""SOURCE ONLY. Requires separately admitted native run; never builds/installs.

Produces one separately labelled manual-window repaired candidate on the unchanged Coffee mesh.
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
    sys.path.insert(0,str(repo/'research/clearance-first-coffee-source-20261029'))
    from selector import select
    diagnostic=repo/'research/independent-2d-route-validator-20261029'
    sys.path.insert(0,str(diagnostic))
    from proposal_windows import diagnose_manual_windows
    from manual_filter import prune,select_with_frozen_cap
    first_file=repo.parent/'coffee-clearance-comparison-attempt-001/comparison/PROPOSALS.json'
    first_sha='1ed63feebdbffbc24b783a1d7691b1a0520a118a013dd8589e298a2c00a6ae29'
    if hashlib.sha256(first_file.read_bytes()).hexdigest()!=first_sha:raise ValueError('first comparison changed')
    first=json.loads(first_file.read_text());first_pair=next(p for p in first['paths']if (p['start'],p['goal'])==(0,8))
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
            if (i,j)!=(0,8):continue
            unfiltered=select(points,clearance,adj,mapping[i],mapping[j],nodes)
            for arm in ('distanceGrid','clearanceGrid'):
                if unfiltered[arm]['pointsXYZ']!=first_pair[arm]['pointsXYZ'] or unfiltered[arm]['lengthMetres']!=first_pair[arm]['lengthMetres']:
                    raise ValueError('unfiltered baseline changed; no repair comparison')
            if unfiltered['lengthCapMetres']!=first_pair['lengthCapMetres']:raise ValueError('detour cap changed')
            connectors=[[path['requestedStartXYZ'],points[mapping[i]].tolist()],
                        [points[mapping[j]].tolist(),path['requestedGoalXYZ']]]
            filtered,filter_receipt=prune(points,adj,manual_windows,connectors)
            repair=({'status':'manualConnectorBlocked','physicalAuthority':False} if filtered is None else
                    select_with_frozen_cap(select,points,clearance,filtered,mapping[i],mapping[j],nodes,first_pair['lengthCapMetres']))
            for arm in ('distanceGrid','clearanceGrid'):
                if arm in repair:
                    chain=[path['requestedStartXYZ']]+repair[arm]['pointsXYZ']+[path['requestedGoalXYZ']]
                    repair[arm]['requestedConnectorChainXYZ']=chain
                    repair[arm]['sampledWallDiagnostic']=sampled_wall_metrics(native,repair[arm]['pointsXYZ'])
                    repair[arm]['independentManualWindowDiagnostic']=diagnose_manual_windows(chain,manual_windows)
            if 'clearanceGrid' in repair and repair['clearanceGrid']['independentManualWindowDiagnostic']['manual_exclusion_contact']:
                repair['status']='independentManualVetoAfterRepair'
            row={'start':i,'goal':j,'status':repair['status'],'baselineArmsUnchanged':first_pair,
                 'manualRepair':repair,'edgeFilter':filter_receipt,'unfilteredGeometryExactlyReproduced':True,
                 'physicalAuthority':False,'full3DBodyAndSupportValidated':False}
            rows.append(row)
            print(json.dumps({'pair':[i,j],'status':row['status']}),flush=True)
    finally: native.close()
    out=pathlib.Path(args.out);out.mkdir(exist_ok=False)
    (out/'PROPOSALS.json').write_text(json.dumps({'status':'sourceManualRepairCandidateNotBodyValidated',
        'firstComparisonSHA256':first_sha,'newlyComparedPairs':[[0,8]],
        'meshSHA256':MESH_SHA,'bodyWidthDepthHeightMetres':[.45,.30,1.60],
        'horizontalMarginMetres':.15,'associations':associations,'paths':rows,
        'physicalAuthority':False},indent=2,allow_nan=False)+'\n')

if __name__=='__main__':main()

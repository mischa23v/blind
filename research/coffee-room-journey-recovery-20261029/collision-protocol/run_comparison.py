#!/usr/bin/env python3
"""Source-only prepared worker. Run only under separately admitted aggregate guard."""
import argparse, gzip, hashlib, json, math, os, pathlib, sys, time
ROOT = pathlib.Path(__file__).resolve().parent
MESH_SHA = 'f10de085426143ad095fefc713b4966d22fdf08beda9ff9ead759019a0a8306a'
FLOOR_Y = -1.6301633051396203
MAX_BOXES, MAX_TRIANGLES, MAX_RAYS = 55000, 30000000, 125000
MAX_LOGICAL, MAX_COMPRESSED = 64*1024*1024, 16*1024*1024

def digest(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
    return h.hexdigest()

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--mesh',required=True);ap.add_argument('--current-result',required=True);ap.add_argument('--out',required=True);ap.add_argument('--pins-sha256',required=True);args=ap.parse_args()
    if digest(ROOT/'SOURCE_PINS.json')!=args.pins_sha256: raise RuntimeError('source manifest pin mismatch')
    pins=json.loads((ROOT/'SOURCE_PINS.json').read_text())
    for p,h in pins['files'].items():
        if digest(ROOT/p)!=h:raise RuntimeError('source/input mismatch: '+p)
    frozen=json.loads((ROOT/'CURRENT_PATHS_20.json').read_text())
    if digest(args.current_result)!=frozen['currentResultSHA256'] or digest(args.mesh)!=MESH_SHA:raise RuntimeError('current path/source pin mismatch')
    schedule=json.loads((ROOT/'SCHEDULE_20.json').read_text())
    if len(schedule['paths'])!=20 or sum(len(p['events'])for p in schedule['paths'])!=6874:raise RuntimeError('schedule identity mismatch')
    out=pathlib.Path(args.out);out.mkdir(exist_ok=False)
    os.environ['OPENBLAS_NUM_THREADS']='1';os.environ['OMP_NUM_THREADS']='1';os.environ['MKL_NUM_THREADS']='1';sys.dont_write_bytecode=True
    up=ROOT/'upstream'
    for p in [up/'blind-split-candidate-game-03/source',up/'blind-split-candidate-game-03/ground-follow-v2',up/'blind-opus-reference-scoring-audit-02/source',up/'blind-koivu-reference-comparison-06']:
        sys.path.insert(0,str(p))
    import numpy as np
    import vtk
    from reference_geometry import ReferenceSurface,serial_vtk
    from oriented_container import OrientedReferenceContainer,BodyGeometry
    from oriented_ground_container import GroundedReferenceContainer
    from ground_support import GroundSupport
    from support_functions import support_check,connected_support,proposed_ground_motion
    runtime=serial_vtk(); began=time.monotonic();logical=0;scorers=[];summaries=[];status='incomplete';error=None
    def totals():
        return {'boxes':sum(s.box_queries for s in scorers),'triangles':sum(s.triangle_queries for s in scorers),'rays':sum(s.floor_ray_queries for s in scorers)}
    def check_budget():
        c=totals()
        if c['boxes']>MAX_BOXES or c['triangles']>MAX_TRIANGLES or c['rays']>MAX_RAYS or time.monotonic()-began>170:raise RuntimeError('worker budget reached; results incomplete')
    # Shared original vertex/face IDs and explicit double coordinates. No OBJ reader welding.
    vertices=[];faces=[]
    for line in pathlib.Path(args.mesh).open():
        q=line.split()
        if not q:continue
        if q[0]=='v':
            if len(q)!=4:raise RuntimeError('unsupported OBJ vertex')
            p=[float(v)for v in q[1:]]
            if not all(math.isfinite(v)for v in p):raise RuntimeError('nonfinite source')
            vertices.append(p)
        elif q[0]=='f':
            if len(q)!=4:raise RuntimeError('nontriangle source')
            faces.append([int(v.split('/')[0])-1 for v in q[1:]])
    if (len(vertices),len(faces))!=(51965,87370):raise RuntimeError('source cardinality mismatch')
    points=vtk.vtkPoints();points.SetDataTypeToDouble();cells=vtk.vtkCellArray()
    for p in vertices:points.InsertNextPoint(*p)
    for i,p in enumerate(vertices):
        if tuple(p)!=points.GetPoint(i):raise RuntimeError('source vertex roundtrip changed')
    for f in faces:
        if min(f)<0 or max(f)>=len(vertices):raise RuntimeError('invalid source index')
        cells.InsertNextCell(3)
        for i in f:cells.InsertCellPoint(i)
    mesh=vtk.vtkPolyData();mesh.SetPoints(points);mesh.SetPolys(cells)
    if mesh.GetNumberOfCells()!=len(faces):raise RuntimeError('source cell identity mismatch')
    for i,f in enumerate(faces):
        cell=mesh.GetCell(i)
        if [cell.GetPointId(j)for j in range(3)]!=f:raise RuntimeError('source face mapping changed')
    surface=ReferenceSurface(mesh);I=np.eye(4);T=np.eye(4);T[1,3]=FLOOR_Y;body=BodyGeometry()
    def local(p):
        q=np.array(p,dtype=float);q[1]-=FLOOR_Y;return q
    def scorer(transform,ground=None):
        if ground is None:
            ids=np.array([],dtype=np.int64);ids.setflags(write=False);a=np.array(transform,copy=True);a.setflags(write=False)
            ground=GroundSupport(ids,{'classification':'unknown','seedComponentComputed':False},surface,mesh,int(mesh.GetMTime()),a)
        s=GroundedReferenceContainer(surface,transform,ground=ground,body=body);scorers.append(s);return s
    def sweep(s,a,b,yaw,dyaw):
        check_budget();r=s.swept_contacts(a,b,yaw,dyaw);check_budget()
        for k in ('actualBody','horizontalMargin'):
            r[k]['rawContactCount']=r[k]['groundContactCount']+r[k]['nonGroundContactCount']
            r[k]['groundClassificationSemantic']=False
        return r
    def initial_ground(path):
        base=OrientedReferenceContainer(surface,T,body=body);scorers.append(base);check_budget()
        initial=base.support_probes(local(path['chain'][0]),path['initialYaw']);check_budget();checked=support_check(initial)
        if not checked['acceptedFiniteSupportModel']:return None,initial,checked,'initialFiniteSupportRejected'
        seeds=[int(p['referenceCellID'])for p in initial['probes']]
        try:g=GroundSupport.from_scorer(base,np.asarray([local(p)for p in path['chain']]),seeds)
        except (ValueError,RuntimeError)as exc:return None,initial,checked,type(exc).__name__+': '+str(exc)
        return g,initial,checked,None
    logfile=out/'CONTACTS.jsonl.gz'
    with gzip.open(logfile,'xt',encoding='utf8') as log:
        def emit(row):
            nonlocal logical
            text=json.dumps(row,separators=(',',':'),allow_nan=False)+'\n';logical+=len(text.encode())
            if logical>MAX_LOGICAL:raise RuntimeError('logical output cap')
            log.write(text);log.flush()
            if sum(p.stat().st_size for p in out.iterdir() if p.is_file())>MAX_COMPRESSED:raise RuntimeError('aggregate output cap')
        try:
            for path in schedule['paths']:
                key=[path['start'],path['goal']];raw=[];a=scorer(I)
                for n,e in enumerate(path['events']):
                    r=sweep(a,e['a'],e['b'],e['yaw'],e['dyaw']);raw.append(tuple(r[k]['rawContactCount']for k in ('actualBody','horizontalMargin')))
                    emit({'path':key,'arm':'A_raw_identity','event':n,'kind':e['kind'],'contacts':r})
                summaries.append({'path':key,'arm':'A','events':len(raw),'status':'sourceContactDiagnosticComplete'})
                g,initial,checked,reason=initial_ground(path)
                emit({'path':key,'arm':'B_initial','probes':initial,'finiteSupport':checked,'failure':reason,'ground':None if g is None else g.receipt})
                if g is None:
                    summaries.extend({'path':key,'arm':arm,'events':0,'status':'groundClassificationUnavailable','reason':reason}for arm in ('B','C'));continue
                np.save(out/('GROUND_IDS_%d_%d.npy'%tuple(key)),g.ground_cell_ids,allow_pickle=False)
                b=scorer(T,g)
                for n,e in enumerate(path['events']):
                    r=sweep(b,local(e['a']),local(e['b']),e['yaw'],e['dyaw']);counts=tuple(r[k]['rawContactCount']for k in ('actualBody','horizontalMargin'))
                    if counts!=raw[n]:raise RuntimeError('raw count frame invariance failure')
                    emit({'path':key,'arm':'B_translated_labels_only','event':n,'contacts':r,'rawCountsEqualIdentity':True})
                summaries.append({'path':key,'arm':'B','events':len(raw),'status':'labelOnlyDiagnosticComplete'})
                c=scorer(T,g);state=local(path['chain'][0]);state[1]=checked['heightMaximum'];cstatus='comparisonComplete';done=0
                emit({'path':key,'arm':'C_start','originalStart':path['chain'][0],'adjustedLocalStart':state.tolist(),'verticalCorrection':float(state[1]-local(path['chain'][0])[1])})
                for n,e in enumerate(path['events']):
                    check_budget()
                    if e['kind'] in ('initial','terminal','stationary'):
                        r=sweep(c,state,state,e['yaw'],0.);emit({'path':key,'arm':'C_ground_follow','event':n,'stateLocal':state.tolist(),'contacts':[r]});done+=1
                        if any(r[k]['nonGroundContactCount'] for k in ('actualBody','horizontalMargin')):
                            cstatus='nonGroundCandidateContactStopped';break
                        continue
                    proposed=state.copy();proposed[[0,2]]=np.asarray(e['b'])[[0,2]]
                    segment,checks,motion=proposed_ground_motion(c,g,state,proposed,e['yaw'],e['dyaw']);check_budget()
                    if segment is None:
                        cstatus='finiteSupportOr3DCapRejected';emit({'path':key,'arm':'C_ground_follow','event':n,'failure':cstatus,'support':checks,'motion':motion});break
                    mid,end=segment;contacts=[]
                    for x,y,yaw,delta in ((state,mid,e['yaw'],e['dyaw']*.5),(mid,end,e['yaw']+e['dyaw']*.5,e['dyaw']*.5)):
                        contacts.append(sweep(c,x,y,yaw,delta))
                    emit({'path':key,'arm':'C_ground_follow','event':n,'nominalEnd':e['b'],'adjustedMidLocal':mid.tolist(),'adjustedEndLocal':end.tolist(),'support':checks,'motion':motion,'contacts':contacts})
                    done+=1
                    if any(r[k]['nonGroundContactCount'] for r in contacts for k in ('actualBody','horizontalMargin')):
                        cstatus='nonGroundCandidateContactStopped';break
                    state=end
                source_end=state.copy();source_end[1]+=FLOOR_Y
                summaries.append({'path':key,'arm':'C','events':done,'status':cstatus,'lastAcceptedSourcePosition':source_end.tolist(),'requestedGoal':path['chain'][-1],'arrivalClaimed':False})
            status='diagnosticCompleted'
        except Exception as exc:
            status='abortedUnknown';error=type(exc).__name__+': '+str(exc)
    receipt={'status':status,'error':error,'runtime':runtime,'counters':totals(),'wallSeconds':time.monotonic()-began,'outputLogicalBytes':logical,'arms':summaries,'physicalAuthority':False,'continuousSupportProven':False,'semanticFloorEstablished':False,'coverageEstablished':False,'movementEpisode':False,'sourceMeshSHA256':MESH_SHA,'pinsSHA256':args.pins_sha256,'limitations':['all-hit conservative OBB overlaps, not exact body contacts','nine support rays can miss holes and low objects','first witness is locator order, not contact time','triangle budget checked after native query, bounded two-query body/margin overshoot <=174740 triangles','external aggregate guard required; this worker does not establish hard RAM/process-tree limits']}
    (out/'RECEIPT.json').write_text(json.dumps(receipt,indent=2,allow_nan=False)+'\n')
    print(json.dumps({'status':status,'counters':totals(),'error':error}),flush=True)
    return 0 if status=='diagnosticCompleted' else 2
if __name__=='__main__':sys.exit(main())

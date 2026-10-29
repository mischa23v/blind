"""EXPORT VARIANT, NOT EXECUTED. Private fixture and original launch authority omitted; non-standalone."""
import private_fixture_config as fixture # intentionally not distributed
from pathlib import Path
import ctypes as C,gc,hashlib,json,os,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1];OUT=H/'run'
CELLS=fixture.cells
D=[(-1,0),(0,1),(1,0),(0,-1)]
def check(ok,message):
    if not ok:raise RuntimeError(message)
def digest(path):
    h=hashlib.sha256()
    with path.open('rb')as f:
        for b in iter(lambda:f.read(1048576),b''):h.update(b)
    return h.hexdigest()
def dump(name,obj):
    data=(json.dumps(obj,separators=(',',':'),allow_nan=False)+'\n').encode()
    check(len(data)<=8*1024**2,'single-json-output-cap')
    with (OUT/name).open('xb')as f:f.write(data)

def compare_saved(a,got,events):
    # Same saved-span compact-link and 2/3 scan replay as pinned replay_saved.py,
    # scoped to all saved layers, with no floor band or reference samples.
    a=a.tolist();cols={}
    for i,r in enumerate(a):cols.setdefault(tuple(r[:2]),[]).append(i)
    ceiling={}
    for ids in cols.values():
        for k,i in enumerate(ids):ceiling[i]=a[ids[k+1]][2] if k+1<len(ids)else 65535
    raw=[i for i,r in enumerate(a)if r[6]];index={r:i for i,r in enumerate(raw)};cc={}
    for i in raw:cc.setdefault(tuple(a[i][:2]),[]).append(i)
    height={i:min(ceiling[i]-a[i][3],255)for i in raw};con={}
    for i in raw:
        r=a[i];links=[]
        for dx,dz in D:
            choice=None
            for j in cc.get((r[0]+dx,r[1]+dz),[]):
                if min(r[3]+height[i],a[j][3]+height[j])-max(r[3],a[j][3])>=61 and abs(a[j][3]-r[3])<=2:
                    choice=j;break
            links.append(choice)
        con[i]=links
    dist={i:0 if None in con[i] else 255 for i in raw};seed={i:i if dist[i]==0 else None for i in raw}
    for reverse,dirs in [(False,[(0,3),(3,2)]),(True,[(2,1),(1,0)])]:
        for cell in sorted(cc,key=lambda q:(q[1],q[0]),reverse=reverse):
            for i in cc[cell]:
                for cardinal,diagonal in dirs:
                    j=con[i][cardinal]
                    if j is None:continue
                    for other,cost in [(j,2),(con[j][diagonal],3)]:
                        if other is None:continue
                        value=min(dist[other]+cost,255)
                        if value<dist[i]:dist[i]=value;seed[i]=seed[other]
    check(len(got)==len(raw),'compact-count')
    for k,i in enumerate(raw):
        r=a[i];expect=[r[0],r[1],r[3],height[i],r[6],r[7],dist[i],-1 if seed[i]is None else index[seed[i]]]+[-1 if j is None else index[j]for j in con[i]]
        check(got[k].tolist()==expect,'native-saved-link-distance-seed-mismatch')
    latest={}
    for k,(span,parent,distance)in enumerate(events):
        check(0<=span<len(raw)and -1<=parent<k,'invalid-event-ancestry');latest[int(span)]=k
    selected=[]
    for k,i in enumerate(raw):
        if tuple(a[i][:2])not in CELLS:continue
        path=[];e=latest.get(k,-1)
        while e>=0:
            span,parent,distance=map(int,events[e]);path.append({'rawSpanRow':raw[span],'cellXZ':a[raw[span]][:2],'distance':distance});e=parent
            check(len(path)<=256,'ancestry-length-cap')
        path.reverse()
        check(not path or path[0]['rawSpanRow']==seed[i],'seed-chain-disagreement')
        selected.append({'rawSpanRow':i,'nativeRow':got[k].tolist(),'snapshotSeedAncestry':path})
    return selected

def main():
    # Original admission checks, frozen compiler invocation and private runtime paths
    # are NOT distributed. This export cannot launch the private experiment.
    raise RuntimeError('Non-standalone preservation export; no execution authority')
    frozen=fixture.metadata
    import numpy as np
    import vtk
    from mesh_reader import read_mesh
    from reader_fixtures import run as fixtures
    check(np.__version__=='2.3.5' and vtk.vtkVersion.GetVTKVersion()=='9.3.1','runtime-version')
    vtk.vtkMultiThreader.SetGlobalMaximumNumberOfThreads(1);vtk.vtkMultiThreader.SetGlobalDefaultNumberOfThreads(1)
    check(vtk.vtkSMPTools.SetBackend('Sequential'),'vtk-sequential')
    lib=C.CDLL(str(OUT/'libprovenance.so'));ptr=C.c_void_p
    lib.provenance_compact.argtypes=[ptr,C.c_int,ptr,C.c_int,ptr,C.c_int,ptr];lib.provenance_compact.restype=C.c_int
    lib.provenance_raster.argtypes=[ptr,C.c_int,ptr,C.c_int,ptr];lib.provenance_raster.restype=C.c_int
    def compact(a):
        check(a.dtype==np.int32 and a.ndim==2 and a.shape[1]==9 and 0<len(a)<=200000,'span-input')
        a=np.ascontiguousarray(a);output=np.empty((len(a),12),np.int32);events=np.empty((9*len(a),3),np.int32);count=C.c_int()
        n=lib.provenance_compact(a.ctypes.data,len(a),output.ctypes.data,len(a),events.ctypes.data,len(events),C.byref(count))
        check(n>=0,'native-compact-status:'+str(n));return output[:n].copy(),events[:count.value].copy()
    def raster(q):
        q=np.ascontiguousarray(q,np.float32);check(q.shape[1:]==(3,3)and len(q)<=2000,'triangle-input')
        output=np.empty((50000,5),np.int32);marks=np.empty(len(q),np.uint8)
        n=lib.provenance_raster(q.ctypes.data,len(q),output.ctypes.data,len(output),marks.ctypes.data)
        check(n>=0,'native-raster-status:'+str(n));return output[:n].copy(),marks
    dump('FIXTURES.json',fixtures(compact,raster))
    for model in frozen['models']:
        name=model['name'];a=np.load(ROOT/model['spans'],allow_pickle=False);got,events=compact(a)
        selected=compare_saved(a,got,events)
        saved_replay=json.loads((fixture.saved_replay_path).read_text())['models'][name]
        by_raw={r['rawSpanRow']:r for r in selected}; saved_chain_checks=0
        for target in saved_replay['targets']:
            if tuple(target['cellXZ'])not in CELLS:continue
            for prior in target['spanAttributions']:
                if 'replayedBoundaryDistanceUnits'not in prior:continue
                current=by_raw[prior['row']]
                check(current['nativeRow'][6]==prior['replayedBoundaryDistanceUnits'],'saved-replay-distance')
                check([r['rawSpanRow']for r in current['snapshotSeedAncestry']]==prior['replayedSeedPathRows'],'saved-replay-chain')
                saved_chain_checks+=1
        check(saved_chain_checks>0,'no-overlapping-saved-replay-control')
        del saved_replay
        np.save(OUT/(name+'_COMPACT.npy'),got);np.save(OUT/(name+'_EVENTS.npy'),events)
        del got,events;gc.collect()
        mesh,vertices,faces=read_mesh(ROOT/model['mesh'],model['vertices'],model['triangles'])
        # Candidate selection in exact Float32 ingress Q; 0.00001m padding,
        # no height, normal, floor, reference or endpoint predicate.
        chosen=[];work=0;cs=float(np.float32(.04));padding=1e-5;ox=fixture.input_min[0];oz=fixture.input_min[2]
        for start in range(0,len(faces),20000):
            q=np.ascontiguousarray(vertices[faces[start:start+20000]][:,:,[0,2,1]]*np.array([1,1,-1]),np.float32)
            lo=q.min(axis=1);hi=q.max(axis=1);mask=np.zeros(len(q),bool)
            for x,z in CELLS:
                mask|=(lo[:,0]<=ox+(x+1)*cs+padding)&(hi[:,0]>=ox+x*cs-padding)&(lo[:,2]<=oz+(z+1)*cs+padding)&(hi[:,2]>=oz+z*cs-padding)
            ids=np.flatnonzero(mask)+start;chosen.extend(map(int,ids));check(len(chosen)<=2000,'candidate-cap')
        ids=np.asarray(chosen,np.int64);original=vertices[faces[ids]].copy()
        q=np.ascontiguousarray(original[:,:,[0,2,1]]*np.array([1,1,-1]),np.float32)
        # Conservative expanded/clamped grid AABB work estimate. Refuse, never crop.
        if len(q):
            low=np.floor((q.min(axis=1)[:,[0,2]].astype(np.float64)-np.array([ox,oz]))/cs).astype(np.int64)-2
            high=np.floor((q.max(axis=1)[:,[0,2]].astype(np.float64)-np.array([ox,oz]))/cs).astype(np.int64)+2
            low=np.maximum(low,0);high=np.minimum(high,[fixture.width-1,fixture.height-1]);sizes=np.maximum(high-low+1,0)
            work=2*int(np.sum(sizes[:,0]*sizes[:,1]));check(work<=2000000,'raster-AABB-work-cap')
        records,marks=raster(q)
        for j,cell in enumerate(CELLS):
            native=records[(records[:,0]==-1)&(records[:,1]==j),2:5]
            saved=a[(a[:,0]==cell[0])&(a[:,1]==cell[1])][:,[2,3,4]]
            check(np.array_equal(native,saved),'raw-column-union-parity:'+name+str(cell))
        normals=np.cross(q[:,1]-q[:,0],q[:,2]-q[:,0]);length=np.linalg.norm(normals,axis=1)
        triangles=[]
        for t,tid in enumerate(chosen):
            triangles.append({'originalTriangleID':tid,'datasetXYZOriginal':original[t].tolist(),'nativeQFloat32':q[t].tolist(),
                'signedNormalQUnnormalizedFloat32':normals[t].tolist(),'normalLengthFloat32':float(length[t]),'releasedMarkArea':int(marks[t]),
                'exactCellContributions':records[records[:,0]==t,1:].tolist()})
        dump(name+'_PROVENANCE.json',{'fixedCellsXZ':CELLS,'candidateCount':len(chosen),'rasterAABBCellWork':work,'allRawColumnUnionsExact':True,
              'allNativeCompactLinksHeightsDistancesSeedsAndErosionExact':True,'savedReplayChainControls':saved_chain_checks,'selectedCompact':selected,'triangles':triangles,
              'unionColumns':records[records[:,0]==-1,1:].tolist(),'strictRouteAdmission':False,'physicalAuthority':False})
        del a,mesh,vertices,faces,original,q,records,marks,triangles,selected;gc.collect()
    dump('SUMMARY.json',{'status':'parity-passed-observer-only','success':True,'models':2,'fixedCells':17,'newRoutes':0,'newWitnesses':0,'referenceGeometryLoaded':False,'parametersChanged':False,'physicalAuthority':False})
    return 0
if __name__=='__main__':
    check(sys.argv[1:]==['--worker'],'guard-only');sys.exit(main())

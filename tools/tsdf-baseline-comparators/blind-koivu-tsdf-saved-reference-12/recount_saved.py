"""Independent saved-array arithmetic recount. No evaluator/geometry imports or rays.

Execute only after the owner releases the CPU slot and evaluation is terminal.
The script additionally requires a successful terminal runner receipt. Matching
arithmetic is not independent sensor accuracy, localization or safety validation.
"""
from pathlib import Path
import argparse, hashlib, json, math, os, resource, signal, stat, sys, time, zipfile

for _name in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS'):
    os.environ[_name]='1'
import numpy as np

ROOT=Path(__file__).resolve().parent
EXPECTED_IDS=[f'frame_{i:05d}'for i in (1,5,9,13,17,21,25,29)]
SHAPE=(249,185);PER_FRAME=46065;TOTAL=368520
RESERVE=768*1024**2;MAX_RSS=384*1024**2;MAX_OUTPUT=1024**2
STAT_FIELDS=('meanSigned','signedP05','signedP50','signedP95','MAE','absoluteP50','absoluteP90','absoluteP95','absoluteP99','maximumAbsolute')
RANGE_NAMES=('positive_below015','015_to_below1','1_to_below2','2_to_below3','3_to_below4','4_to_below5','5_and_above')
EDGE_NAMES=('missing_centre','scheduled_raster_boundary','missing_neighbour','delta_le_002','delta_gt002_le010','delta_gt010')
KEYS={'row','column','savedReferenceAxialMetres','predictedTSDFLocalAxialMetres','TSDFCellID','referenceCellID','savedReferenceEdgeCode'}
checks=0;float_comparisons=0;max_difference=0.;started=0.

def need(ok,message):
    global checks
    checks+=1
    if not ok:raise ValueError(message)

def budget():
    need(time.monotonic()-started<45.,'45-second recount wall cap')
    need(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024<=MAX_RSS,'384 MiB observed peak RSS cap')
    need(os.statvfs(ROOT).f_bavail*os.statvfs(ROOT).f_frsize>=RESERVE,'768 MiB free reserve')

def digest(path,maximum):
    path=Path(path);need(not path.is_symlink(),'symlink input: '+str(path))
    with path.open('rb')as f:
        a=os.fstat(f.fileno());need(stat.S_ISREG(a.st_mode) and a.st_size<=maximum,'input type/size: '+str(path))
        h=hashlib.sha256()
        for block in iter(lambda:f.read(1<<20),b''):h.update(block)
        b=os.fstat(f.fileno())
    identity=lambda s:(s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
    need(identity(a)==identity(b)==identity(path.stat()),'input changed while hashing: '+str(path))
    return {'path':str(path),'bytes':a.st_size,'sha256':h.hexdigest()}

def read_json(path,maximum=2*1024**2):
    pin=digest(path,maximum)
    obj=json.loads(Path(path).read_text())
    need(digest(path,maximum)==pin,'JSON changed while reading')
    return obj,pin

def linear_percentiles(sorted_values,probabilities):
    # Independent linear order-statistic interpolation; not np.quantile.
    last=len(sorted_values)-1;out=[]
    for q in probabilities:
        position=last*q;lo=int(math.floor(position));hi=int(math.ceil(position));t=position-lo
        a=float(sorted_values[lo]);b=float(sorted_values[hi])
        out.append(a+(b-a)*t)
    return out

def describe_errors(values):
    values=np.asarray(values,dtype=np.float64);count=int(values.size)
    if not count:return {'count':0,**{k:None for k in STAT_FIELDS}}
    need(bool(np.isfinite(values).all()),'nonfinite residual in paired error group')
    ordered=np.sort(values);absolute=np.sort(np.abs(values))
    signed=linear_percentiles(ordered,(.05,.5,.95));aq=linear_percentiles(absolute,(.5,.9,.95,.99))
    numbers=[math.fsum(values)/count,*signed,math.fsum(absolute)/count,*aq,float(absolute[-1])]
    return {'count':count,**dict(zip(STAT_FIELDS,numbers))}

def edge_codes(depth):
    # Independent neighbour slicing and sequential bin assignment; boundaries
    # stay separate and missing centres stay -1, including raster boundaries.
    valid=np.isfinite(depth)&(depth>0)
    code=np.full(depth.shape,-1,np.int8);code[valid]=0
    core=depth[1:-1,1:-1];centre=valid[1:-1,1:-1]
    neighbours=(depth[:-2,1:-1],depth[2:,1:-1],depth[1:-1,:-2],depth[1:-1,2:])
    supported=np.ones(core.shape,bool);delta=np.zeros(core.shape,np.float64)
    for neighbour in neighbours:
        supported&=np.isfinite(neighbour)&(neighbour>0)
        delta=np.maximum(delta,np.abs(neighbour-core))
    interior=code[1:-1,1:-1]
    interior[centre&~supported]=1
    complete=centre&supported;interior[complete]=2
    interior[complete&(delta>.02)]=3;interior[complete&(delta>.10)]=4
    return code

def summarize(reference,predicted,edge):
    reference=np.asarray(reference,dtype=np.float64);predicted=np.asarray(predicted,dtype=np.float64)
    rv=np.isfinite(reference);pv=np.isfinite(predicted);paired=rv&pv;error=predicted-reference
    # Independent integer four-state cross-tab; no sensor values enter this code.
    counts=np.bincount((2*rv.astype(np.int8)+pv.astype(np.int8)).ravel(),minlength=4)
    availability={'scheduled':int(reference.size),'paired':int(counts[3]),
        'referenceOnly':int(counts[2]),'TSDFOnly':int(counts[1]),'neither':int(counts[0])}
    need(int(counts.sum())==reference.size,'four-class denominator')
    def group(mask):
        return {'scheduled':int(np.count_nonzero(mask)),'referenceValid':int(np.count_nonzero(mask&rv)),
            'TSDFHit':int(np.count_nonzero(mask&pv)),'statistics':describe_errors(error[mask&paired])}
    bounds=((0.,.15),(.15,1.),(1.,2.),(2.,3.),(3.,4.),(4.,5.),(5.,math.inf))
    ranges=[{'label':label,**group(rv&(reference>=lo)&(reference<hi))}
        for label,(lo,hi)in zip(RANGE_NAMES,bounds)]
    need(sum(r['scheduled']for r in ranges)==int(rv.sum()),'reference range-bin denominator')
    edges=[{'label':label,'code':i-1,**group(edge==i-1)}for i,label in enumerate(EDGE_NAMES)]
    need(sum(r['scheduled']for r in edges)==reference.size,'saved reference edge denominator')
    return {'availability':availability,'allPairedStatistics':describe_errors(error[paired]),
        'referenceBelow4Statistics':describe_errors(error[paired&(reference<4)]),
        'reference4AndAboveStatistics':describe_errors(error[paired&(reference>=4)]),
        'byReferenceDepth':ranges,'bySavedReferenceEdge':edges}

def compare(actual,recorded,path):
    global float_comparisons,max_difference
    if isinstance(actual,dict):
        need(isinstance(recorded,dict) and set(actual)==set(recorded),'keys mismatch: '+path)
        for k in actual:compare(actual[k],recorded[k],path+'/'+k)
    elif isinstance(actual,list):
        need(isinstance(recorded,list) and len(actual)==len(recorded),'list shape: '+path)
        for i,(a,b)in enumerate(zip(actual,recorded)):compare(a,b,path+'/'+str(i))
    elif isinstance(actual,float):
        need(isinstance(recorded,(float,int)) and not isinstance(recorded,bool) and math.isfinite(recorded),'nonfinite/wrong numeric type: '+path)
        difference=abs(actual-recorded);max_difference=max(max_difference,difference);float_comparisons+=1
        need(math.isclose(actual,recorded,rel_tol=2e-12,abs_tol=2e-12),'statistic mismatch: '+path+': '+repr((actual,recorded)))
    else:need(type(actual)is type(recorded) and actual==recorded,'exact mismatch: '+path+': '+repr((actual,recorded)))

def main():
    global started
    if sys.flags.optimize:raise RuntimeError('normal interpreter mode required')
    ap=argparse.ArgumentParser();ap.add_argument('--run',type=Path,default=ROOT/'run-01')
    ap.add_argument('--frozen',type=Path,default=ROOT/'FROZEN.json');ap.add_argument('--frozen-sha',required=True)
    ap.add_argument('--output',type=Path,default=ROOT/'POSTRUN_RECOUNT.json');args=ap.parse_args()
    need(args.output.parent.resolve()==ROOT and not args.output.exists() and not args.output.is_symlink(),'new output must be an immediate stage JSON file')
    started=time.monotonic();cpu0=time.process_time();resource.setrlimit(resource.RLIMIT_CPU,(30,30))
    resource.setrlimit(resource.RLIMIT_AS,(2*1024**3,)*2)
    signal.signal(signal.SIGALRM,lambda *_:(_ for _ in ()).throw(TimeoutError('45-second recount wall limit')));signal.alarm(45)
    hashes=[];frame_reports=[];failure=None;report={}
    try:
        budget();hashes.append(digest(Path(__file__),1024**2))
        fp=digest(args.frozen,1024**2);need(fp['sha256']==args.frozen_sha,'frozen SHA mismatch before parse')
        frozen,fp2=read_json(args.frozen,1024**2);need(fp==fp2,'frozen changed while parsing');hashes.append(fp)
        need(frozen['frameIDs']==EXPECTED_IDS,'frozen ordered eight IDs')
        need(frozen['schedule']=={'height':994,'pixelOffset':0.5,'raysPerFrame':PER_FRAME,'stride':4,'totalRays':TOTAL,'width':738},'frozen pixel schedule')
        terminal,tp=read_json(args.run/'RUN_RECEIPT.json');hashes.append(tp)
        need(terminal['status']=='completed both serial modes; evaluator owns scientific conclusions' and terminal['sourceAndInputHashesVerifiedBeforeAndAfter'] is True,'evaluation is not successfully terminal')
        need([m['mode']for m in terminal['modes']]==['conventions','evaluate'] and all(m['exitCode']==0 for m in terminal['modes']),'terminal modes incomplete')
        need(any(p['role']=='manifest' and p['sha256']==args.frozen_sha and Path(p['path']).resolve()==args.frozen.resolve() for p in terminal['pins']),'terminal frozen association')
        result_path=args.run/'evaluate/artifacts/result.json';result,rp=read_json(result_path);hashes.append(rp)
        need(terminal['modes'][1]['resultSHA256']==rp['sha256'],'runner/result hash mismatch')
        need(Path(terminal['modes'][1]['resultPath']).resolve()==result_path.resolve(),'runner result association')
        need(result['frameCount']==8 and result['frameIDs']==EXPECTED_IDS and result['sampleStride']==4 and result['pixelOffset']==.5,'result schedule mismatch')
        need(result['integratedViewCount']==7 and result['excludedViewCount']==1,'view association counts')
        need(result['residualSign']=='TSDF axial depth minus saved reference axial depth','residual sign declaration')
        need(all(result[k]is False for k in ['fullFAROMeshOpened','referenceRaysRecomputed','referenceScaleAppliedAgain','meshChanged','fittingPerformed','savedSensorDepthUsedToSelectRays','missingGeometryImpliesFree','referenceMeasuredVersusEditedMaskAvailable','physicalAuthority','navigationCalled']),'result interpretation changed')
        need(len(result['frames'])==len(result['artifacts'])==8,'frame/artifact count')
        artifacts={r['path']:r for r in result['artifacts']};names={name+'-rays.npz'for name in EXPECTED_IDS}
        need(set(artifacts)==names and {p.name for p in result_path.parent.glob('*-rays.npz')}==names,'artifact filenames/duplicates')
        expected_row=np.repeat((np.arange(249,dtype=np.uint16)*4)[:,None],185,axis=1)
        expected_column=np.repeat((np.arange(185,dtype=np.uint16)*4)[None,:],249,axis=0)
        ref_pool=[];pred_pool=[];edge_pool=[]
        for index,name in enumerate(EXPECTED_IDS):
            budget();path=result_path.parent/(name+'-rays.npz');pin=digest(path,4*1024**2);hashes.append(pin)
            need(pin['bytes']==artifacts[path.name]['bytes'] and pin['sha256']==artifacts[path.name]['sha256'],'NPZ artifact hash: '+name)
            with zipfile.ZipFile(path)as archive:
                infos=archive.infolist();need(len(infos)==7 and {x.filename for x in infos}=={k+'.npy'for k in KEYS},'NPZ exact members')
                need(sum(x.file_size for x in infos)<=2*1024**2 and all(not x.flag_bits&1 for x in infos),'NPZ expansion/type bound')
            with np.load(path,allow_pickle=False)as saved:
                need(set(saved.files)==KEYS,'array names');values={k:saved[k]for k in KEYS}
            types={'row':np.uint16,'column':np.uint16,'savedReferenceAxialMetres':np.float64,'predictedTSDFLocalAxialMetres':np.float64,'TSDFCellID':np.int64,'referenceCellID':np.int64,'savedReferenceEdgeCode':np.int8}
            for key,value in values.items():
                need(value.shape==SHAPE,'array shape: '+name+'/'+key)
                need(value.dtype==np.dtype(types[key]),'array dtype: '+name+'/'+key)
            need(np.array_equal(values['row'],expected_row) and np.array_equal(values['column'],expected_column),'original ordered row/column schedule')
            reference=values['savedReferenceAxialMetres'];pred=values['predictedTSDFLocalAxialMetres'];edge=values['savedReferenceEdgeCode']
            for label,depth,cell in [('reference',reference,values['referenceCellID']),('TSDF',pred,values['TSDFCellID'])]:
                hit=np.isfinite(depth)
                need(bool((np.isfinite(depth)|np.isnan(depth)).all()) and bool((depth[hit]>0).all()),label+' depth is not positive Float64 or NaN')
                need(bool(((cell==-1)|(cell>=0)).all()) and np.array_equal(hit,cell>=0) and np.array_equal(np.isnan(depth),cell==-1),label+' no-hit/NaN/-1 mismatch')
            need(bool((values['TSDFCellID']<frozen['expectedMesh']['triangles']).all()),'TSDF cell upper bound')
            need(np.array_equal(edge_codes(reference),edge),'independent saved-reference edge mismatch: '+name)
            actual=summarize(reference,pred,edge);recorded=result['frames'][index]
            need(recorded['frameID']==name and recorded['index']==index and recorded['usedByTSDFIntegration']is(name!='frame_00021'),'per-frame order/integration association')
            compare(actual,{k:recorded[k]for k in actual},name)
            frame_reports.append({'frameID':name,**actual})
            ref_pool.append(reference.ravel());pred_pool.append(pred.ravel());edge_pool.append(edge.ravel())
        budget();pooled=summarize(np.concatenate(ref_pool),np.concatenate(pred_pool),np.concatenate(edge_pool))
        compare(pooled,result['pooledRayWeighted'],'pooledRayWeighted');need(pooled['availability']['scheduled']==TOTAL,'total 368,520 rays')
        for pin in hashes:need(digest(pin['path'],4*1024**2)==pin,'input changed during recount: '+pin['path'])
        budget()
        report={'success':True,'scope':'Independent saved-array arithmetic recount, not new geometry or physical truth',
            'frameCount':8,'scheduledRays':TOTAL,'pooledRayWeighted':pooled,'frames':frame_reports,
            'allRangeAndEdgeStatisticsReconciled':True,'fourWayAvailabilityReconciled':True,
            'quantileMethod':'independent sorted order statistics and linear interpolation; no evaluator import',
            'meanMethod':'math.fsum/count independently of evaluator NumPy mean',
            'comparisonTolerance':{'relative':2e-12,'absolute':2e-12},'floatComparisons':float_comparisons,
            'maximumAbsoluteStatisticDifference':max_difference,'checks':checks,'hashes':hashes,
            'geometryLoaded':False,'raysCast':0,'fullFAROMeshOpened':False,'sensorValuesUsed':False,
            'limitsNote':'Uses saved reference/prediction arrays. Verifies arithmetic and denominator consistency, not original reference authenticity, registration, physical accuracy, hazard misses, clearance or navigation. Mostly training views; missing geometry remains unknown.'}
    except BaseException as exc:
        failure=exc;report={'success':False,'error':repr(exc),'checks':checks,'completedFrames':len(frame_reports),'hashes':hashes,'noValidationPassClaim':True}
    finally:
        signal.alarm(0)
        report['sourceSHA256']=digest(Path(__file__),1024**2)['sha256']
        report['resources']={'wallSeconds':time.monotonic()-started,'CPUSeconds':time.process_time()-cpu0,'peakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,
            'limits':{'cpuSeconds':30,'wallSeconds':45,'observedRSSBytes':MAX_RSS,'addressSpaceBytes':2*1024**3,'outputBytes':MAX_OUTPUT,'freeReserveBytes':RESERVE},
            'enforcement':'process CPU/address-space/alarm limits plus sampled peak-RSS/free-space checks, not a cgroup'}
        data=(json.dumps(report,indent=2,sort_keys=True,allow_nan=False)+'\n').encode()
        need(len(data)<=MAX_OUTPUT,'recount output size cap')
        need(os.statvfs(ROOT).f_bavail*os.statvfs(ROOT).f_frsize-len(data)>=RESERVE,'reserve before receipt')
        with args.output.open('xb')as f:f.write(data)
        print(json.dumps({'success':report['success'],'output':str(args.output),'sha256':hashlib.sha256(data).hexdigest(),'bytes':len(data),'resources':report['resources']}))
    if failure is not None:raise failure

if __name__=='__main__':main()

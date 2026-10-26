"""Bounded original-byte inspection; no navigation or hardware accuracy claims."""
from pathlib import Path
import csv, hashlib, importlib.util, json, os, re, resource, shutil, signal, stat, zipfile
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
OLD=ROOT.parent/'blind-raw-iphone-feasibility-01'
CAP=32*1024**2
RESERVE=768*1024**2

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024**2),b''):h.update(b)
    return h.hexdigest()

def main():
    resource.setrlimit(resource.RLIMIT_AS,(768*1024**2,768*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(90,90));signal.alarm(180)
    decoder=module('old_decoder',OLD/'audit_decoded_fields.py').ExactDecoder()
    safe_name=module('old_selection',OLD/'select_recorded_frames.py').safe_name
    selections=json.loads((ROOT/'FROZEN_FRAME_SELECTION.json').read_text())
    indexed={x['clip_id']:x for x in csv.DictReader((ROOT/'index.csv').open())}
    specs=[('EM1-1093',ROOT/'EM1-1093.r3d',55082489,'5cd8b4d03fd7e1ed2ec28d005d4e01209dddd9583029787f85e5b5f65376e6cb',selections['selected17FrameIDs']),
           ('EM1-0387',OLD/'EM1-0387.r3d',13973317,'aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4',selections['selected12FrameIDs'])]
    prepared=[];total_output=0
    # Inventory both archives and validate metadata before extracting any member.
    for clip,path,size,sha,ids in specs:
        if path.stat().st_size!=size or digest(path)!=sha:raise ValueError('archive provenance mismatch')
        with zipfile.ZipFile(path) as z:
            infos=z.infolist();names={};logical=0
            if len(infos)>2000:raise ValueError('member cap')
            for info in infos:
                name=safe_name(info.filename);kind=stat.S_IFMT(info.external_attr>>16)
                if name in names or info.flag_bits&1 or kind not in (0,stat.S_IFREG,stat.S_IFDIR):raise ValueError('ambiguous/unsafe ZIP member')
                if not 0<=info.file_size<=16*1024**2:raise ValueError('member size cap')
                logical+=info.file_size;names[name]=info
            if logical>256*1024**2:raise ValueError('logical archive cap')
            if 'metadata' not in names or names['metadata'].file_size>2*1024**2:raise ValueError('metadata cap')
            raw=z.read(names['metadata']);m=json.loads(raw)
            dims=[m[k] for k in ('dw','dh','w','h')]
            if any(isinstance(v,bool) or not isinstance(v,int) or v<=0 for v in dims):raise ValueError('dimension types')
            dw,dh,w,h=dims
            if dw*dh>1024**2 or w*h>16*1024**2:raise ValueError('dimension cap')
            if dims!=[int(indexed[clip][k]) for k in ('depth_w','depth_h','rgb_w','rgb_h')]:raise ValueError('index dimensions mismatch')
            ts=np.asarray(m['frameTimestamps'],dtype=float);poses=np.asarray(m['poses'],dtype=float);ks=np.asarray(m['perFrameIntrinsicCoeffs'],dtype=float)
            n=int(indexed[clip]['n_frames'])
            if ts.shape!=(n,) or not np.isfinite(ts).all() or not(np.diff(ts)>0).all():raise ValueError('timestamp contract')
            if poses.shape!=(n,7) or ks.shape!=(n,4) or not np.isfinite(poses).all() or not np.isfinite(ks).all():raise ValueError('pose/intrinsic array contract')
            norms=np.linalg.norm(poses[:,:4],axis=1)
            if np.max(np.abs(norms-1))>0.001 or not (ks[:,:2]>0).all():raise ValueError('pose/intrinsic numeric contract')
            if ids!=[k*(n-1)//7 for k in range(8)]:raise ValueError('frozen selection mismatch')
            initial=np.asarray(m['initPose'],dtype=float);K=np.asarray(m['K'],dtype=float)
            if initial.shape!=(7,) or not np.isfinite(initial).all() or abs(np.linalg.norm(initial[:4])-1)>0.001:raise ValueError('initPose contract')
            if K.shape!=(9,) or not np.isfinite(K).all() or K[0]<=0 or K[4]<=0:raise ValueError('K contract')
            selected=['metadata']+[f'rgbd/{i}.{kind}' for i in ids for kind in ('jpg','depth','conf')]
            if any(name not in names for name in selected):raise ValueError('missing frozen frame triples')
            selected_bytes=sum(names[name].file_size for name in selected)
            decoded_bytes=len(ids)*dw*dh*5;total_output+=selected_bytes+decoded_bytes
            prepared.append((clip,path,sha,ids,m,raw,names,logical,selected,selected_bytes,decoded_bytes))
    if total_output>CAP or shutil.disk_usage(ROOT).free<RESERVE+total_output+4*1024**2:raise RuntimeError('combined selected-output/reserve cap')
    stage=ROOT/'audited.partial';final=ROOT/'audited'
    if stage.exists() or final.exists():raise ValueError('exclusive audit outputs')
    stage.mkdir();reports=[]
    for clip,path,sha,ids,m,raw,names,logical,selected,selected_bytes,decoded_bytes in prepared:
        d=stage/clip;d.mkdir();(d/'selected/rgbd').mkdir(parents=True);(d/'decoded').mkdir()
        file_receipts=[];rows=[];manifest=[];counts=np.zeros(3,dtype=np.int64);all_depth=[]
        dw,dh,w,h=[m[k] for k in ('dw','dh','w','h')];ts=np.asarray(m['frameTimestamps']);ks=np.asarray(m['perFrameIntrinsicCoeffs']);poses=np.asarray(m['poses'])
        with zipfile.ZipFile(path) as z:
            for name in selected:
                b=z.read(names[name]);(d/'selected'/name).write_bytes(b)
                file_receipts.append({'name':name,'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()})
        for frame in ids:
            b=decoder.decode((d/f'selected/rgbd/{frame}.depth').read_bytes(),dw*dh*4)
            c=decoder.decode((d/f'selected/rgbd/{frame}.conf').read_bytes(),dw*dh)
            depth=np.frombuffer(b,dtype='<f4').reshape(dh,dw);conf=np.frombuffer(c,dtype=np.uint8).reshape(dh,dw)
            if (conf>2).any():raise ValueError('non-ARKit confidence')
            with Image.open(d/f'selected/rgbd/{frame}.jpg') as im:
                if im.size!=(w,h):raise ValueError('RGB dimension mismatch')
            dp=d/f'decoded/{frame}.depth.f32le';cp=d/f'decoded/{frame}.confidence.u8';dp.write_bytes(b);cp.write_bytes(c)
            cc=np.bincount(conf.ravel(),minlength=3);counts+=cc
            finite=np.isfinite(depth);positive=finite&(depth>0);all_depth.append(depth[positive])
            byconfidence={str(k):{'count':int((conf==k).sum()),'positiveDepthQuantilesM':np.quantile(depth[positive&(conf==k)],[0,.05,.5,.95,1]).tolist() if np.any(positive&(conf==k)) else None} for k in range(3)}
            row={'frameID':frame,'timestamp':float(ts[frame]),'originalConfidenceCounts012':cc.tolist(),'finitePixels':int(finite.sum()),'nonpositiveFinitePixels':int((finite&(depth<=0)).sum()),'positiveDepthQuantilesM':np.quantile(depth[positive],[0,.05,.5,.95,1]).tolist() if positive.any() else None,'byConfidence':byconfidence,'intrinsics':ks[frame].tolist(),'depthSHA256':hashlib.sha256(b).hexdigest(),'confidenceSHA256':hashlib.sha256(c).hexdigest(),'validRange015To5AllPixels':int((finite&(depth>=.15)&(depth<=5)).sum()),'stride2CandidateConfidenceCounts012':np.bincount(conf[::2,::2].ravel(),minlength=3).tolist()}
            rows.append(row)
            manifest.append({'id':frame,'width':dw,'height':dh,'imageWidth':w,'imageHeight':h,'depthPath':str(final/clip/'decoded'/dp.name),'confidencePath':str(final/clip/'decoded'/cp.name),'fx':float(ks[frame,0]),'fy':float(ks[frame,1]),'cx':float(ks[frame,2]),'cy':float(ks[frame,3]),'originalRelativeTimestamp':float(ts[frame])})
        dt=np.diff(ts);values=np.concatenate(all_depth)
        report={'clipID':clip,'archiveSHA256':sha,'deviceProvenance':'Publisher pinned index: '+indexed[clip]['device']+'; exact device/app/OS fields reported below if present','metadataKeys':sorted(m),'deviceOrSoftwareFields':{k:m[k] for k in m if re.search('device|model|version|ios|app|tracking',k,re.I)},'cameraType':m.get('cameraType'),'configuredFPS':m.get('fps'),'dimensions':{'depth':[dw,dh],'rgb':[w,h]},'originalFrameCount':len(ts),'frozenFrameIDs':ids,'timestampSpan':float(ts[-1]-ts[0]),'timestampIntervalsMinMedianMax':np.quantile(dt,[0,.5,1]).tolist(),'effectiveFrameTimestampRate':float((len(ts)-1)/(ts[-1]-ts[0])),'poseQuaternionNormMinMax':[float(np.min(np.linalg.norm(poses[:,:4],axis=1))),float(np.max(np.linalg.norm(poses[:,:4],axis=1)))],'intrinsicsMin':ks.min(axis=0).tolist(),'intrinsicsMax':ks.max(axis=0).tolist(),'metadataKColumnMajor':m['K'],'originalInitPose':m['initPose'],'confidenceCounts012':counts.tolist(),'confidenceFractions012':(counts/counts.sum()).tolist(),'positiveDepthQuantilesM':np.quantile(values,[0,.05,.5,.95,1]).tolist(),'selectedBytes':selected_bytes,'decodedBytes':decoded_bytes,'archiveMemberCount':len(names),'archiveLogicalBytes':logical,'unselectedCRCVerified':False,'selectedMembers':file_receipts,'frames':rows,'trackingState':'unknown; not synthesized','bodyMountCalibration':None,'independentGeometryReference':None,'navigationRun':False,'hardwareAccuracyComparison':False}
        (d/'FIELD_AUDIT.json').write_text(json.dumps(report,indent=2)+'\n');(d/'NATIVE_MANIFEST.json').write_text(json.dumps({'clipID':clip,'frames':manifest},indent=2)+'\n');reports.append(report)
    summary={'scope':'Two unmatched Record3D clips, eight fixed original frames each; input distributions only','newArchiveBytes':55082489,'combinedSelectedAndDecodedBytes':total_output,'freeAfterBytes':shutil.disk_usage(ROOT).free,'reserveBytes':RESERVE,'decoderBinarySHA256':digest(OLD/'decoder/liblzfse_decode.so'),'clips':reports}
    (stage/'COMPLETE_AUDIT.json').write_text(json.dumps(summary,indent=2)+'\n');stage.rename(final)
    print(json.dumps({'scope':summary['scope'],'combinedOutput':total_output,'freeAfter':summary['freeAfterBytes'],'clips':[{k:c[k] for k in ('clipID','deviceOrSoftwareFields','dimensions','originalFrameCount','frozenFrameIDs','configuredFPS','timestampSpan','timestampIntervalsMinMedianMax','effectiveFrameTimestampRate','confidenceCounts012','confidenceFractions012','positiveDepthQuantilesM','intrinsicsMin','intrinsicsMax')} for c in reports]},indent=2))

if __name__=='__main__':main()

"""Bounded actual byte/field audit. No projection, detection, tracking or control."""
from pathlib import Path
import ctypes as C
import hashlib,json,math,resource,shutil,signal,time
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parent
CLIP_SHA='aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4'

def validate_selection(selection):
    expected={'metadata'}|{f'rgbd/{i}.{kind}' for i in range(8) for kind in ('jpg','depth','conf')}
    files=selection.get('files',[])
    if selection.get('clipSHA256')!=CLIP_SHA or selection.get('frameIDs')!=list(range(8)):raise ValueError('unapproved clip/frame selection')
    names=[f.get('name') for f in files]
    if len(names)!=len(expected) or set(names)!=expected:raise ValueError('non-whitelisted source receipt path')

class ExactDecoder:
    def __init__(self):
        path=ROOT/'decoder/liblzfse_decode.so';receipt=json.loads((ROOT/'decoder/BUILD_RECEIPT.json').read_text())
        if hashlib.sha256(path.read_bytes()).hexdigest()!=receipt['binarySHA256']:raise ValueError('changed decoder')
        self.lib=C.CDLL(str(path));self.lib.lzfse_decode_scratch_size.argtypes=[];self.lib.lzfse_decode_scratch_size.restype=C.c_size_t
        self.lib.lzfse_decode_buffer.argtypes=[C.c_void_p,C.c_size_t,C.c_void_p,C.c_size_t,C.c_void_p];self.lib.lzfse_decode_buffer.restype=C.c_size_t
        self.scratch_bytes=self.lib.lzfse_decode_scratch_size()
        if not 0<self.scratch_bytes<=1024**2:raise ValueError('decoder scratch bound')
    def decode(self,data,expected):
        if not isinstance(data,bytes) or not 0<len(data)<=16*1024**2:raise ValueError('compressed input bound')
        if isinstance(expected,bool) or not isinstance(expected,int) or not 0<expected<=4*1024**2:raise ValueError('decoded output bound')
        source=C.create_string_buffer(data,len(data));output=C.create_string_buffer(expected+1);scratch=C.create_string_buffer(self.scratch_bytes)
        # One extra byte is an overflow detector, not permission for larger output.
        count=self.lib.lzfse_decode_buffer(output,expected+1,source,len(data),scratch)
        if count!=expected:raise ValueError(f'decoded byte count {count}, required {expected}')
        return output.raw[:expected]

def main():
    resource.setrlimit(resource.RLIMIT_AS,(512*1024**2,512*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(30,30));signal.alarm(120)
    started=time.monotonic();decoder=ExactDecoder()
    selection=json.loads((ROOT/'SELECTION_RECEIPT.json').read_text());m=json.loads((ROOT/'selected/metadata').read_text())
    validate_selection(selection)
    for f in selection['files']:
        p=ROOT/'selected'/f['name'];b=p.read_bytes()
        if len(b)!=f['bytes'] or hashlib.sha256(b).hexdigest()!=f['sha256']:raise ValueError('changed selected source')
    dw,dh,w,h=[m[k] for k in ('dw','dh','w','h')]
    if any(isinstance(x,bool) or not isinstance(x,int) or x<=0 for x in (dw,dh,w,h)) or dw*dh>1024**2 or w*h>16*1024**2:raise ValueError('image dimension contract')
    times=np.asarray(m['frameTimestamps'],dtype=float);poses=np.asarray(m['poses'],dtype=float);intrinsics=np.asarray(m['perFrameIntrinsicCoeffs'],dtype=float)
    if times.ndim!=1 or not np.isfinite(times).all() or not (np.diff(times)>0).all():raise ValueError('original time ordering invalid')
    if poses.shape!=(len(times),7) or intrinsics.shape!=(len(times),4) or not np.isfinite(poses).all() or not np.isfinite(intrinsics).all():raise ValueError('pose/intrinsic metadata shape')
    initial=np.asarray(m['initPose'],dtype=float);k=np.asarray(m['K'],dtype=float)
    if initial.shape!=(7,) or not np.isfinite(initial).all() or abs(np.linalg.norm(initial[:4])-1)>.001:raise ValueError('invalid initPose shape/quaternion')
    if k.shape!=(9,) or not np.isfinite(k).all() or k[0]<=0 or k[4]<=0:raise ValueError('invalid original intrinsic matrix')
    expected_bytes=8*dw*dh*5;existing=sum(p.stat().st_size for p in (ROOT/'selected').rglob('*') if p.is_file())
    if existing+expected_bytes>64*1024**2 or shutil.disk_usage(ROOT).free<768*1024**2+expected_bytes:raise RuntimeError('output/reserve cap')
    stage=ROOT/'decoded.partial';final=ROOT/'decoded'
    if stage.exists() or final.exists():raise ValueError('refuse decode overwrite')
    stage.mkdir();rows=[];counts=np.zeros(3,dtype=np.int64)
    for frame in selection['frameIDs']:
        if not 0<=frame<len(times):raise ValueError('frame ID has no original metadata')
        prefix=ROOT/'selected/rgbd'/str(frame)
        d=decoder.decode(prefix.with_suffix('.depth').read_bytes(),dw*dh*4)
        c=decoder.decode(prefix.with_suffix('.conf').read_bytes(),dw*dh)
        depth=np.frombuffer(d,dtype='<f4').reshape(dh,dw);confidence=np.frombuffer(c,dtype=np.uint8).reshape(dh,dw)
        if (confidence>2).any():raise ValueError('non-ARKit confidence value')
        with Image.open(prefix.with_suffix('.jpg')) as im:
            rgb_size=im.size;rgb_mode=im.mode
        if rgb_size!=(w,h):raise ValueError('recorded RGB dimensions mismatch')
        finite=np.isfinite(depth);positive=finite&(depth>0);cc=np.bincount(confidence.ravel(),minlength=3);counts+=cc
        output=[]
        for name,data in [(f'{frame}.depth.f32le',d),(f'{frame}.confidence.u8',c)]:
            (stage/name).write_bytes(data);output.append({'path':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        rows.append({'frameID':frame,'originalRelativeTimestamp':float(times[frame]),'rgbSize':rgb_size,'rgbMode':rgb_mode,
            'depthWidth':dw,'depthHeight':dh,'depthFormat':'float32 little-endian metres, original decoded values unchanged',
            'depthFinitePixels':int(finite.sum()),'depthZeroPixels':int((depth==0).sum()),'depthNegativePixels':int((finite&(depth<0)).sum()),
            'depthPositiveRangeMetres':[float(depth[positive].min()),float(depth[positive].max())] if positive.any() else None,
            'originalConfidenceCounts012':cc.tolist(),'confidenceReplaced':False,
            'originalIntrinsicCoefficients':intrinsics[frame].tolist(),'intrinsicCoefficientOrder':'Four original coefficients retained; ordering not independently verified; no projection executed',
            'quaternionNorm':float(np.linalg.norm(poses[frame,:4])),
            'trackingState':'unknown','bodyMountCalibrated':False,'physicalNavigationAuthority':False,'decodedFiles':output})
    receipt={'scope':'Eight actual depth/confidence pairs decoded; eight RGB headers checked. No native perception, projection, localization or navigation pass.',
        'datasetRevision':'a285cd1249fe9762085713a1c796ab68b1810ac2','clipSHA256':selection['clipSHA256'],
        'deviceProvenance':'Publisher pinned index identifies iPhone 12 Pro; device model is not present in this clip metadata',
        'metadataSHA256':hashlib.sha256((ROOT/'selected/metadata').read_bytes()).hexdigest(),
        'originalMetadataKeys':sorted(m),'cameraTypeOriginal':m['cameraType'],'configuredFPS':m['fps'],
        'originalTimestampCount':len(times),'originalPoseCount':len(poses),'originalPerFrameIntrinsicCount':len(intrinsics),
        'timestampSpanSeconds':float(times[-1]-times[0]),'timestampIntervalMinMedianMaxSeconds':[float(np.min(np.diff(times))),float(np.median(np.diff(times))),float(np.max(np.diff(times)))],
        'effectiveIntervalsPerSecond':float((len(times)-1)/(times[-1]-times[0])),
        'selectedFrameIDs':selection['frameIDs'],'selectedDecodedBytes':expected_bytes,'originalConfidenceCounts012':counts.tolist(),
        'originalInitPose':m['initPose'],'gravityAssociationResolved':False,'worldPoseProjectionExecuted':False,
        'originalTrackingStateAvailable':False,'bodyToPhoneExtrinsicsAvailable':False,'independentObstacleOrCollisionTruthAvailable':False,
        'nativeRecordedTransportUsed':False,'physicalNavigationAuthority':False,
        'decoderBinarySHA256':json.loads((ROOT/'decoder/BUILD_RECEIPT.json').read_text())['binarySHA256'],
        'decoderScratchBytes':decoder.scratch_bytes,'wallSeconds':time.monotonic()-started,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
        'freeAfterBytes':shutil.disk_usage(ROOT).free,'frames':rows}
    (stage/'COMPLETE_DECODE_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');stage.rename(final)
    (ROOT/'FIELD_DECODE_AUDIT.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps({k:v for k,v in receipt.items() if k!='frames'},indent=2))

if __name__=='__main__':main()

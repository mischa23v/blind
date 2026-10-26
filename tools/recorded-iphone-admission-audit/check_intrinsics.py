"""Metadata association only, following Record3D author issue 99; no projection."""
from pathlib import Path
import hashlib,json,os
import numpy as np

ROOT=Path(__file__).resolve().parent

def main():
    value=os.environ.get('WORKSPACE')
    if not value or not Path(value).expanduser().is_absolute():raise ValueError('WORKSPACE must be an explicitly configured absolute directory')
    source=Path(value).expanduser().resolve()/'blind-raw-iphone-feasibility-01/selected/metadata'
    if (ROOT/'INTRINSICS_METADATA_CHECK.json').exists():raise RuntimeError('Historical receipt exists; copy checker into a clean work directory before a separately approved rerun')
    data=source.read_bytes();sha=hashlib.sha256(data).hexdigest()
    if sha!='fa1cab04539609735af5282726a453ce8e8da1b63e45e372bd3a70e03303f1fa':raise ValueError('changed original metadata')
    m=json.loads(data);k=np.asarray(m['K'],dtype=np.float64).reshape(3,3,order='F');p=np.asarray(m['perFrameIntrinsicCoeffs'],dtype=np.float64)
    if p.shape!=(89,4) or not np.isfinite(p).all() or not (p[:,:2]>0).all():raise ValueError('original coefficient contract')
    fx,fy,cx,cy=p[0];constructed=np.array([[fx,0,cx],[0,fy,cy],[0,0,1]],dtype=np.float64)
    if not np.array_equal(k,constructed):raise ValueError('global K differs from first-frame coefficients')
    sx=m['dw']/m['w'];sy=m['dh']/m['h'];roundtrip=p.astype(np.float32).astype(np.float64)
    r={'scope':'Original metadata association check using author-confirmed intrinsics order; no pixel/world projection or perception call',
       'metadataSHA256':sha,'authorConfirmation':'https://github.com/marek-simonik/record3d/issues/99#issuecomment-2459540413',
       'officialDemoPin':'0c6e7692da100aad2d5195e307f01e75427a6a2a',
       'coefficientOrder':['fx','fy','tx_principal_x','ty_principal_y'],'globalKLayout':'column-major flat array',
       'globalKEqualsConstructedFirstFrameExactly':True,'globalKIsFirstFrameOnly':True,'perFrameCount':len(p),
       'rgbWidthHeight':[m['w'],m['h']],'depthWidthHeight':[m['dw'],m['dh']],
       'sameAspectRatio':m['w']*m['dh']==m['h']*m['dw'],'depthOverRGBScaleXY':[sx,sy],
       'allCoefficientsAreExactlyFloat32Representable':bool(np.array_equal(p,roundtrip)),
       'coefficientMin':p.min(axis=0).tolist(),'coefficientMax':p.max(axis=0).tolist(),
       'framesWhoseCoefficientsDifferFromFirst':int(np.any(p!=p[0],axis=1).sum()),
       'selectedFirst8OriginalCoefficientRows':p[:8].tolist(),
       'firstFrameDepthResolutionCoefficientsDerivedOnly':[float(fx*sx),float(fy*sy),float(cx*sx),float(cy*sy)],
       'depthRGBAlignmentProvenance':'Record3D author states Apple-aligned RGB/depth. This audit checks dimensions and metadata, not independent geometric registration residuals.',
       'alignmentSource':'https://github.com/marek-simonik/record3d/issues/108',
       'pixelProjectionExecuted':False,'nativeProjectionCalled':False,'bodyOrWorldAssociationEstablished':False,'physicalAuthority':False}
    (ROOT/'INTRINSICS_METADATA_CHECK.json').write_text(json.dumps(r,indent=2)+'\n')
    print(json.dumps({k:v for k,v in r.items() if k!='selectedFirst8OriginalCoefficientRows'},indent=2))

if __name__=='__main__':main()

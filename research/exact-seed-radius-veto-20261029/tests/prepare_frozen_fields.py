#!/usr/bin/env python3
"""Data-only conversion of already frozen captures; does not execute native code."""
import argparse
import hashlib
import json
import pathlib
import struct

parser=argparse.ArgumentParser()
parser.add_argument('--repository',type=pathlib.Path,required=True)
parser.add_argument('--output',type=pathlib.Path,required=True)
args=parser.parse_args()
root=args.repository/'research/native-floor-import-repair-20261028/edt-navigation-probe'
capture_path=root/'capture-result/FULL_CAPTURE.json'
mask_path=root/'EDT_MASK_INPUTS.json'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert sha(capture_path)=='71761f53b3567b6ac5e09d38c95f9a015249062c35ee84ae0cbade1a1f1977e1'
assert sha(mask_path)=='13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a'
capture=json.loads(capture_path.read_text());masks=json.loads(mask_path.read_text())
assert capture['fullCaptureComplete'] and capture['allLayersSupported'] and not capture['physicalAuthority']
assert len(capture['profiles'])==len(masks['profiles'])==6
lines=['6'];receipt=[]
for p,m in zip(capture['profiles'],masks['profiles']):
    for key in ['profileIndex','width','height','spanCount','erosionRadiusCells','cellSizeBits','cellHeightBits','originBits']:
        assert p[key]==m[key],key
    words=[0x424c4544,1,p['profileIndex'],p['width'],p['height'],p['spanCount'],p['erosionRadiusCells'],p['cellSizeBits'],p['cellHeightBits'],*p['originBits']]
    words += [v for row in p['columns'] for v in row]+[v for row in p['spans'] for v in row]
    serialized=b''.join(struct.pack('<I',v&0xffffffff) for v in words)
    assert len(serialized)==m['layoutByteCount'] and hashlib.sha256(serialized).hexdigest()==m['layoutSHA256']
    assert hashlib.sha256(bytes(m['keepMask'])).hexdigest()==m['maskSHA256']
    assert sum(v!=0 for _,_,_,_,_,_,v,*_ in p['spans'])==m['originalKeepCount']
    assert sum(m['keepMask'])==m['candidateKeepCount']
    lines.append(' '.join(map(str,[p['width'],p['height'],p['spanCount'],p['erosionRadiusCells'],m['realSeedCount'],m['originalKeepCount'],m['candidateKeepCount']])))
    lines.append(' '.join(map(str,[p['cellSizeBits'],p['cellHeightBits'],*p['originBits']])))
    lines.extend(' '.join(map(str,row)) for row in p['columns'])
    for i,(row,keep) in enumerate(zip(p['spans'],m['keepMask'])):
        assert row[0]==i and len(row)==12 and keep in (0,1) and (not keep or row[6]!=0)
        lines.append(' '.join(map(str,[row[3],row[4],row[5],row[6],keep,*row[8:12]])))
    radius=p['erosionRadiusCells']
    disk=sum(x*x+z*z<radius*radius for x in range(-radius,radius+1) for z in range(-radius,radius+1))
    bound=m['originalKeepCount']*disk
    assert bound<=10_000_000
    receipt.append({'profile':p['profileIndex'],'layoutSHA256':m['layoutSHA256'],'maskSHA256':m['maskSHA256'],
        'stockKeep':m['originalKeepCount'],'exactKeep':m['candidateKeepCount'],'diskOffsets':disk,'workUpperBound':bound})
assert not args.output.exists(),'Do not overwrite a retained fixture attempt'
args.output.parent.mkdir(parents=True,exist_ok=True)
args.output.write_text('\n'.join(lines)+'\n')
print(json.dumps({'dataOnly':True,'nativeExecuted':False,'outputSHA256':sha(args.output),'profiles':receipt},indent=2))

#!/usr/bin/env python3
"""Read retained failed prefix; all-row lossless audit only. No engine imports."""
import gzip,hashlib,json,pathlib,resource,sys,time
H=pathlib.Path(__file__).resolve().parent;W=H.parents[2];sys.path.insert(0,str(H))
from contact_codec import HEADER,canonical,encode_record,decode_record
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 resource.setrlimit(resource.RLIMIT_CPU,(60,60));resource.setrlimit(resource.RLIMIT_AS,(256*1024**2,)*2);began=time.monotonic()
 pins=json.loads((H/'CODEC_AUDIT_PINS.json').read_text());paths={k:W/v['path']for k,v in pins['inputs'].items()}
 for k,p in paths.items():assert sha(p)==pins['inputs'][k]['sha256']
 raw_bytes=compact_bytes=canonical_bytes=rows=contact_count=0;a=hashlib.sha256();b=hashlib.sha256()
 with gzip.open(paths['failedContacts'],'rb')as f:
  while True:
   line=f.readline(2*1024**2+1)
   if not line:break
   assert len(line)<=2*1024**2 and time.monotonic()-began<90
   row=json.loads(line);packed=encode_record(row);restored=decode_record(packed,HEADER)
   x=canonical(row).encode();y=canonical(restored).encode();assert row==restored and x==y
   a.update(x+b'\n');b.update(y+b'\n');raw_bytes+=len(line);compact_bytes+=len(json.dumps(packed,separators=(',',':'),allow_nan=False).encode())+1;canonical_bytes+=len(x)+1;rows+=1;contact_count+=len(row.get('contactIDs')or[])
 assert rows==29069
 for k,p in paths.items():assert sha(p)==pins['inputs'][k]['sha256']
 print(json.dumps({'status':'all_saved_prefix_rows_losslessly_roundtripped','rows':rows,'allContactIDOccurrencesPreserved':contact_count,'rawJSONLBytes':raw_bytes,'encodedJSONLBytes':compact_bytes,'headerBytes':len(json.dumps(HEADER,separators=(',',':')).encode())+1,'originalCanonicalStreamSHA256':a.hexdigest(),'decodedCanonicalStreamSHA256':b.hexdigest(),'canonicalBytes':canonical_bytes,'sourcePinSHA256':sha(H/'CODEC_AUDIT_PINS.json'),'originalFailurePreserved':True,'nativeExecuted':False,'geometryModified':False,'completeNewRunEstablished':False},indent=2))
if __name__=='__main__':main()

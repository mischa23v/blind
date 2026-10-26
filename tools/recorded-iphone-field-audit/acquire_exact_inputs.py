"""Bounded, authorized pinned public inputs; no installs, no dataset bulk pull."""
from pathlib import Path
import hashlib,json,shutil,time,urllib.request,urllib.parse

ROOT=Path(__file__).resolve().parent
PIN='a285cd1249fe9762085713a1c796ab68b1810ac2'
CLIP='clips/D2/EM1-0387.r3d'
SIZE=13973317
SHA='aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4'
RESERVE=768*1024**2

def read_bounded(url,cap):
    request=urllib.request.Request(url,headers={'User-Agent':'bounded-public-input-audit/1.0'})
    with urllib.request.urlopen(request,timeout=45) as response:
        data=response.read(cap+1)
        if len(data)>cap:raise ValueError('metadata/source transfer cap')
        return data,response.geturl()

def main():
    # Account for the maximum selected output AND decoder work before transfer.
    required=(16+64+10)*1024**2+RESERVE
    free=shutil.disk_usage(ROOT).free
    if free<required:raise RuntimeError(f'free {free} < required {required}')
    receipts=[]
    for name in ('README.md','LICENSE'):
        url=f'https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/resolve/{PIN}/{name}'
        data,final=read_bounded(url,128*1024)
        destination=ROOT/('DATASET_'+name)
        if destination.exists():
            if destination.read_bytes()!=data:raise RuntimeError('pinned metadata changed')
        else:destination.write_bytes(data)
        receipts.append({'path':destination.name,'sourceURL':url,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
    target=ROOT/'EM1-0387.r3d';part=ROOT/'EM1-0387.r3d.partial'
    if target.exists() or part.exists():raise RuntimeError('refuse duplicate/partial clip overwrite')
    url=f'https://huggingface.co/datasets/CaryxAI/everyday-manipulation-3d-raw/resolve/{PIN}/{CLIP}?download=true'
    sha=hashlib.sha256();count=0;started=time.monotonic()
    with urllib.request.urlopen(urllib.request.Request(url,headers={'User-Agent':'bounded-public-input-audit/1.0'}),timeout=45) as response,part.open('xb') as output:
        final_host=urllib.parse.urlparse(response.geturl()).hostname
        if not (final_host in {'huggingface.co','us.aws.cdn.hf.co'} or final_host.endswith('.huggingface.co') or final_host.endswith('.xethub.hf.co')):raise RuntimeError('unexpected official download redirect')
        while True:
            if time.monotonic()-started>180:raise RuntimeError('clip acquisition wall cap')
            data=response.read(min(1024**2,SIZE-count+1))
            if not data:break
            count+=len(data)
            if count>SIZE or count>16*1024**2:raise RuntimeError('clip transfer cap')
            output.write(data);sha.update(data)
            if shutil.disk_usage(ROOT).free<RESERVE+(64+10)*1024**2+(SIZE-count):raise RuntimeError('reserved disk space at risk')
    if count!=SIZE or sha.hexdigest()!=SHA:raise ValueError('clip provenance mismatch; partial retained')
    part.rename(target)
    receipts.append({'path':target.name,'sourceURL':url,'redirectHost':final_host,'bytes':count,'sha256':sha.hexdigest(),'wallSeconds':time.monotonic()-started})
    plan=json.loads((ROOT/'LZFSE_SOURCE_PLAN.json').read_text());total=0;source_records=[]
    upstream=ROOT/'decoder/upstream';upstream.mkdir(parents=True,exist_ok=False)
    for entry in plan['proposedSourceFiles']:
        url=f'https://raw.githubusercontent.com/lzfse/lzfse/{plan["revision"]}/{entry["path"]}'
        data,_=read_bounded(url,min(1024**2-total,entry['size']))
        total+=len(data)
        git=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
        if len(data)!=entry['size'] or git!=entry['sha']:raise ValueError('official source blob mismatch')
        p=upstream/entry['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        source_records.append({'path':entry['path'],'bytes':len(data),'gitBlobSHA1':git,'sha256':hashlib.sha256(data).hexdigest(),'sourceURL':url})
    if total!=213037:raise ValueError('source set changed')
    source_receipt={'repository':plan['officialRepository'],'revision':plan['revision'],'tree':plan['tree'],'license':'BSD-3-Clause','files':source_records,'totalSourceBytes':total,'sourceAcquisitionCapBytes':1048576}
    (ROOT/'decoder/UPSTREAM_MANIFEST.json').write_text(json.dumps(source_receipt,indent=2)+'\n')
    receipt={'scope':'Recorded field/decoder audit only; no native perception or navigation run','datasetRevision':PIN,'freeBeforeBytes':free,'freeAfterBytes':shutil.disk_usage(ROOT).free,'reserveBytes':RESERVE,'files':receipts,'codecSourceBytes':total,'protocolSHA256':hashlib.sha256((ROOT/'DATA_AUDIT_PROTOCOL.md').read_bytes()).hexdigest()}
    (ROOT/'ACQUISITION_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))

if __name__=='__main__':main()

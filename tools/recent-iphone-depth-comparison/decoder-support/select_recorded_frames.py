"""Guarded exact ZIP selection; original bytes only, no pose/confidence inference."""
from pathlib import Path,PurePosixPath
import hashlib,json,os,re,resource,shutil,signal,stat,zipfile

ROOT=Path(__file__).resolve().parent
SHA='aa200931b3769084043b4cd45ae76aef52151971194b079735756aca186749d4'
CAP=64*1024**2
RESERVE=768*1024**2

def safe_name(name):
    if not isinstance(name,str) or not name or len(name)>500 or '\\' in name or '\0' in name:raise ValueError('bad ZIP name')
    p=PurePosixPath(name)
    if not p.parts or p.is_absolute() or '..' in p.parts or ':' in p.parts[0]:raise ValueError('unsafe ZIP path')
    return str(p)

def main():
    resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(60,60));signal.alarm(180)
    clip=ROOT/'EM1-0387.r3d'
    if clip.stat().st_size!=13973317:raise ValueError('clip length mismatch')
    stage=ROOT/'selected.partial';final=ROOT/'selected'
    if stage.exists() or final.exists():raise ValueError('refuse duplicate/partial selection overwrite')
    with clip.open('rb') as source:
        before=os.fstat(source.fileno());digest=hashlib.sha256()
        while True:
            b=source.read(1024**2)
            if not b:break
            digest.update(b)
        if digest.hexdigest()!=SHA:raise ValueError('clip hash mismatch')
        source.seek(0)
        with zipfile.ZipFile(source) as archive:
            infos=archive.infolist()
            if len(infos)>2000:raise ValueError('member cap')
            rows=[];names={};total=0;frames={}
            for info in infos:
                name=safe_name(info.filename);kind=stat.S_IFMT(info.external_attr>>16)
                if name in names or info.flag_bits&1 or kind not in (0,stat.S_IFREG,stat.S_IFDIR):raise ValueError('duplicate/encrypted/link/special ZIP member')
                if not 0<=info.file_size<=16*1024**2:raise ValueError('individual ZIP member cap')
                total+=info.file_size
                if total>256*1024**2:raise ValueError('logical archive cap')
                names[name]=info;rows.append({'name':name,'bytes':info.file_size,'compressedBytes':info.compress_size,'crc32':info.CRC,'directory':info.is_dir()})
                match=re.fullmatch(r'rgbd/(\d+)\.(jpg|depth|conf)',name)
                if match:frames.setdefault(int(match[1]),{})[match[2]]=name
            if 'metadata' not in names or names['metadata'].file_size>2*1024**2:raise ValueError('missing/oversized original metadata')
            metadata_bytes=archive.read(names['metadata']);metadata=json.loads(metadata_bytes)
            if not isinstance(metadata,dict):raise ValueError('invalid metadata root')
            ids=sorted(frames)[:8]
            if len(ids)!=8 or any(set(frames[i])!={'jpg','depth','conf'} for i in ids):raise ValueError('first eight originals not complete triples')
            selected=['metadata']+[frames[i][kind] for i in ids for kind in ('jpg','depth','conf')]
            selected_bytes=sum(names[n].file_size for n in selected)
            dw=metadata.get('dw');dh=metadata.get('dh')
            if not isinstance(dw,int) or not isinstance(dh,int) or not 0<dw*dh<=1024*1024:raise ValueError('invalid bounded original depth dimensions')
            decoded_cap=len(ids)*dw*dh*5
            if selected_bytes+decoded_cap>CAP:raise ValueError('selected plus decoded cap')
            if shutil.disk_usage(ROOT).free<RESERVE+selected_bytes+decoded_cap:raise RuntimeError('reserved disk space')
            inventory={'clipSHA256':SHA,'members':rows,'memberCount':len(rows),'logicalBytes':total,'allMemberNamesTypesSizesValidated':True,'unselectedMemberCRCVerified':False,'selectedFrameIDs':ids,
                'selectedBytes':selected_bytes,'expectedDecodedDepthConfidenceBytes':decoded_cap,'selectionCapBytes':CAP,
                'metadataKeys':sorted(metadata),'selectionReason':'First eight numerically ordered original frame IDs, fixed before detector outcomes.'}
            (ROOT/'ZIP_INVENTORY.json').write_text(json.dumps(inventory,indent=2)+'\n')
            stage.mkdir();outputs=[]
            for name in selected:
                data=archive.read(names[name]) # zipfile verifies CRC; inventory bounds allocation.
                p=stage/Path(*PurePosixPath(name).parts);p.parent.mkdir(parents=True,exist_ok=True)
                with p.open('xb') as output:output.write(data)
                outputs.append({'name':name,'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
            after=os.fstat(source.fileno())
            if (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns)!=(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns):raise ValueError('clip changed during selection')
            receipt={'clipSHA256':SHA,'frameIDs':ids,'files':outputs,'originalBytesPreserved':True,'selectedBytes':selected_bytes,
                'decodedOutputBytesReserved':decoded_cap,'trackingState':'unknown unless original metadata establishes otherwise',
                'navigationRun':False,'perceptionRun':False}
            (stage/'COMPLETE_SELECTION_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');stage.rename(final)
            (ROOT/'SELECTION_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
            print(json.dumps({k:v for k,v in inventory.items() if k!='members'},indent=2))
            print('Metadata values excluding frame arrays:',json.dumps({k:v for k,v in metadata.items() if k not in ('poses','frameTimestamps','perFrameIntrinsicCoeffs')},default=str)[:12000])

if __name__=='__main__':main()

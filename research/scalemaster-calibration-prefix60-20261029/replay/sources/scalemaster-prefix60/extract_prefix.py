"""Exactly one safe full tar stream; selected prefix depth/confidence <=32MiB."""
import gzip,hashlib,json,sys,tarfile
from pathlib import Path,PurePosixPath


def main():
    freeze=json.loads(Path(sys.argv[1]).read_text()); out=Path(sys.argv[2])/'images'
    expected={r['name']:r for r in json.loads(Path(freeze['input_paths']['inventory']).read_text())}
    names={f'Stairs_02/{kind}/{i:06d}.png':f'{kind}_{i:06d}.png' for i in range(60) for kind in ('depth','confidence')}
    if not set(names)<=set(expected):raise ValueError('Fixed prefix member missing; no substitute frames')
    for n,e in expected.items():
        p=PurePosixPath(n)
        if p.is_absolute() or '..' in p.parts or '\\' in n or e['type'] not in ('file','dir'):
            raise ValueError('Unsafe inventory')
    class HashReader:
        def __init__(self,f):self.f=f;self.hash=hashlib.sha256();self.count=0
        def read(self,n=-1):
            b=self.f.read(n);self.hash.update(b);self.count+=len(b)
            if self.count>freeze['archive']['bytes']:raise ValueError('Compressed cap')
            return b
    class Reader:
        count=0
        def __init__(self,g):self.g=g
        def read(self,n=-1):
            if n<0:n=2**20
            b=self.g.read(min(n,2**30-self.count+1));self.count+=len(b)
            if self.count>2**30:raise ValueError('Expanded stream cap1GiB')
            return b
    buffers={};seen=set();total=0
    with open(freeze['input_paths']['archive'],'rb') as raw:
        hashed=HashReader(raw)
        with gzip.GzipFile(fileobj=hashed,mode='rb') as gz:
            reader=Reader(gz)
            with tarfile.open(fileobj=reader,mode='r|') as tar:
                for member in tar:
                    if len(seen)>=20000:raise ValueError('Member cap')
                    e=expected.get(member.name)
                    if member.name in seen or e is None or e['size']!=member.size or not (member.isfile() or member.isdir()):
                        raise ValueError('Changed/unsafe member')
                    if (member.isfile() and e['type']!='file') or (member.isdir() and e['type']!='dir'):
                        raise ValueError('Member type changed')
                    seen.add(member.name)
                    if member.name in names:
                        if not member.isfile() or member.size>2**20:raise ValueError('Selected member oversized/nonregular')
                        payload=tar.extractfile(member).read(member.size+1)
                        if len(payload)!=member.size:raise ValueError('Truncated selected member')
                        total+=len(payload)
                        if total>32*2**20-65536:raise ValueError('Selective extraction cap')
                        buffers[names[member.name]]=payload
            while reader.read(2**20):pass
    if hashed.hash.hexdigest()!=freeze['archive']['sha256'] or hashed.count!=freeze['archive']['bytes']:
        raise ValueError('Compressed source hash/size changed')
    if seen!=set(expected) or set(buffers)!=set(names.values()):raise ValueError('Incomplete archive/selection')
    out.mkdir()
    for name,payload in buffers.items():
        with (out/name).open('xb') as f:f.write(payload)
    result={'indices':list(range(60)),'selection':'fixed prefix before visual selection',
            'compressed_sha256':hashed.hash.hexdigest(),'compressed_bytes':hashed.count,
            'gzip_crc_eof':'passed','expanded_stream_bytes':reader.count,'members':len(seen),
            'selected_bytes':total,'files':{n:hashlib.sha256(b).hexdigest() for n,b in buffers.items()}}
    with (out/'receipt.json').open('x') as f:json.dump(result,f,indent=2)
    print(json.dumps({'selected_members':len(buffers),'selected_bytes':total}))


if __name__=='__main__':main()

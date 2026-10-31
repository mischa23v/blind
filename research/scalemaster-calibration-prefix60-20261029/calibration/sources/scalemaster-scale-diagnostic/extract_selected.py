"""One bounded pass; validates prior safe inventory and writes <=3MiB selected data."""
import argparse,gzip,hashlib,json,tarfile
from pathlib import Path,PurePosixPath

def main():
    ap=argparse.ArgumentParser();ap.add_argument('manifest');ap.add_argument('archive');ap.add_argument('inventory');ap.add_argument('out');a=ap.parse_args()
    manifest=json.loads(Path(a.manifest).read_text());expected={r['name']:r for r in json.loads(Path(a.inventory).read_text())}
    ids=sorted({p[k] for p in manifest['pairs'] for k in ('i','j')})
    if len(ids)>12:raise ValueError('Too many selected indices')
    names={f'Stairs_02/{kind}/{i:06d}.png':f'{kind}_{i:06d}.png' for i in ids for kind in ('depth','confidence')}
    if not set(names)<=set(expected):raise ValueError('Frozen index missing; do not reselect pairs from image availability')
    for n,e in expected.items():
        p=PurePosixPath(n)
        if p.is_absolute() or '..' in p.parts or '\\' in n or e['type'] not in ('file','dir'):raise ValueError('Unsafe inventory')
    class Reader:
        count=0
        def __init__(self,g):self.g=g
        def read(self,n=-1):
            if n<0:n=2**20
            b=self.g.read(min(n,2**30-self.count+1));self.count+=len(b)
            if self.count>2**30:raise ValueError('Expanded-byte cap')
            return b
    class HashReader:
        def __init__(self,f):self.f=f;self.hash=hashlib.sha256();self.count=0
        def read(self,n=-1):
            b=self.f.read(n);self.hash.update(b);self.count+=len(b);return b
    buffers={};seen=set()
    with open(a.archive,'rb') as raw:
      hashed=HashReader(raw)
      with gzip.GzipFile(fileobj=hashed,mode='rb') as gz:
        reader=Reader(gz)
        with tarfile.open(fileobj=reader,mode='r|') as tf:
            for m in tf:
                if len(seen)>=20000:raise ValueError('Member-count cap')
                e=expected.get(m.name)
                if m.name in seen or e is None or e['size']!=m.size or not (m.isfile() or m.isdir()):raise ValueError('Changed/unsafe archive')
                seen.add(m.name)
                if m.name in names:
                    if not m.isfile() or m.size>2**20:raise ValueError('Oversized/nonregular selected member')
                    b=tf.extractfile(m).read(m.size+1)
                    if len(b)!=m.size:raise ValueError('Truncated selected member')
                    buffers[names[m.name]]=b
                    if sum(map(len,buffers.values()))>3*2**20-65536:raise ValueError('3MiB output cap including reserved receipt space')
        while reader.read(2**20):pass
      if hashed.hash.hexdigest()!='3aea83a4ab6cfcf5818ce8b68f16768545d2923e35f359fb829d941518d8f6af':
        raise ValueError('Compressed archive differs from verified Stairs_02 source')
    if seen!=set(expected) or len(buffers)!=len(names):raise ValueError('Incomplete archive/selection')
    out=Path(a.out)
    if out.exists():raise SystemExit('Refusing to overwrite an existing extraction')
    out.mkdir(parents=True)
    for n,b in buffers.items():(out/n).write_bytes(b)
    receipt={'manifest_sha256':hashlib.sha256(Path(a.manifest).read_bytes()).hexdigest(),'gzip_crc_eof':'passed',
        'compressed_sha256':hashed.hash.hexdigest(),'compressed_bytes_read':hashed.count,
        'bytes_written':sum(map(len,buffers.values())),'indices':ids,'files':{n:hashlib.sha256(b).hexdigest() for n,b in buffers.items()}}
    (out/'receipt.json').write_text(json.dumps(receipt,indent=2));print(json.dumps(receipt,indent=2))

if __name__=='__main__':main()

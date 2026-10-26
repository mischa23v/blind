#!/usr/bin/env python3
"""Verify ordered parts and restore one exact asset without overwriting any path."""
import argparse, hashlib, json, os, re, shutil, stat
from pathlib import Path, PurePosixPath
MAX_PART=8*1024**2
MAX_TOTAL=100*1024**2
RESERVE=768*1024**2

def safe_rel(name):
    if not isinstance(name,str) or not name or '\\' in name or ':' in name or '\0' in name:
        raise ValueError('unsafe relative path')
    p=PurePosixPath(name)
    if p.is_absolute() or any(x in ('','.','..') for x in name.split('/')):
        raise ValueError('unsafe relative path')
    return p

def no_symlinks(path):
    path=Path(os.path.abspath(path))
    for p in [*reversed(path.parents),path]:
        if p.is_symlink():raise ValueError('symlink path refused')
    return path

def regular_fd(path):
    no_symlinks(path)
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW)
    if not stat.S_ISREG(os.fstat(fd).st_mode):os.close(fd);raise ValueError('regular file required')
    return os.fdopen(fd,'rb')

def sha(data):return hashlib.sha256(data).hexdigest()
def valid_sha(value):return isinstance(value,str) and re.fullmatch('[0-9a-f]{64}',value)

def restore(manifest,manifest_sha,asset,outdir):
    manifest=no_symlinks(manifest)
    with regular_fd(manifest) as f:
        raw=f.read(1024**2+1)
    if len(raw)>1024**2 or not valid_sha(manifest_sha) or sha(raw)!=manifest_sha:
        raise ValueError('manifest hash/size mismatch')
    d=json.loads(raw);rows=d['assets']
    if d['format']!='ordered-byte-parts-v1' or asset not in rows:raise ValueError('asset missing or format unknown')
    row=rows[asset];name=row['filename'];safe_rel(name)
    if '/' in name or not valid_sha(row['sha256']) or type(row['bytes']) is not int or not 0<row['bytes']<=MAX_TOTAL:raise ValueError('invalid asset')
    parts=row['parts']
    if not parts or len(parts)>100 or len({p['path'] for p in parts})!=len(parts):raise ValueError('duplicate/empty parts')
    if sum(p['bytes'] for p in parts)!=row['bytes']:raise ValueError('part size sum')
    for i,p in enumerate(parts):
        safe_rel(p['path'])
        if p['index']!=i or type(p['bytes']) is not int or not 0<p['bytes']<=MAX_PART or not valid_sha(p['sha256']):raise ValueError('invalid part')
    outdir=no_symlinks(outdir)
    if not outdir.is_dir():raise ValueError('existing output directory required')
    target=outdir/name;partial=outdir/(name+'.partial')
    if os.path.lexists(target) or os.path.lexists(partial):raise FileExistsError('output/partial exists')
    if shutil.disk_usage(outdir).free<RESERVE+row['bytes']:raise RuntimeError('768 MiB reserve plus asset required')
    fd=os.open(partial,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    whole=hashlib.sha256();total=0;created=True
    try:
        with os.fdopen(fd,'wb') as out:
            for p in parts:
                h=hashlib.sha256();n=0
                with regular_fd(manifest.parent/str(safe_rel(p['path']))) as inp:
                    if os.fstat(inp.fileno()).st_size!=p['bytes']:raise ValueError('part byte count')
                    while True:
                        b=inp.read(min(1024**2,p['bytes']-n+1))
                        if not b:break
                        n+=len(b)
                        if n>p['bytes']:raise ValueError('part grew')
                        h.update(b);whole.update(b);total+=len(b);out.write(b)
                        if shutil.disk_usage(outdir).free<RESERVE:raise RuntimeError('reserve crossed')
                if n!=p['bytes'] or h.hexdigest()!=p['sha256']:raise ValueError('part hash mismatch')
            out.flush();os.fsync(out.fileno())
        if total!=row['bytes'] or whole.hexdigest()!=row['sha256']:raise ValueError('asset hash mismatch')
        # Hard-link is atomic and refuses an existing destination; never os.replace.
        os.link(partial,target,follow_symlinks=False);partial.unlink();created=False
        return {'asset':asset,'filename':name,'bytes':total,'sha256':whole.hexdigest(),'overwritten':False}
    finally:
        if created and partial.exists():partial.unlink()

def main():
    p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,default=Path(__file__).resolve().parent/'PARTS_MANIFEST.json');p.add_argument('--manifest-sha',required=True);p.add_argument('--asset',required=True);p.add_argument('--output-dir',type=Path,required=True);a=p.parse_args()
    print(json.dumps(restore(a.manifest,a.manifest_sha,a.asset,a.output_dir),indent=2))
if __name__=='__main__':main()

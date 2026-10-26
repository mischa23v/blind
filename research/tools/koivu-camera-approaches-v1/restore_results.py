"""Restore an exact original gzip result; refuse overwrite, traversal and symlinks."""
from pathlib import Path,PurePosixPath
import argparse,gzip,hashlib,json,os,shutil,stat
MAX=32*1024**2;RESERVE=768*1024**2
def sha(b):return hashlib.sha256(b).hexdigest()
def safe(p):
 p=Path(os.path.abspath(p))
 for q in [*reversed(p.parents),p]:
  if q.is_symlink():raise ValueError('symlink refused')
 return p
def regular(p):
 p=safe(p);fd=os.open(p,os.O_RDONLY|os.O_NOFOLLOW)
 if not stat.S_ISREG(os.fstat(fd).st_mode):os.close(fd);raise ValueError('regular file required')
 return os.fdopen(fd,'rb')
def restore(manifest,expected,asset,output):
 manifest=safe(manifest)
 with regular(manifest)as f:b=f.read(1024**2+1)
 if len(b)>1024**2 or sha(b)!=expected:raise ValueError('manifest identity')
 d=json.loads(b)
 if d['format']!='exact-original-gzip-v1':raise ValueError('format')
 rows=[r for r in d['assets']if r['asset']==asset]
 if len(rows)!=1:raise ValueError('asset')
 r=rows[0];name=r['storedPath'];parts=name.split('/')
 if PurePosixPath(name).is_absolute()or any(x in ('','.','..')for x in parts)or '\\'in name or ':'in name:raise ValueError('unsafe source path')
 if type(r['originalBytes'])is not int or not 0<r['originalBytes']<=MAX or not 0<r['gzipBytes']<=8*1024**2:raise ValueError('size bound')
 src=safe(manifest.parent/name);out=safe(output);partial=out.with_name(out.name+'.partial')
 if out.name!=r['filename']or not out.parent.is_dir():raise ValueError('original basename and existing output parent required')
 if os.path.lexists(out)or os.path.lexists(partial):raise FileExistsError('refuse existing output/partial')
 if shutil.disk_usage(out.parent).free<RESERVE+r['originalBytes']:raise RuntimeError('free reserve')
 with regular(src)as f:
  raw=f.read(r['gzipBytes']+1)
 if len(raw)!=r['gzipBytes']or sha(raw)!=r['gzipSHA256']:raise ValueError('gzip identity')
 import io
 created=False
 try:
  fd=os.open(partial,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600);created=True;n=0;h=hashlib.sha256()
  with os.fdopen(fd,'wb')as target,gzip.GzipFile(fileobj=io.BytesIO(raw))as inp:
   while b:=inp.read(min(1048576,r['originalBytes']-n+1)):
    n+=len(b)
    if n>r['originalBytes']:raise ValueError('expanded size')
    h.update(b);target.write(b)
   target.flush();os.fsync(target.fileno())
  if n!=r['originalBytes']or h.hexdigest()!=r['originalSHA256']:raise ValueError('original identity')
  os.link(partial,out,follow_symlinks=False);partial.unlink();created=False
  return {'bytes':n,'sha256':h.hexdigest(),'overwritten':False}
 finally:
  if created:partial.unlink(missing_ok=True)
def main():
 p=argparse.ArgumentParser();p.add_argument('--manifest',type=Path,default=Path(__file__).resolve().parent/'COMPRESSED_RESULTS.json');p.add_argument('--manifest-sha',required=True);p.add_argument('--asset',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();print(json.dumps(restore(a.manifest,a.manifest_sha,a.asset,a.output),indent=2))
if __name__=='__main__':main()

#!/usr/bin/env python3
"""SOURCE PREPARATION: exact original Koivu OBJ+poses only; never imports native code.
Run only after root confirms download completion and admits this bounded extraction.
"""
import argparse, gzip, hashlib, json, os, pathlib, resource, signal, stat, tarfile, time
ARCHIVE_BYTES = 146575749
ARCHIVE_SHA256 = '68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518'
PREFIX = 'room_datasets/koivu/iphone/long_capture/'
EXPECTED = {
    PREFIX+'polycam_mesh/textured.obj': ('textured.obj', 3465360, '79cfd017b9c88dca840c8ec969208a93593b03f600303d70cc6777b7c55438a1'),
    PREFIX+'transformations.json': ('transformations.json', 239937, 'c496c8dc6474679766db8abd92da9c756104a752bb9e4519fd462fe294af90c3'),
}
SCAN_CAP = 256*1024**2
RESERVE = 768*1024**2

def identity(s):
    return (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)

def digest_stream(f):
    h=hashlib.sha256(); n=0
    for b in iter(lambda:f.read(1024**2),b''):
        n+=len(b)
        if n>ARCHIVE_BYTES: raise ValueError('archive exceeds exact byte length')
        h.update(b)
    if n!=ARCHIVE_BYTES or h.hexdigest()!=ARCHIVE_SHA256:
        raise ValueError('full archive length/SHA256 mismatch; partial/substitute refused')
    return h.hexdigest()

class LimitedReader:
    def __init__(self,raw): self.raw=raw; self.count=0
    def read(self,n=-1):
        if n<0: raise ValueError('unbounded decompression read refused')
        b=self.raw.read(n); self.count+=len(b)
        if self.count>SCAN_CAP: raise ValueError('decompressed scan cap')
        return b

def main():
    p=argparse.ArgumentParser(); p.add_argument('--archive',type=pathlib.Path,required=True); p.add_argument('--out',type=pathlib.Path,required=True); a=p.parse_args()
    resource.setrlimit(resource.RLIMIT_CPU,(60,60)); resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2))
    resource.setrlimit(resource.RLIMIT_FSIZE,(4*1024**2,4*1024**2)); resource.setrlimit(resource.RLIMIT_CORE,(0,0)); signal.alarm(180)
    a.out.mkdir(exist_ok=False); began=time.monotonic(); receipt={'status':'started','archiveSHA256':ARCHIVE_SHA256,'archiveBytes':ARCHIVE_BYTES,'files':[],'nativeExecuted':False,'depthExtracted':False}
    def save(name):
        with (a.out/name).open('x') as f: json.dump(receipt,f,indent=2); f.write('\n')
    save('STARTED.json')
    try:
        if os.statvfs(a.out).f_bavail*os.statvfs(a.out).f_frsize<RESERVE+3705297:
            raise RuntimeError('768 MiB disk reserve plus extraction required')
        fd=os.open(a.archive,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
        with os.fdopen(fd,'rb') as source:
            before=os.fstat(source.fileno())
            if not stat.S_ISREG(before.st_mode) or before.st_size!=ARCHIVE_BYTES: raise ValueError('nonregular/partial archive')
            receipt['fullArchiveSHA256Before']=digest_stream(source); source.seek(0); seen=set(); found=set(); declared=0; member_count=0
            with gzip.GzipFile(fileobj=source,mode='rb') as raw:
                bounded=LimitedReader(raw)
                with tarfile.open(fileobj=bounded,mode='r|') as archive:
                    for member in archive:
                        name=member.name; path=pathlib.PurePosixPath(name)
                        if (not name or '\x00' in name or '\\' in name or len(name)>1000 or path.is_absolute() or '..' in path.parts or (path.parts and ':' in path.parts[0])):
                            raise ValueError('unsafe archive member')
                        normalized=str(path)
                        if normalized=='.':
                            if not member.isdir(): raise ValueError('non-directory root')
                            continue
                        if normalized in seen: raise ValueError('duplicate archive member')
                        seen.add(normalized); member_count+=1; declared+=member.size
                        if member_count>10000 or member.size<0 or declared>SCAN_CAP: raise ValueError('archive member/declaration cap')
                        if not (member.isdir() or member.isreg()): raise ValueError('archive link/special member refused')
                        if normalized not in EXPECTED: continue
                        dest,size,expected=EXPECTED[normalized]
                        if not member.isreg() or member.size!=size: raise ValueError('selected member size/type mismatch')
                        h=hashlib.sha256(); total=0
                        with archive.extractfile(member) as inp,(a.out/dest).open('xb') as output:
                            for chunk in iter(lambda:inp.read(1024**2),b''):
                                total+=len(chunk)
                                if total>size: raise ValueError('selected member exceeds bound')
                                output.write(chunk); h.update(chunk)
                        if total!=size or h.hexdigest()!=expected: raise ValueError('selected member content hash mismatch: '+normalized)
                        found.add(normalized); receipt['files'].append({'member':normalized,'output':dest,'bytes':total,'sha256':h.hexdigest()})
                # Drain the gzip stream to validate CRC and bound any trailing data.
                while bounded.read(1024**2): pass
                receipt['decompressedBytesScanned']=bounded.count
            if found!=set(EXPECTED): raise ValueError('missing selected original member')
            if identity(before)!=identity(os.fstat(source.fileno())): raise ValueError('archive changed during extraction')
            source.seek(0); receipt['fullArchiveSHA256After']=digest_stream(source)
            if identity(before)!=identity(os.fstat(source.fileno())): raise ValueError('archive changed during final verification')
        receipt.update(status='COMPLETE_EXACT_OBJ_AND_ORIGINAL_POSES',selectedBytes=sum(x['bytes']for x in receipt['files']),archiveMembersInspected=member_count,wallSeconds=time.monotonic()-began,scriptSHA256=hashlib.sha256(pathlib.Path(__file__).read_bytes()).hexdigest(),sourceLicense='CC BY 4.0',sourceAttribution='Xuqian Ren et al. / MuSHRoom',officialArchiveURL='https://zenodo.org/api/records/10230733/files/koivu_iphone.tar.gz/content')
        save('EXTRACTION.json'); print(json.dumps({'status':receipt['status'],'out':str(a.out),'selectedBytes':receipt['selectedBytes'],'wallSeconds':receipt['wallSeconds']}))
    except BaseException as exc:
        receipt.update(status='FAILED_PARTIAL_RETAINED',error=type(exc).__name__+': '+str(exc),wallSeconds=time.monotonic()-began)
        save('FAILED.json'); raise

if __name__=='__main__': main()

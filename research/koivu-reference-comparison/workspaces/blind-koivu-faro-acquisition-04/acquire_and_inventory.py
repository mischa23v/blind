"""Exact authorized FARO archive acquisition and inventory ONLY. No extraction."""
from pathlib import Path,PurePosixPath
import gzip,hashlib,json,os,resource,shutil,signal,sys,tarfile,time,urllib.parse,urllib.request
ROOT=Path(__file__).resolve().parent
SIZE=455583916; MD5='1fc9598ff73fc833b6e4db90af604062'
CAP=460*1024**2; RESERVE=768*1024**2; SCAN_CAP=2*1024**3; MAX_MEMBERS=10000
URL='https://zenodo.org/api/records/10222321/files/koivu_mesh_pd.tar.gz/content'
ARCHIVE=ROOT/'koivu_mesh_pd.tar.gz'; META=ROOT/'zenodo-record-10222321.json'

def dump(name,value):(ROOT/name).write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')
def sha(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(1024**2),b''):h.update(b)
    return h.hexdigest()
def reserve(remaining=0):
    if shutil.disk_usage(ROOT).free<RESERVE+remaining:raise RuntimeError('free-space reserve/remaining transfer requirement')
class OfficialRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        p=urllib.parse.urlparse(newurl)
        if p.scheme!='https' or p.hostname!='zenodo.org' or p.username or p.password:raise ValueError('unapproved redirect')
        return super().redirect_request(req,fp,code,msg,headers,newurl)

def acquire():
    if sha(META)!='147ea028701494eeb1e267bf2ec575c683a87bfab606fafe306ca8d603dc803b':raise ValueError('verified official metadata snapshot changed')
    m=json.loads(META.read_text());entry=next(f for f in m['files'] if f['key']=='koivu_mesh_pd.tar.gz')
    if entry['size']!=SIZE or entry['checksum']!='md5:'+MD5 or entry['links']['self']!=URL:raise ValueError('official asset metadata changed')
    if m['metadata']['access_right']!='open' or m['metadata']['license']['id']!='cc-by-4.0':raise ValueError('public license/access changed')
    part=ROOT/'koivu_mesh_pd.tar.gz.partial'
    if ARCHIVE.exists() or part.exists():raise RuntimeError('refuse existing archive/partial overwrite')
    reserve(SIZE+2*1024**2);before=shutil.disk_usage(ROOT).free;start=time.monotonic();count=0;md5=hashlib.md5();digest=hashlib.sha256()
    req=urllib.request.Request(URL,headers={'User-Agent':'bounded-public-reference-verification/1.0'})
    with urllib.request.build_opener(OfficialRedirects()).open(req,timeout=40) as response,part.open('xb') as output:
        final=response.geturl()
        u=urllib.parse.urlparse(final)
        if u.scheme!='https' or u.hostname!='zenodo.org' or u.username or u.password:raise ValueError('unapproved final URL')
        n=response.headers.get('Content-Length')
        if n is not None and int(n)!=SIZE:raise ValueError('changed declared transfer length')
        while True:
            b=response.read(min(1024**2,SIZE-count+1))
            if not b:break
            count+=len(b)
            if count>SIZE or count>CAP:raise ValueError('compressed transfer cap')
            output.write(b);md5.update(b);digest.update(b);reserve(SIZE-count)
    if count!=SIZE or md5.hexdigest()!=MD5:raise ValueError('official length/MD5 mismatch; partial retained')
    part.rename(ARCHIVE)
    result={'sourceURL':URL,'finalURL':final,'record':'https://zenodo.org/records/10222321','license':'CC BY4.0',
       'bytes':count,'publishedMD5':MD5,'actualMD5':md5.hexdigest(),'sha256':digest.hexdigest(),'metadataSHA256':sha(META),
       'sourceScriptSHA256':sha(Path(__file__)),'wallSeconds':time.monotonic()-start,'freeBeforeBytes':before,'freeAfterBytes':shutil.disk_usage(ROOT).free,
       'compressedCapBytes':CAP,'reservedFreeBytes':RESERVE,'extracted':False,'comparisonExecuted':False}
    dump('ACQUISITION_RECEIPT.json',result);print(json.dumps(result,indent=2),flush=True)

def safe_name(raw):
    if not isinstance(raw,str) or not raw or len(raw)>1000 or '\x00' in raw or '\\' in raw:raise ValueError('invalid member name')
    p=PurePosixPath(raw)
    if str(p)=='.':return None
    if p.is_absolute() or '..' in p.parts or ':' in p.parts[0]:raise ValueError('unsafe member path')
    return str(p)
class GuardedTarInfo(tarfile.TarInfo):
    def _proc_gnusparse_00(self,*args,**kwargs):raise ValueError('PAX sparse member rejected')
    def _proc_gnusparse_01(self,*args,**kwargs):raise ValueError('PAX sparse member rejected')
    def _proc_gnusparse_10(self,*args,**kwargs):raise ValueError('PAX sparse member rejected')
    def _proc_member(self,tar):
        # Installed Python 3.12 calls this before PAX/GNU metadata allocation.
        tar.guard_header_count=getattr(tar,'guard_header_count',0)+1
        if tar.guard_header_count>MAX_MEMBERS:raise ValueError('raw tar header count cap')
        if self.type in (tarfile.XHDTYPE,tarfile.XGLTYPE,tarfile.SOLARIS_XHDTYPE,tarfile.GNUTYPE_LONGNAME,tarfile.GNUTYPE_LONGLINK) and not 0<=self.size<=1024**2:
            raise ValueError('extended tar metadata exceeds 1 MiB')
        if self.type==tarfile.GNUTYPE_SPARSE:raise ValueError('sparse member not authorized')
        return super()._proc_member(tar)
class Bounded:
    def __init__(self,raw):self.raw=raw;self.count=0
    def read(self,n):
        if n<0:raise ValueError('unbounded archive read')
        b=self.raw.read(min(n,SCAN_CAP-self.count+1));self.count+=len(b)
        if self.count>SCAN_CAP:raise ValueError('decompressed scan cap')
        reserve();return b

def inventory():
    if (ROOT/'ARCHIVE_INVENTORY.json').exists():raise RuntimeError('refuse inventory overwrite')
    receipt=json.loads((ROOT/'ACQUISITION_RECEIPT.json').read_text());start=time.monotonic();rows=[];seen=set();total=0
    with ARCHIVE.open('rb') as source:
        before=os.fstat(source.fileno());digest=hashlib.sha256();count=0
        for b in iter(lambda:source.read(1024**2),b''):
            count+=len(b)
            if count>SIZE:raise ValueError('archive length changed')
            digest.update(b)
        if count!=SIZE or digest.hexdigest()!=receipt['sha256']:raise ValueError('archive differs from acquisition receipt')
        source.seek(0)
        with gzip.GzipFile(fileobj=source,mode='rb') as raw:
            bounded=Bounded(raw)
            with tarfile.open(fileobj=bounded,mode='r|',tarinfo=GuardedTarInfo) as tar:
                for member in tar:
                    name=safe_name(member.name)
                    if name is None:
                        if not member.isdir():raise ValueError('non-directory root')
                        continue
                    if name in seen:raise ValueError('duplicate normalized member')
                    seen.add(name)
                    if not (member.isdir() or member.isreg()) or member.issparse():raise ValueError('link/special/sparse member rejected')
                    if member.size<0 or member.size>SCAN_CAP:raise ValueError('invalid member length')
                    total+=member.size
                    if total>SCAN_CAP or len(seen)>MAX_MEMBERS:raise ValueError('logical bytes/member cap')
                    rows.append({'name':name,'bytes':member.size,'kind':'directory' if member.isdir() else 'file'})
            raw_headers=tar.guard_header_count
            while bounded.read(1024**2):pass # Verify gzip end/CRC without extracting trailing content.
            scanned=bounded.count
        after=os.fstat(source.fileno())
        if (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns)!=(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns):raise ValueError('archive changed during scan')
    result={'archiveSHA256':receipt['sha256'],'pythonVersion':sys.version,'tarfileSourceSHA256':sha(Path(tarfile.__file__)),'memberCount':len(rows),'rawHeaderCountIncludingExtendedMetadata':raw_headers,'extendedMetadataCapBytes':1024**2,'declaredTotalBytes':total,'decompressedBytesScanned':scanned,
      'decompressedCapBytes':SCAN_CAP,'memberCap':MAX_MEMBERS,'reservedFreeBytes':RESERVE,'wallSeconds':time.monotonic()-start,
      'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'allListedMembersValidated':True,'extracted':False,'comparisonExecuted':False,'members':rows}
    dump('ARCHIVE_INVENTORY.json',result);print(json.dumps(result,indent=2),flush=True)

if __name__=='__main__':
    resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(300,300));signal.alarm(300)
    try:
        if sys.argv[1:]==['acquire']:acquire()
        elif sys.argv[1:]==['inventory']:inventory()
        else:raise SystemExit('usage: acquire_and_inventory.py acquire | inventory (no extraction command)')
    except Exception as error:
        dump('FAILURE_'+('-'.join(sys.argv[1:]) or 'arguments')+'.json',{'error':repr(error),'partialPreserved':True,'extracted':False});raise

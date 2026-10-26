"""Inspect first; manually extract an explicit, bounded subset. Never extractall."""
from pathlib import Path,PurePosixPath
from contextlib import contextmanager
import gzip,hashlib,json,os,resource,shutil,signal,sys,tarfile,time

ROOT=Path(__file__).resolve().parent
ARCHIVE=ROOT/'koivu_iphone.tar.gz'
SCAN_CAP=2*1024**3
EXTRACT_CAP=256*1024**2
RESERVE=768*1024**2
MAX_MEMBERS=20000

class BoundedStream:
    def __init__(self,raw):self.raw=raw;self.count=0;self.started=time.monotonic()
    def read(self,n):
        if time.monotonic()-self.started>180:raise RuntimeError('archive scan wall cap')
        b=self.raw.read(n);self.count+=len(b)
        if self.count>SCAN_CAP:raise RuntimeError('archive scan decompressed-byte cap')
        return b

@contextmanager
def checked_archive():
    receipt=json.loads((ROOT/'ACQUISITION_RECEIPT.json').read_text())
    with ARCHIVE.open('rb') as compressed:
        before=os.fstat(compressed.fileno());sha=hashlib.sha256();count=0
        while True:
            block=compressed.read(1024**2)
            if not block:break
            count+=len(block)
            if count>146575749:raise ValueError('changed archive length')
            sha.update(block)
        if count!=receipt['bytes'] or sha.hexdigest()!=receipt['sha256']:raise ValueError('archive does not match acquisition receipt')
        compressed.seek(0)
        with gzip.GzipFile(fileobj=compressed,mode='rb') as raw:
            yield BoundedStream(raw)
        after=os.fstat(compressed.fileno())
        if (before.st_dev,before.st_ino,before.st_size,before.st_mtime_ns)!=(after.st_dev,after.st_ino,after.st_size,after.st_mtime_ns):raise ValueError('archive changed while inspected')

def safe_name(name):
    if not isinstance(name,str) or not name or len(name)>1000 or '\x00' in name or '\\' in name:raise ValueError('invalid archive name')
    p=PurePosixPath(name)
    normalized=str(p)
    if normalized=='.':return None
    if p.is_absolute() or '..' in p.parts or ':' in p.parts[0]:raise ValueError('unsafe archive path: '+name)
    return normalized

def inspect():
    seen=set();rows=[];total=0
    with checked_archive() as bounded:
        with tarfile.open(fileobj=bounded,mode='r|') as archive:
            for member in archive:
                name=safe_name(member.name)
                if name is None:
                    if not member.isdir():raise ValueError('non-directory root')
                    continue
                if name in seen:raise ValueError('duplicate member path: '+name)
                seen.add(name)
                if not (member.isdir() or member.isreg()):raise ValueError('link/special archive member: '+name)
                if member.size<0 or member.size>EXTRACT_CAP:raise ValueError('individual member size cap: '+name)
                total+=member.size
                if total>SCAN_CAP or len(seen)>MAX_MEMBERS:raise ValueError('aggregate archive size/member cap')
                rows.append({'name':name,'bytes':member.size,'kind':'directory' if member.isdir() else 'file'})
        scanned=bounded.count
    inventory={'archiveSHA256':json.loads((ROOT/'ACQUISITION_RECEIPT.json').read_text())['sha256'],
        'memberCount':len(rows),'declaredTotalBytes':total,'decompressedBytesScanned':scanned,
        'scanCapBytes':SCAN_CAP,'extractCapBytes':EXTRACT_CAP,'allMembersValidated':True,'members':rows}
    (ROOT/'ARCHIVE_INVENTORY.json').write_text(json.dumps(inventory,indent=2)+'\n')
    print(json.dumps({k:v for k,v in inventory.items() if k!='members'},indent=2))
    for row in rows:
        if row['kind']=='file' and PurePosixPath(row['name']).suffix.lower() in {'.obj','.ply','.mtl','.json','.txt','.md'}:print(row)

def extract(names,selection='selected'):
    if selection not in {'selected','recorded_subset'}:raise ValueError('invalid fixed selection directory')
    inventory=json.loads((ROOT/'ARCHIVE_INVENTORY.json').read_text())
    if inventory.get('allMembersValidated') is not True:raise ValueError('archive was not completely validated')
    if inventory['archiveSHA256']!=json.loads((ROOT/'ACQUISITION_RECEIPT.json').read_text())['sha256']:raise ValueError('inventory does not match acquired archive')
    wanted=set(names)
    if not wanted or len(wanted)!=len(names):raise ValueError('explicit unique selected names required')
    members={r['name']:r for r in inventory['members']}
    if any(safe_name(n)!=n or n not in members or members[n]['kind']!='file' for n in wanted):raise ValueError('unlisted selection')
    total=sum(members[n]['bytes'] for n in wanted)
    existing=sum(p.stat().st_size for folder in ('selected','recorded_subset') for p in (ROOT/folder).rglob('*') if p.is_file())
    if existing+total>EXTRACT_CAP:raise ValueError('aggregate selected extraction cap')
    if shutil.disk_usage(ROOT).free<total+RESERVE:raise RuntimeError('insufficient extraction reserve')
    target=ROOT/(selection+'.partial')
    if (ROOT/selection).exists():raise ValueError('refuse existing completed selection')
    target.mkdir(exist_ok=False)
    receipt=[]
    with checked_archive() as bounded:
        with tarfile.open(fileobj=bounded,mode='r|') as archive:
            for member in archive:
                name=safe_name(member.name)
                if name not in wanted:continue
                if not member.isreg() or member.size!=members[name]['bytes']:raise ValueError('changed member')
                path=target/Path(*PurePosixPath(name).parts);path.parent.mkdir(parents=True,exist_ok=True)
                sha=hashlib.sha256();count=0
                with archive.extractfile(member) as source,path.open('xb') as output:
                    while True:
                        block=source.read(1024**2)
                        if not block:break
                        count+=len(block)
                        if count>member.size:raise ValueError('member expanded beyond declared size')
                        output.write(block);sha.update(block)
                        if shutil.disk_usage(ROOT).free<RESERVE:raise RuntimeError('reserved free space at risk')
                if count!=member.size:raise ValueError('incomplete selected member')
                receipt.append({'name':name,'bytes':count,'sha256':sha.hexdigest()})
    if {r['name'] for r in receipt}!=wanted:raise ValueError('incomplete selected set')
    result={'sourceArchiveSHA256':inventory['archiveSHA256'],'selectedBytes':total,'priorExtractedBytes':existing,
        'freeAfterBytes':shutil.disk_usage(ROOT).free,'files':receipt,
        'meshUnitsGravityHolesStartFitAudited':False,'navigationRun':False}
    (target/'COMPLETE_EXTRACTION_RECEIPT.json').write_text(json.dumps(result,indent=2)+'\n')
    target.rename(ROOT/selection)
    receipt='SELECTIVE_EXTRACTION_RECEIPT.json' if selection=='selected' else 'RECORDED_SUBSET_EXTRACTION_RECEIPT.json'
    (ROOT/receipt).write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))

if __name__=='__main__':
    # tarfile may read extended PAX/GNU metadata before yielding a member.
    # Bound the process as well as the eventual logical archive/member sizes.
    resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2))
    resource.setrlimit(resource.RLIMIT_CPU,(60,60))
    signal.alarm(180)
    if sys.argv[1:]==['list']:inspect()
    elif len(sys.argv)>2 and sys.argv[1]=='extract':extract(sys.argv[2:])
    elif sys.argv[1:]==['extract-recorded']:
        selection=json.loads((ROOT/'RECORDED_SUBSET_SELECTION.json').read_text())
        extract(selection['members'],selection='recorded_subset')
    else:raise SystemExit('usage: guarded_archive.py list | extract EXACT_MEMBER ...')

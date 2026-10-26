"""Exact three-file extraction only. Requires separate approval; no evaluation/raycast.
Uses the reviewed tar guard without modifying it. Failed partial outputs are retained.
"""
from pathlib import Path
import ctypes,errno,gzip,hashlib,importlib.util,json,math,os,resource,shutil,signal,stat,sys,tarfile,time
ROOT=Path(__file__).resolve().parent
STAGE=ROOT/'selected-reference.partial';FINAL=ROOT/'selected-reference'
EXTRACT_CAP=640*1024**2;RESERVE=768*1024**2;SCAN_CAP=2*1024**3
TOTAL=660790468;REPORT_BUDGET=1024**2;CHUNK=1024**2;HEADER_CAP=64*1024
GUARD_SHA='ee2e095bfd35f864d509ede0ec2404362825edff79af38c18f19f8e5e7ea1e37'
TARFILE_SHA='41a9f1930e5285455b4b0db2b9394247cce312c3fa1ef586a58e66c0100668d5'
SOURCES=[{'archive':ROOT/'koivu_mesh_pd.tar.gz','bytes':455583916,
 'sha256':'e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26',
 'inventory':ROOT/'ARCHIVE_INVENTORY.json','inventorySHA256':'bc0a82327bafb6906c431afba0a76c179108ccc5dc2124880c46fee7f32afa09',
 'members':{'room_datasets/koivu/gt_mesh.ply':('gt_mesh.ply',660550085),'room_datasets/koivu/icp_iphone.json':('icp_iphone.json',449)}},
 {'archive':ROOT.parent/'blind-mushroom-koivu-acquisition-01/koivu_iphone.tar.gz','bytes':146575749,
 'sha256':'68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518',
 'inventory':ROOT.parent/'blind-mushroom-koivu-acquisition-01/ARCHIVE_INVENTORY.json','inventorySHA256':'ec0f005863f74b75276593cc2dbbe54057c2d29a2a591a8cde3aa4a847f09037',
 'members':{'room_datasets/koivu/iphone/long_capture/transformations_colmap.json':('transformations_colmap.json',239934)}}]

def sha_file(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(CHUNK),b''):h.update(b)
 return h.hexdigest()
def identity(s):return (s.st_dev,s.st_ino,s.st_size,s.st_mtime_ns,s.st_ctime_ns)
def reserve(remaining):
 free=shutil.disk_usage(ROOT).free;required=RESERVE+remaining+REPORT_BUDGET
 if free<required:raise RuntimeError(f'insufficient free space: available={free} bytes, required={required} bytes, remaining payload={remaining} bytes; reserve and receipt allowance included')
def bounded_json(path,limit=REPORT_BUDGET):
 with path.open('rb') as f:b=f.read(limit+1)
 if len(b)>limit:raise ValueError('JSON byte bound')
 return json.loads(b,parse_constant=lambda v:(_ for _ in ()).throw(ValueError('nonfinite JSON constant')))
def write_json(name,value):
 b=(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+'\n').encode()
 if len(b)>REPORT_BUDGET:raise ValueError('receipt size cap')
 if sum(p.stat().st_size for p in STAGE.iterdir() if p.is_file())+len(b)>EXTRACT_CAP:raise ValueError('staged output cap')
 reserve(0)
 with (STAGE/name).open('xb') as f:f.write(b);f.flush();os.fsync(f.fileno())

def load_guard():
 path=ROOT/'acquire_and_inventory.py'
 if sha_file(path)!=GUARD_SHA or sha_file(Path(tarfile.__file__))!=TARFILE_SHA:raise ValueError('reviewed archive guard/Python tar parser changed')
 spec=importlib.util.spec_from_file_location('reviewed_archive_guard',path);module=importlib.util.module_from_spec(spec)
 sys.dont_write_bytecode=True;spec.loader.exec_module(module)
 return module

class BoundedStream:
 def __init__(self,raw,state):self.raw=raw;self.state=state;self.count=0
 def read(self,n):
  if n<0:raise ValueError('unbounded archive read')
  b=self.raw.read(min(n,SCAN_CAP-self.count+1));self.count+=len(b)
  if self.count>SCAN_CAP:raise ValueError('decompressed scan cap')
  reserve(TOTAL-self.state['written']);return b

def hash_fd(source,expected_bytes):
 source.seek(0);h=hashlib.sha256();count=0
 while True:
  b=source.read(min(CHUNK,expected_bytes-count+1))
  if not b:break
  count+=len(b)
  if count>expected_bytes:raise ValueError('archive byte count changed')
  h.update(b)
 if count!=expected_bytes:raise ValueError('archive byte count mismatch')
 return h.hexdigest()

def extract_archive(spec,guard,state):
 if sha_file(spec['inventory'])!=spec['inventorySHA256']:raise ValueError('reviewed inventory changed')
 inv=bounded_json(spec['inventory']);expected=inv['members']
 if inv['archiveSHA256']!=spec['sha256']:raise ValueError('inventory/archive association')
 seen=set();rows=[];extracted=[];logical=0
 fd=os.open(spec['archive'],os.O_RDONLY|os.O_NOFOLLOW)
 with os.fdopen(fd,'rb') as source:
  before=os.fstat(source.fileno())
  if not stat.S_ISREG(before.st_mode) or before.st_size!=spec['bytes']:raise ValueError('archive must be exact regular file')
  if hash_fd(source,spec['bytes'])!=spec['sha256']:raise ValueError('same-FD archive hash mismatch before parsing')
  source.seek(0)
  with gzip.GzipFile(fileobj=source,mode='rb') as raw:
   bounded=BoundedStream(raw,state)
   with tarfile.open(fileobj=bounded,mode='r|',tarinfo=guard.GuardedTarInfo) as tar:
    for member in tar:
     name=guard.safe_name(member.name)
     if name is None:
      if not member.isdir():raise ValueError('non-directory root member')
      continue
     if name in seen:raise ValueError('duplicate canonical tar member')
     seen.add(name)
     if len(seen)>10000 or not (member.isdir() or member.isreg()) or member.issparse():raise ValueError('link/special/sparse/member cap')
     if any(k.startswith('GNU.sparse') or k=='SCHILY.realsize' for k in member.pax_headers):raise ValueError('sparse metadata rejected')
     if member.size<0 or member.size>SCAN_CAP:raise ValueError('invalid declared member size')
     logical+=member.size
     if logical>SCAN_CAP:raise ValueError('logical bytes cap')
     rows.append({'name':name,'bytes':member.size,'kind':'directory' if member.isdir() else 'file'})
     if name not in spec['members']:continue
     filename,size=spec['members'][name]
     if member.name!=name or not member.isreg() or member.size!=size:raise ValueError('selected original fullname/type/size mismatch')
     if state['written']+size>TOTAL or state['written']+size>EXTRACT_CAP:raise ValueError('selection byte cap')
     data=tar.extractfile(member)
     if data is None:raise ValueError('selected regular member unavailable')
     count=0;digest=hashlib.sha256()
     with data,(STAGE/filename).open('xb') as output:
      while count<size:
       b=data.read(min(CHUNK,size-count))
       if not b:raise ValueError('truncated selected member')
       count+=len(b);state['written']+=len(b)
       if count>size or state['written']>TOTAL:raise ValueError('selected member overflow')
       output.write(b);digest.update(b);reserve(TOTAL-state['written'])
      if data.read(1):raise ValueError('selected member exceeds declared size')
      output.flush();os.fsync(output.fileno())
     row={'archiveSHA256':spec['sha256'],'originalMemberName':member.name,'normalizedMemberName':name,'output':filename,'bytes':count,'sha256':digest.hexdigest()}
     extracted.append(row);state['files'].append(row)
   raw_headers=tar.guard_header_count
   while bounded.read(CHUNK):pass # Consume to gzip EOF and validate trailer/CRC.
   scanned=bounded.count
  if rows!=expected or logical!=inv['declaredTotalBytes']:raise ValueError('full archive differs from reviewed inventory')
  if {f['originalMemberName'] for f in extracted}!=set(spec['members']):raise ValueError('missing selected member')
  if hash_fd(source,spec['bytes'])!=spec['sha256']:raise ValueError('same-FD archive hash changed after parsing')
  after=os.fstat(source.fileno());path_after=os.stat(spec['archive'],follow_symlinks=False)
  if identity(before)!=identity(after) or identity(before)!=identity(path_after):raise ValueError('source archive identity changed during extraction')
 return {'archive':spec['archive'].name,'archiveSHA256':spec['sha256'],'inventorySHA256':spec['inventorySHA256'],'allInventoryMembersMatched':True,
  'sameFDHashBeforeAndAfter':True,'sourceIdentityUnchanged':True,'rawHeaderCount':raw_headers,'decompressedBytesScanned':scanned,'selectedMembers':extracted}

def ply_header_report(path):
 used=0;lines=[]
 with path.open('rb') as f:
  while True:
   line=f.readline(HEADER_CAP-used+1);used+=len(line)
   if not line or used>HEADER_CAP:raise ValueError('PLY header absent or exceeds 64 KiB')
   text=line.decode('ascii').rstrip('\r\n');lines.append(text)
   if text=='end_header':break
 if lines[0]!='ply':raise ValueError('missing PLY signature')
 formats=[s.split() for s in lines if s.startswith('format ')]
 if len(formats)!=1 or len(formats[0])!=3 or formats[0][1] not in ['ascii','binary_little_endian','binary_big_endian'] or formats[0][2]!='1.0':raise ValueError('unsupported PLY format/version')
 elements={}
 for line in lines:
  if line.startswith('element '):
   a=line.split()
   if len(a)!=3 or a[1] in elements or not a[2].isdigit() or int(a[2])>2**63-1:raise ValueError('invalid/duplicate PLY element')
   elements[a[1]]=int(a[2])
 return {'scope':'Header only; no vertices/faces loaded or geometry evaluated','format':formats[0][1],'version':formats[0][2],'headerBytes':used,'headerCapBytes':HEADER_CAP,
  'vertexCount':elements.get('vertex'),'faceCount':elements.get('face'),'elements':elements,'fileBytes':path.stat().st_size,'unitsVerified':False,'gravityVerified':False,'meshCompletenessVerified':False}

def metadata_report(guard,phone_inventory):
 icp=bounded_json(STAGE/'icp_iphone.json',449);poses=bounded_json(STAGE/'transformations_colmap.json',239934)
 def finite_numbers(value,depth=0):
  if depth>64:raise ValueError('JSON nesting bound')
  if isinstance(value,bool) or value is None or isinstance(value,str):return 0
  if isinstance(value,(int,float)):
   if not math.isfinite(value):raise ValueError('nonfinite numeric metadata')
   return 1
  if isinstance(value,list):return sum(finite_numbers(v,depth+1) for v in value)
  if isinstance(value,dict):return sum(finite_numbers(v,depth+1) for v in value.values())
  raise ValueError('unsupported JSON value')
 numeric_icp=finite_numbers(icp);numeric_pose=finite_numbers(poses)
 frames=poses.get('frames') if isinstance(poses,dict) else None
 if not isinstance(frames,list) or len(frames)>10000:raise ValueError('COLMAP frame list contract')
 prefix='room_datasets/koivu/iphone/long_capture/'
 available={r['name'] for r in phone_inventory['members'] if r['kind']=='file'}
 names=[];missing=[];malformed=0
 for frame in frames:
  if not isinstance(frame,dict) or not isinstance(frame.get('file_path'),str):raise ValueError('COLMAP frame association missing')
  relative=guard.safe_name(frame['file_path'])
  if relative is None:raise ValueError('empty image association')
  name=prefix+relative;names.append(name)
  if name not in available:missing.append(name)
  matrix=frame.get('transform_matrix')
  if not (isinstance(matrix,list) and len(matrix)==4 and all(isinstance(row,list) and len(row)==4 and all(isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x) for x in row) for row in matrix)):malformed+=1
 return {'scope':'Metadata values and archive-name association only; no transforms applied, registration tested or depth compared',
  'icpJSON':icp,'icpFiniteNumericValueCount':numeric_icp,'poseFiniteNumericValueCount':numeric_pose,'poseTopLevelKeys':sorted(poses),
  'poseFrameCount':len(frames),'associatedImageNamesUnique':len(set(names))==len(names),'imageNamesMatchedInventory':len(frames)-len(missing),
  'unmatchedImageNames':missing,'malformed4x4TransformCount':malformed,'poseSource':'author-associated exported pose file; filename does not establish successful COLMAP; NOT causal ARKit tracking',
  'alignmentDirectionEstablished':False,'independentPhysicalAccuracyEstablished':False,'raycastExecuted':False,'nativeSensorOrNavigationExecuted':False}

def atomic_publish():
 # Linux no-replace rename provides atomic directory visibility without an overwrite race.
 libc=ctypes.CDLL(None,use_errno=True);rename=getattr(libc,'renameat2',None)
 if rename is None:raise RuntimeError('atomic no-replace rename unavailable; partial retained')
 rename.argtypes=[ctypes.c_int,ctypes.c_char_p,ctypes.c_int,ctypes.c_char_p,ctypes.c_uint];rename.restype=ctypes.c_int
 if rename(-100,os.fsencode(STAGE),-100,os.fsencode(FINAL),1)!=0:
  code=ctypes.get_errno();raise OSError(code,os.strerror(code))

def main():
 if sys.argv[1:]!=['extract-approved-selection']:raise SystemExit('usage: extract_selected.py extract-approved-selection (requires separate authorization/review)')
 if STAGE.exists() or STAGE.is_symlink() or FINAL.exists() or FINAL.is_symlink():raise RuntimeError('refuse existing output/partial overwrite')
 resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,384*1024**2));resource.setrlimit(resource.RLIMIT_CPU,(300,300))
 def timed_out(signum,frame):raise TimeoutError('300-second wall cap')
 signal.signal(signal.SIGALRM,timed_out);signal.alarm(300)
 start=time.monotonic();cpu_start=time.process_time();reserve(TOTAL);guard=load_guard();STAGE.mkdir(mode=0o700)
 state={'written':0,'files':[]};receipts=[]
 try:
  for source in SOURCES:receipts.append(extract_archive(source,guard,state))
  if state['written']!=TOTAL or len(state['files'])!=3:raise ValueError('exact three-file total mismatch')
  for f in state['files']:
   p=STAGE/f['output']
   if p.stat().st_size!=f['bytes'] or sha_file(p)!=f['sha256']:raise ValueError('output content verification failed')
  write_json('PLY_HEADER_REPORT.json',ply_header_report(STAGE/'gt_mesh.ply'))
  write_json('POSE_METADATA_REPORT.json',metadata_report(guard,bounded_json(SOURCES[1]['inventory'])))
  receipt={'status':'completed exact selective extraction and bounded metadata/header inspection only','files':state['files'],'archives':receipts,
   'selectedBytes':state['written'],'extractionCapBytes':EXTRACT_CAP,'reservedFreeBytes':RESERVE,'wallCapSeconds':300,'cpuCapSeconds':300,'addressSpaceCapBytes':384*1024**2,
   'wallSeconds':time.monotonic()-start,'cpuSeconds':time.process_time()-cpu_start,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
   'helperSHA256':sha_file(Path(__file__)),'archiveGuardSHA256':GUARD_SHA,'tarfileSourceSHA256':TARFILE_SHA,
   'pointCloudExtracted':False,'meshLoaded':False,'raycastExecuted':False,'comparisonExecuted':False,'navigationExecuted':False}
  write_json('EXTRACTION_RECEIPT.json',receipt);reserve(0);atomic_publish();signal.alarm(0)
  print(json.dumps(receipt,indent=2),flush=True)
 except BaseException as error:
  if STAGE.is_dir():
   try:write_json('FAILURE_RECEIPT.json',{'error':repr(error),'partialRetained':True,'selectedBytesWritten':state['written'],'completedFiles':state['files'],'comparisonExecuted':False})
   except Exception:pass
  raise
if __name__=='__main__':main()

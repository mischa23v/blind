import pathlib,json,urllib.request,hashlib,time,resource,tarfile,os,shutil
R=pathlib.Path(__file__).resolve().parent;start=time.monotonic();resource.setrlimit(resource.RLIMIT_AS,(536870912,536870912));s=json.loads((R/'SELECTION.json').read_text());meta=json.loads((R/'OFFICIAL_METADATA.json').read_text());entry=next(x for x in meta['files'] if x['key']=='coffee_room_iphone.tar.gz');assert entry['size']==s['expectedArchiveBytes'] and entry['checksum']=='md5:'+s['expectedMD5'];assert shutil.disk_usage(R).free>768*1024**2+500000000
selectionSHA=hashlib.sha256((R/'SELECTION.json').read_bytes()).hexdigest();n=0;md=hashlib.md5();sh=hashlib.sha256();archive=R/'coffee_room_iphone.tar.gz';url=entry['links']['self'];assert url=='https://zenodo.org/api/records/10230733/files/coffee_room_iphone.tar.gz/content'
with urllib.request.urlopen(url,timeout=30) as response,archive.open('xb') as out:
 assert response.url.startswith('https://zenodo.org/'),response.url
 while True:
  assert time.monotonic()-start<600
  b=response.read(min(1048576,200000000-n+1))
  if not b:break
  n+=len(b);assert n<=200000000
  out.write(b);md.update(b);sh.update(b)
assert n==entry['size'] and md.hexdigest()==s['expectedMD5'];assert sh.hexdigest()=='591672a1c4afa50e5109fc78ff08d8f608d05756a9181cfdd7cef38a57a1623d'
wanted=set(s['members']);rows=[];kept=0
with tarfile.open(archive,'r|gz') as t:
 for m in t:
  assert time.monotonic()-start<600
  if m.name not in wanted:continue
  p=pathlib.PurePosixPath(m.name);assert not p.is_absolute() and '..' not in p.parts and m.isfile() and not m.issym() and not m.islnk() and 0<=m.size<=5000000
  dest=R/'selected'/p;dest.parent.mkdir(parents=True,exist_ok=True);h=hashlib.sha256();count=0
  with t.extractfile(m) as inp,dest.open('xb') as out:
   while True:
    b=inp.read(1048576)
    if not b:break
    count+=len(b);kept+=len(b);assert count<=m.size and n+kept<500000000;h.update(b);out.write(b)
  assert count==m.size;rows.append({'member':m.name,'bytes':count,'sha256':h.hexdigest()});wanted.remove(m.name)
assert not wanted
result={'officialMetadataChecked':True,'selectionSHA256':selectionSHA,'networkArchiveBytes':n,'archiveSHA256':sh.hexdigest(),'archiveMD5':md.hexdigest(),'selectedBytes':kept,'files':rows,'wallSeconds':time.monotonic()-start,'peakRSSKiB':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,'processAddressSpaceCapBytes':536870912,'rawImagesNotForGitPublication':True}
(R/'ACQUISITION_RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items() if k!='files'},indent=2))

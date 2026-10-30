import pathlib,sys,json,gzip,hashlib,collections,resource
resource.setrlimit(resource.RLIMIT_CPU,(60,60));resource.setrlimit(resource.RLIMIT_AS,(384*1024**2,)*2)
W=pathlib.Path(__file__).resolve().parents[3];S=W/'blind/research/detour-height-follow-compact-source-20261030';sys.path.insert(0,str(S))
from contact_codec import decode_record,canonical
from vtk_contract import validate_vtk
D=W/'detour-height-follow-attempt-002';old=W/'detour-height-follow-attempt-001'
validated=validate_vtk(D/'vtk',W/'blind',W/'rapier-real-room-inputs-001',D/'height/events.jsonl')
header=json.loads((D/'vtk/CONTACT_ENCODING.json').read_text());cat=json.loads((D/'vtk/TRIANGLE_CATALOG.json').read_text())['triangles'];stats={};pairs={};prefix=0;ph=hashlib.sha256();nh=hashlib.sha256();row_count=0
with gzip.open(D/'vtk/contacts.jsonl.gz','rt')as f,gzip.open(old/'vtk/contacts.jsonl.gz','rt')as o:
 for line in f:
  r=decode_record(json.loads(line),header);row_count+=1;prev=o.readline()
  if prev:
   a=canonical(json.loads(prev));b=canonical(r);assert a==b;ph.update((a+'\n').encode());nh.update((b+'\n').encode());prefix+=1
  key=f"{r['scene']}:{r['envelope']}:{r['lowerTrimMetres']}";arm=r['arm'];k=key+':'+arm
  z=stats.setdefault(k,{'records':0,'contactEvents':0,'hitOccurrences':0,'faces':set(),'high50cmEvents':0,'high50cmFaces':set(),'above5cmEvents':0})
  z['records']+=1;ids=r['contactIDs'];assert ids is not None;z['contactEvents']+=bool(ids);z['hitOccurrences']+=len(ids);z['faces'].update(ids)
  high=[c for c in ids if cat[r['scene']+':'+str(c)]['modelHeightRange'][0]>=r['startFoot'][1]+.5];z['high50cmEvents']+=bool(high);z['high50cmFaces'].update(high);z['above5cmEvents']+=any(cat[r['scene']+':'+str(c)]['modelHeightRange'][0]>=r['startFoot'][1]+.05 for c in ids)
  if arm=='historical_xyz':pairs[(key,r['eventIndex'])]=r
  else:
   h=pairs.pop((key,r['eventIndex']));lost=set(h['contactIDs'])-set(ids);added=set(ids)-set(h['contactIDs']);p=stats.setdefault(key+':paired',{'lostOccurrences':0,'addedOccurrences':0,'lostFaces':set(),'addedFaces':set(),'lostHigh50cmOccurrences':0,'addedHigh50cmOccurrences':0,'lostAboveNewFootOccurrences':0,'newOnlyContactEvents':0,'contactRemovedEvents':0,'lostWholeTriangleBelowNewFootOccurrences':0,'lostExtends50cmAboveOriginalFootOccurrences':0,'maxLostTriangleAboveOriginalFootMetres':None,'maxLostTriangleAboveNativeFootMetres':None})
   p['lostOccurrences']+=len(lost);p['addedOccurrences']+=len(added);p['lostFaces'].update(lost);p['addedFaces'].update(added);p['lostHigh50cmOccurrences']+=sum(cat[r['scene']+':'+str(c)]['modelHeightRange'][0]>=h['startFoot'][1]+.5 for c in lost);p['addedHigh50cmOccurrences']+=sum(cat[r['scene']+':'+str(c)]['modelHeightRange'][0]>=r['startFoot'][1]+.5 for c in added);p['lostAboveNewFootOccurrences']+=sum(cat[r['scene']+':'+str(c)]['modelHeightRange'][0]>=r['startFoot'][1]for c in lost);p['lostWholeTriangleBelowNewFootOccurrences']+=sum(cat[r['scene']+':'+str(c)]['modelHeightRange'][1]<r['startFoot'][1]for c in lost);p['lostExtends50cmAboveOriginalFootOccurrences']+=sum(cat[r['scene']+':'+str(c)]['modelHeightRange'][1]>=h['startFoot'][1]+.5 for c in lost)
   if lost:
    upper=max(cat[r['scene']+':'+str(c)]['modelHeightRange'][1]for c in lost);p['maxLostTriangleAboveOriginalFootMetres']=max(p['maxLostTriangleAboveOriginalFootMetres']if p['maxLostTriangleAboveOriginalFootMetres']is not None else -1e9,upper-h['startFoot'][1]);p['maxLostTriangleAboveNativeFootMetres']=max(p['maxLostTriangleAboveNativeFootMetres']if p['maxLostTriangleAboveNativeFootMetres']is not None else -1e9,upper-r['startFoot'][1])
   p['newOnlyContactEvents']+=bool(ids)and not h['contactIDs'];p['contactRemovedEvents']+=bool(h['contactIDs'])and not ids
assert row_count==29568 and prefix==29069 and not pairs
for s in stats.values():
 for k,v in list(s.items()):
  if isinstance(v,set):s[k+'Count']=len(v);s[k]=sorted(v)
shifts={}
for line in(D/'height/events.jsonl').read_text().splitlines():
 h=json.loads(line);d=shifts.setdefault(h['scene'],[])
 for k in ('a','b'):d.append(h[k][1]-h['originalEvent'][k][1])
print(json.dumps({'validated':validated,'prefixRowsIdentical':prefix,'prefixOriginalCanonicalSHA':ph.hexdigest(),'prefixNewCanonicalSHA':nh.hexdigest(),'heightBytesIdentical':(old/'height/events.jsonl').read_bytes()==(D/'height/events.jsonl').read_bytes(),'shifts':{k:{'min':min(v),'max':max(v),'positive':sum(x>0 for x in v),'negative':sum(x<0 for x in v),'total':len(v)}for k,v in shifts.items()},'stats':stats,'physicalSafetyEstablished':False},indent=2))

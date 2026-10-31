"""Stdlib-only terminal reconciliation for frozen full-route VTK evidence."""
import gzip,hashlib,importlib.util,json,math,pathlib,struct,sys
H=pathlib.Path(__file__).resolve().parent
def need(v,m):
 if not v:raise ValueError(m)
def validate_vtk(work_vtk,repo,mesh_root,height_events):
 d=pathlib.Path(work_vtk);repo=pathlib.Path(repo);mesh_root=pathlib.Path(mesh_root);height_events=pathlib.Path(height_events)
 sys.path.insert(0,str(H))
 spec=importlib.util.spec_from_file_location('validation_schedule',H/'schedule_contract.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod);schedules=mod.load_schedules(repo)
 from contact_codec import HEADER,decode_record
 header=json.loads((d/'CONTACT_ENCODING.json').read_text());need(header==HEADER,'contact encoding header')
 heights=[json.loads(x)for x in height_events.read_text().splitlines()];lookup={(h['scene'],h['name'],h['eventIndex']):h for h in heights};need(len(lookup)==len(heights)==3696,'height row denominator')
 s=json.loads((d/'SUMMARY.json').read_text());need(s['status']=='completed_full_route_diagnostic_only','VTK worker failed')
 for k,v in {'records':29568,'movementApplied':False,'physicalAuthority':False,'groundExemptions':False,'semanticFloorEstablished':False,'supportEstablished':False,'arrivalEstablished':False,'allContactIDsRetained':True,'inputHashesAfterMatch':True,'catalogWritten':True,'contactEncoding':'lossless-contact-defaults-v1'}.items():need(s.get(k)==v,'VTK summary '+k)
 need(s['contactEncodingSHA256']==hashlib.sha256((d/'CONTACT_ENCODING.json').read_bytes()).hexdigest(),'encoding header binding')
 need(s['heightEventsSHA256']==hashlib.sha256(height_events.read_bytes()).hexdigest(),'height input digest')
 catalog=json.loads((d/'TRIANGLE_CATALOG.json').read_text())['triangles'];buffers={}
 for scene in ['conference','coffee']:buffers[scene]=((mesh_root/(scene+'.vertices.f32')).read_bytes(),(mesh_root/(scene+'.indices.u32')).read_bytes())
 for key,c in catalog.items():
  scene=c['scene'];cid=c['triangleID'];need(key==scene+':'+str(cid) and type(cid)is int and cid>=0,'catalog identity');vb,ib=buffers[scene];need((cid+1)*12<=len(ib),'catalog triangle bounds');ids=list(struct.unpack_from('<III',ib,cid*12));need(ids==c['originalVertexIDs'],'original triangle vertex identity');ys=[struct.unpack_from('<f',vb,j*12+4)[0]for j in ids];need(c['modelHeightRange']==[min(ys),max(ys)]and c['heightIsWholeTriangleNotContactPoint']is True,'catalog true wholetriangle heights')
 expected=((route,i,e,arm,envelope,trim)for route in schedules for i,e in enumerate(route['events'])for arm in ('historical_xyz','native_height')for envelope in ('body','horizontal_margin')for trim in (0.,.002))
 count=queried=unavailable=hits=decoded=0;used=set()
 with gzip.open(d/'contacts.jsonl.gz','rb')as f:
  for route,i,e,arm,envelope,trim in expected:
   line=f.readline(2*1024**2+1);need(line and len(line)<=2*1024**2,'missing/oversized VTK row');decoded+=len(line);need(decoded<=64*1024**2,'decoded evidence cap');r=decode_record(json.loads(line),header);h=lookup[(route['scene'],route['name'],i)]
   for k,v in {'scene':route['scene'],'name':route['name'],'eventIndex':i,'kind':e['kind'],'arm':arm,'envelope':envelope,'lowerTrimMetres':trim,'yaw':e['yaw'],'dyaw':e['dyaw'],'movementApplied':False,'physicalAuthority':False,'support':'unknown','semanticFloor':'unknown','nativeHeightValid':h['valid'],'nativeHeightUnavailableReason':h['unavailableReason'],'nativeHeightQueryEvidenceKey':[route['scene'],route['name'],i]}.items():need(r.get(k)==v,'VTK row identity '+k)
   count+=1
   if arm=='native_height'and not h['valid']:
    need(r['status']=='unavailable_native_height'and r['queryExecuted']is False and r['contactIDs']is None,'invalid native step hidden/queried');unavailable+=1;continue
   start=e['a']if arm=='historical_xyz'else h['a'];end=e['b']if arm=='historical_xyz'else h['b'];need(r['startFoot']==start and r['endFoot']==end and r['queryExecuted']is True and r['status']=='queried','VTK query pose')
   need(r['originalStartFoot']==e['a']and r['originalEndFoot']==e['b']and r['startVerticalShiftMetres']==start[1]-e['a'][1]and r['endVerticalShiftMetres']==end[1]-e['b'][1],'vertical shift accounting')
   for key,orig,actual in [('start',e['a'],start),('end',e['b'],end)]:
    band=r['verticalShiftCoverage'][key];need(band['uncoveredLowerBand']==([orig[1]+trim,actual[1]+trim]if actual[1]>orig[1]else None)and band['newlyCoveredLowerBand']==([actual[1]+trim,orig[1]+trim]if actual[1]<orig[1]else None),'endpoint lower-band accounting')
   ids=r['contactIDs'];res=r['result'];need(len(ids)==len(set(ids))==r['nonGroundContactCount']==res['nonGroundContactCount']and res['groundContactCount']==0 and bool(ids)==res['contact'],'complete hit inventory')
   if ids:need(res['firstReferenceCellID']==ids[0],'first ID identity')
   need(res['completeCandidateContactCounts']and not res['physicalAuthority']and not res['physicalClearanceEstablished']and not res['closedSolidContainmentClassified'],'kernel authority/coverage')
   sw=r['sweep'];need(sw['floorContactExclusionMetres']==trim and sw['actualYawDeltaRadians']==e['dyaw']and sw['verticalBoundsMetres']==[min(start[1],end[1])+trim,max(start[1],end[1])+1.6],'exact swept height/yaw')
   for cid in ids:
    key=route['scene']+':'+str(cid);need(key in catalog,'missing all-hit catalog entry');used.add(key)
   queried+=1;hits+=len(ids)
  need(not f.read(1),'extra VTK rows')
 need(count==29568 and queried==s['queries']and unavailable==sum(not h['valid']for h in heights)*4,'complete query/unavailable accounting');need(used==set(catalog),'catalog extra/missing faces')
 return {'records':count,'queried':queried,'unavailable':unavailable,'contactOccurrences':hits,'uniqueContactTriangles':len(used),'physicalAuthority':False,'movementApplied':False}

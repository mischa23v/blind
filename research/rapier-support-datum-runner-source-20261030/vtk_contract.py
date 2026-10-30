"""Stdlib terminal check only; does not import or run VTK."""
import json,math,pathlib

def validate_vtk(work_vtk,frozenEntries):
 d=pathlib.Path(work_vtk);s=json.loads((d/'SUMMARY.json').read_text());rows=[json.loads(x)for x in (d/'rows.jsonl').read_text().splitlines()]
 for k,v in {'status':'completed_no_exemption_fixed_pose_contacts','queries':96,'movementApplied':False,'physicalAuthority':False,'groundExemptions':False,'semanticFloorEstablished':False,'supportEstablished':False,'arrivalEstablished':False,'allContactIDsRetained':True,'inputHashesAfterMatch':True}.items():
  if s.get(k)!=v:raise ValueError('VTK terminal contract: '+k)
 expected=[(x,e,b)for x in frozenEntries for e in ['body','horizontal_margin']for b in [0,.002]]
 if len(rows)!=96 or len(expected)!=96:raise ValueError('VTK fixed inventory')
 for r,(x,e,b)in zip(rows,expected):
  p=x['probe'];source,datum,intent=p['id'].split('|');end=[a+b for a,b in zip(p['foot'],p['desiredDelta'])]
  for k,v in {'probeId':p['id'],'scene':x['scene'],'sourceId':source,'datumArm':datum,'inputArm':intent,'envelope':e,'lowerTrimMetres':b,'startFoot':p['foot'],'endFoot':end,'requestedDelta':p['desiredDelta'],'yawRadians':p['yawRadians'],'movementApplied':False,'physicalAuthority':False,'support':'unknown','semanticFloor':'unknown'}.items():
   if r.get(k)!=v:raise ValueError('VTK exact row binding: '+k)
  result=r['result'];contacts=r['contacts'];ids=[c['triangleID']for c in contacts]
  if len(ids)!=len(set(ids)) or len(ids)!=result['nonGroundContactCount']or len(ids)!=result['rawContactCount']or bool(ids)!=result['contact']or result['groundContactCount']!=0 or result['groundExemptions'] is not False:raise ValueError('VTK complete hit accounting')
  if ids and result['firstReferenceCellID']!=ids[0]:raise ValueError('VTK first hit identity')
  if not result['completeCandidateContactCounts'] or result['physicalAuthority'] or result['physicalClearanceEstablished']or result['closedSolidContainmentClassified']:raise ValueError('VTK authority/coverage')
  sweep=r['sweep']
  if sweep['floorContactExclusionMetres']!=b or sweep['actualYawDeltaRadians']!=0 or sweep['verticalBoundsMetres']!=[min(p['foot'][1],end[1])+b,max(p['foot'][1],end[1])+1.6]:raise ValueError('VTK band or turn mismatch')
  for c in contacts:
   if not isinstance(c['triangleID'],int) or c['triangleID']<0 or len(c['originalVertexIDs'])!=3:raise ValueError('VTK triangle identity')
   h=c['modelHeightRange']
   if len(h)!=2 or not all(math.isfinite(v)for v in h) or h[0]>h[1]:raise ValueError('VTK finite whole triangle range')
   if c['relativeToStartFootHeightRange']!=[v-p['foot'][1]for v in h]or c['relativeToEndFootHeightRange']!=[v-end[1]for v in h]or c['heightIsWholeTriangleNotContactPoint']is not True:raise ValueError('VTK height convention')
 return {'verifiedVTKRows':96,'summary':s}

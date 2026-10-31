#!/usr/bin/env python3
"""Reproduce saved-result audit using stdlib only; never execute geometry engines."""
import collections,gzip,hashlib,json,math,pathlib,sys
H=pathlib.Path(__file__).resolve().parent;REPO=H.parents[1];W=REPO.parent
SOURCE=REPO/'research/detour-height-follow-compact-source-20261030';sys.path.insert(0,str(SOURCE))
from contact_codec import decode_record,canonical
from validate_results import validate_results
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def save(path,x):path.write_text(json.dumps(x,indent=2,allow_nan=False)+'\n')
def main():
 out=pathlib.Path(sys.argv[1]);out.mkdir(exist_ok=False)
 work=W/'detour-height-follow-attempt-002';old=W/'detour-height-follow-attempt-001'
 validation=validate_results(work,SOURCE,'e8ead6eb6cc7909a1391ab35e8e77a4c843bed14ae7ec7403a075ad2e35c0783')
 guard=json.loads((work/'GUARD_RUN/RESULT.json').read_text());assert guard['sourceCommit']=='0a1a59cd580239a52939f5cdc9642cc608ece425'and guard['status']=='completed-two-route-height-diagnostic-only'
 assert guard['inputHashesBefore']==guard['inputHashesAfter']and all(c['exitCode']==0 and c['groupRetired']for c in guard['commands'])
 header=json.loads((work/'vtk/CONTACT_ENCODING.json').read_text());catalog=json.loads((work/'vtk/TRIANGLE_CATALOG.json').read_text())['triangles'];groups={};changes=[];endpoints=[];prefix_count=0;prefix_hash=hashlib.sha256();decoded_hash=hashlib.sha256();event_group=[]
 def process(rows):
  assert len(rows)==8
  pairs={}
  for r in rows:
   groupkey=(r['scene'],r['envelope'],r['lowerTrimMetres']);g=groups.setdefault(groupkey,{'historical_xyz':collections.Counter(),'native_height':collections.Counter(),'lost':collections.Counter(),'added':collections.Counter(),'pairCases':collections.Counter(),'lostIDs':set(),'addedIDs':set(),'lostRelativeHeightRange':None})
   ids=r['contactIDs'];stat=g[r['arm']];stat['events']+=1;stat['contactEvents']+=bool(ids);stat['contactOccurrences']+=len(ids);stat['contactEvents_'+r['kind']]+=bool(ids);stat['events_'+r['kind']]+=1
   high=[cid for cid in ids if catalog[r['scene']+':'+str(cid)]['modelHeightRange'][0]-max(r['startFoot'][1],r['endFoot'][1])>.1]
   stat['eventsWithEntireTriangleAbove10cm']+=bool(high);stat['entireTriangleAbove10cmOccurrences']+=len(high)
   pairs.setdefault((r['envelope'],r['lowerTrimMetres']),{})[r['arm']]=r
  for(env,trim),pair in pairs.items():
   a,b=pair['historical_xyz'],pair['native_height'];g=groups[(a['scene'],env,trim)];aa,bb=set(a['contactIDs']),set(b['contactIDs']);lost,added=aa-bb,bb-aa
   g['pairCases']['becameNoContact']+=bool(aa)and not bb;g['pairCases']['becameContact']+=not aa and bool(bb);g['pairCases']['sameIDSet']+=aa==bb
   for label,ids in [('lost',lost),('added',added)]:
    g[label]['occurrences']+=len(ids);g[label+'IDs'].update(ids)
    for cid in ids:
     ymin,ymax=catalog[a['scene']+':'+str(cid)]['modelHeightRange'];lo=ymin-max(a['startFoot'][1],a['endFoot'][1]);hi=ymax-min(a['startFoot'][1],a['endFoot'][1]);category='entirelyAbove10cm'if lo>.1 else'entirelyAtOrBelow10cm'if hi<=.1 else'straddles10cm';g[label][category]+=1
     if label=='lost':
      g[label]['wholeTriangleBelowBothNativeFeet']+=ymax<min(b['startFoot'][1],b['endFoot'][1])
      prev=g['lostRelativeHeightRange'];g['lostRelativeHeightRange']=[lo,hi]if prev is None else[min(prev[0],lo),max(prev[1],hi)]
   if lost or added:
    changes.append({'scene':a['scene'],'name':a['name'],'eventIndex':a['eventIndex'],'kind':a['kind'],'envelope':env,'lowerTrimMetres':trim,'originalStartFoot':a['startFoot'],'originalEndFoot':a['endFoot'],'nativeStartFoot':b['startFoot'],'nativeEndFoot':b['endFoot'],'originalContactIDs':a['contactIDs'],'nativeContactIDs':b['contactIDs'],'lostIDs':sorted(lost),'addedIDs':sorted(added),'verticalShiftCoverage':b['verticalShiftCoverage']})
   if a['kind']in ['initial','terminal']:
    endpoints.append({'scene':a['scene'],'kind':a['kind'],'eventIndex':a['eventIndex'],'envelope':env,'lowerTrimMetres':trim,'originalFoot':a['startFoot'],'nativeFoot':b['startFoot'],'originalContactCount':len(aa),'nativeContactCount':len(bb),'originalContactIDs':a['contactIDs'],'nativeContactIDs':b['contactIDs']})
 with gzip.open(old/'vtk/contacts.jsonl.gz','rt')as previous,gzip.open(work/'vtk/contacts.jsonl.gz','rt')as stream:
  count=0
  for line in stream:
   r=decode_record(json.loads(line),header);count+=1;earlier=previous.readline()
   if earlier:
    before=json.loads(earlier);assert before==r and canonical(before)==canonical(r);b=(canonical(r)+'\n').encode();prefix_hash.update((canonical(before)+'\n').encode());decoded_hash.update(b);prefix_count+=1
   event_group.append(r)
   if len(event_group)==8:process(event_group);event_group=[]
  assert not previous.readline()and count==29568 and prefix_count==29069 and not event_group
 group_rows=[]
 for k,g in groups.items():
  g['lostUniqueIDs']=sorted(g.pop('lostIDs'));g['addedUniqueIDs']=sorted(g.pop('addedIDs'));group_rows.append({'scene':k[0],'envelope':k[1],'lowerTrimMetres':k[2],**g})
 native=json.loads((work/'height/SUMMARY.json').read_text());events=[json.loads(x)for x in(work/'height/events.jsonl').read_text().splitlines()]
 residuals=[]
 for e in events:
  for key,actual in [('a',e['actualNativeA']),('b',e['actualNativeB'])]:residuals.append(math.hypot(actual[0]-e['originalEvent'][key][0],actual[2]-e['originalEvent'][key][2]))
 paths=['GUARD_RUN/RESULT.json','height/SUMMARY.json','height/events.jsonl','vtk/SUMMARY.json','vtk/contacts.jsonl.gz','vtk/CONTACT_ENCODING.json','vtk/TRIANGLE_CATALOG.json','libheight_follow.so']
 sourcefiles=json.loads((SOURCE/'SOURCE_FREEZE.json').read_text());assert all(sha(SOURCE/n)==d for n,d in sourcefiles.items())
 results={'status':'completed_saved_result_audit_not_movement_acceptance','sourceCommit':guard['sourceCommit'],'sourceManifestSHA256':sha(SOURCE/'RUN_PINS.json'),'sourceFreezeSHA256':sha(SOURCE/'SOURCE_FREEZE.json'),'validation':validation,'runtime':{k:guard[k]for k in ['wallSeconds','aggregateCPUSeconds','peakObservedAggregateRSS','peakFastExitChildRSS']},'immutableInputPins':len(guard['inputHashesBefore']),'allChildGroupsRetired':True,'rawHashes':{p:sha(work/p)for p in paths},'oldNativeEventSHA256':sha(old/'height/events.jsonl'),'exactNativeEventBytesReproduced':True,'oldVTKPrefix':{'records':prefix_count,'allDecodedObjectsEqual':True,'originalCanonicalSHA256':prefix_hash.hexdigest(),'decodedCanonicalSHA256':decoded_hash.hexdigest()},'maximumActualNativeXZResidualMetres':max(residuals),'desiredXZAndAuthoredHeadingsUnchanged':True,'groups':group_rows,'changedPairs':len(changes),'eventsTotal':3696,'vtkRecords':29568,'vtkSummary':json.loads((work/'vtk/SUMMARY.json').read_text()),'heightBandRule':'10cm is descriptive only, whole triangle relative to original event foot range; not contact point or a safe floor band','physicalStartKnown':False,'continuousSupportEstablished':False,'lowObjectsInUncoveredBandResolved':False,'movementApplied':False,'arrivalEstablished':False,'appChanged':False}
 used_changed={r['scene']+':'+str(cid)for r in changes for key in ['originalContactIDs','nativeContactIDs']for cid in r[key]}
 save(out/'RESULTS.json',results);save(out/'CONTACT_CHANGES.json',{'pairs':changes,'noFilteringOfLostOrAddedIDs':True,'catalogScope':'all IDs referenced in changed pairs; complete971-face source catalog retained by raw hash and checked by validator','wholeTriangleCatalog':{k:catalog[k]for k in sorted(used_changed)}});save(out/'ENDPOINTS.json',endpoints);save(out/'NATIVE_ASSOCIATIONS.json',native['scenes'])
 print(json.dumps({'status':results['status'],'groups':len(group_rows),'changedPairs':len(changes),'records':29568,'prefix':prefix_count,'maxXZResidual':max(residuals)}))
if __name__=='__main__':main()

#!/usr/bin/env python3
"""Bounded stdlib recount of both frozen complete-ID runs; no native query."""
import argparse,gzip,hashlib,importlib.util,json,os,pathlib,resource,sys,time
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
ARMS=('actualBody','horizontalMargin')
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def need(x,m):
 if not x:raise ValueError(m)
def read(p):return json.loads(p.read_text())
def main():
 a=argparse.ArgumentParser();a.add_argument('--pins-sha256',required=True);a.add_argument('--out',type=pathlib.Path,required=True);a=a.parse_args()
 t=time.monotonic();c=time.process_time();resource.setrlimit(resource.RLIMIT_CPU,(30,30));resource.setrlimit(resource.RLIMIT_CORE,(0,0));os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
 need(sha(H/'AUDIT_PINS.json')==a.pins_sha256,'external pins');pins=read(H/'AUDIT_PINS.json')
 def verify():
  for name,d in pins['inputs'].items():need(sha(W/name)==d,'changed '+name)
 def budget():need(time.monotonic()-t<60 and time.process_time()-c<30 and resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024<256*1024**2,'audit budget')
 verify();out=a.out.resolve();out.relative_to(W);out.mkdir(exist_ok=False)
 hp=R/'research/conference-contact-ids-result-20261030/recount_heights.py';spec=importlib.util.spec_from_file_location('frozen_height_helpers',hp);h=importlib.util.module_from_spec(spec);spec.loader.exec_module(h)
 reports={}
 for variant,attempt,source in [('baseline','conference-contact-ids-attempt-001','conference-contact-ids-source-20261030'),('simplified','conference-simplified-body-attempt-001','conference-simplified-body-source-20261030')]:
  root=W/attempt;g=read(root/'GUARD_RUN/RESULT.json');sp=read(R/'research'/source/'SOURCE_PINS.json');receipt=read(root/'comparison/RECEIPT.json')
  need(g['status']=='completed-zero-exit' and all(x['exitCode']==0 and x['groupRetired'] is True for x in g['commands']),'guard completion')
  need(g['inputHashesBefore']==g['inputHashesAfter']==sp['inputs'] and g['pins']==sp,'guard input identities')
  need(g['manifestSHA256']==sha(R/'research'/source/'SOURCE_PINS.json')==receipt['pinsSHA256'],'source manifest')
  for name,v in g['finalPayloadInventory'].items():
   if name.endswith('/'):continue
   p=root/name;need(p.stat().st_size==v['bytes'] and sha(p)==v['sha256'],'terminal bytes')
  need(receipt['status']=='rawDiagnosticCompleted' and all(receipt[k] is False for k in ('physicalAuthority','continuousSupportProven','semanticFloorEstablished','coverageEstablished','movementEpisode','arrivalClaimed','validatedCameraMeshAlignment')),'authority boundary')
  heights=h.source_heights(sp);routes=read(R/'research'/('conference-body-source-20261029' if variant=='baseline' else source)/'ROUTES.json')['paths'];need(len(routes)==len(receipt['paths'])==7,'seven routes')
  globalarms={k:h.new_arm() for k in ARMS};rows=[];events=hitsum=candidates=cb=ib=0;digest=hashlib.sha256()
  with gzip.open(root/'comparison/CONTACTS.jsonl.gz','rb') as contacts,gzip.open(root/'comparison/HIT_IDS.jsonl.gz','rb') as ids:
   for route,reported in zip(routes,receipt['paths']):
    need(route['name']==reported['name'],'route ordering');arms={k:h.new_arm() for k in ARMS};schedule=h.frozen_schedule(route,sp)
    for n,event in enumerate(schedule):
     raw,row=h.finite_row(contacts);rawid,identity=h.finite_row(ids);cb+=len(raw);ib+=len(rawid)
     need(row['path']==identity['path']==route['name'] and row['event']==identity['event']==n and row['authoredIncrement']==event,'event identity')
     counts=[]
     for arm,key in [('actualBody','actualBodyTriangleIDs'),('horizontalMargin','horizontalMarginTriangleIDs')]:
      hit=identity[key];r=row['contacts'][arm];need(len(set(hit))==len(hit) and all(type(i)is int and 0<=i<len(heights) for i in hit),'unique valid IDs')
      need(len(hit)==r['rawContactCount']==r['nonGroundContactCount'] and r['groundContactCount']==0 and r['contact'] is bool(hit),'full returned hit counts')
      need(len(hit)<=r['candidateTriangles']<=29366,'candidates');counts.append(r['candidateTriangles']);hitsum+=len(hit)
      if hit:need(hit[0]==r['firstReferenceCellID'] and heights[hit[0]]==r['firstTriangleModelHeightRange'],'witness source')
      else:need(r['firstReferenceCellID'] is None,'empty witness')
      h.accumulate(arms[arm],hit,event,heights);h.accumulate(globalarms[arm],hit,event,heights)
     digest.update(('%d,%d\n'%tuple(counts)).encode());candidates+=sum(counts);events+=1
     need(hitsum<=200000 and cb+ib<=64*1024**2 and ib<=8*1024**2,'output budget')
     if events%128==0:budget()
    arms={k:h.finish_arm(v) for k,v in arms.items()};need(reported['completedEvents']==len(schedule),'schedule complete')
    for arm in ARMS:need(reported['contactEvents'][arm]==arms[arm]['references']['startFoot']['events']['contact'],'contact event recount')
    rows.append({'name':route['name'],'authoredEvents':len(schedule),'arms':arms})
   need(contacts.read(1)==ids.read(1)==b'','extra data')
  recorder=receipt['hitRecorder'];need(recorder['complete'] is True and recorder['logicalBytes']==ib and recorder['candidateCountStreamSHA256']==digest.hexdigest(),'recorder identity')
  need(receipt['counters']=={'boxes':2*events,'triangles':candidates,'rays':0} and receipt['outputLogicalBytes']==cb,'worker counters')
  reports[variant]={'sourceCommit':g['sourceCommit'],'events':events,'hitOccurrences':hitsum,'candidateTriangles':candidates,'arms':{k:h.finish_arm(v) for k,v in globalarms.items()},'paths':rows,'aggregateCPUSeconds':g['aggregateCPUSeconds'],'aggregateWallSeconds':g['wallSeconds'],'peakObservedRSSBytes':g['peakObservedAggregateRSS']}
 changes=[]
 for old,new in zip(reports['baseline']['paths'],reports['simplified']['paths']):
  need(old['name']==new['name'],'cross run route');row={'name':new['name'],'arms':{}}
  for arm in ARMS:
   x=set(old['arms'][arm]['uniqueIDs']);y=set(new['arms'][arm]['uniqueIDs']);row['arms'][arm]={'sharedFaceIDs':sorted(x&y),'addedFaceIDs':sorted(y-x),'removedFaceIDs':sorted(x-y)}
  changes.append(row)
 reported=read(W/'conference-simplified-body-attempt-001/comparison/RECEIPT.json')['baselineComparison']['paths']
 for actual,saved in zip(changes,reported):
  need(actual['name']==saved['name'],'saved comparison route')
  for arm in ARMS:
   for k,v in actual['arms'][arm].items():need(saved['arms'][arm][k]==v,'saved face set mismatch')
 verify();budget();need(not any(x in sys.modules for x in ('numpy','vtk','scipy')),'native imports')
 result={'status':'SAVED_IDS_AND_FACE_CHANGES_RECOUNTED','reports':reports,'changes':changes,'nativeRerun':False,'physicalAuthority':False,'safetyImprovementEstablished':False,'contactEventPercentagesCalculated':False,'analysisCPUSeconds':time.process_time()-c,'analysisWallSeconds':time.monotonic()-t,'analysisPeakRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024}
 (out/'AUDIT.json').write_text(json.dumps(result,indent=2,allow_nan=False)+'\n');print(json.dumps({v:{k:reports[v][k] for k in ('events','hitOccurrences','candidateTriangles')}for v in reports}))
if __name__=='__main__':main()

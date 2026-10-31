"""Stdlib terminal contract; never imports native libraries."""
import json,math

def validate_results(work,source,pins_sha):
 entries=json.loads((source/'PROBES.json').read_text());expected=[]
 for scene in ('conference','coffee'):
  for envelope in ('body','horizontal_margin'):
   expected.extend((scene,envelope,e['probe']) for e in entries if e['scene']==scene)
 rows=[json.loads(s) for s in (work/'probes/probe-rows.jsonl').read_text().splitlines()]
 if len(rows)!=48 or len(expected)!=48:raise ValueError('KCC inventory')
 for x,(scene,envelope,p) in zip(rows,expected):
  r=x['row']
  if (x['scene'],x['envelope'],x['arm'],x['inputArm'],x['datumArm'],x['intentArm'],x['sourceProbeID'])!=(scene,envelope,'raw_trimesh','exact_xyz',p['datumArm'],p['intentArm'],p['sourceProbeID']):raise ValueError('KCC envelope identity')
  for k,v in [('id',p['id']),('kind',p['kind']),('originalFoot',p['foot']),('originalYawRadians',p['yawRadians']),('originalDesiredDelta',p['desiredDelta']),('independentEvidence',p['independentEvidence'])]:
   if r.get(k)!=v:raise ValueError('KCC original binding '+k)
  if not r.get('controllerCalled') or r.get('status')!='proposal_only' or r.get('proposalWasNotApplied') is not True:raise ValueError('KCC query state')
  for k in ['physicalAuthority','movementApplied','arrivalEstablished']:
   if r.get(k) is not False:raise ValueError('KCC authority')
  if r.get('support')!='unknown' or r.get('semanticFloor')!='unknown' or not r.get('queryBandDifference'):raise ValueError('KCC support/band')
  if len(r['proposedMovement'])!=3 or not all(map(math.isfinite,r['proposedMovement'])):raise ValueError('KCC nonfinite')
 summary=json.loads((work/'probes/SUMMARY.json').read_text())
 for k,v in {'scope':'six_pose_estimated_datum_diagnostic','status':'completed_diagnostic_proposals_not_movement','wrapperCount':4,'probeCount':48,'controllerCalls':48,'unsupportedTurns':0,'physicalAuthority':False,'movementApplied':False,'arrivalEstablished':False,'allSelectedRowsRetained':True,'pinsSHA256':pins_sha,'wrapperVersion':'0.21.0','wasmInitialized':True,'analyticControlsHadTwoKnownFailures':True}.items():
  if summary.get(k)!=v:raise ValueError('KCC summary '+k)
 wrappers=[json.loads(s) for s in (work/'probes/wrapper-records.jsonl').read_text().splitlines()]
 if [(x['scene'],x['envelope'],x['probeCount']) for x in wrappers]!=[('conference','body',16),('conference','horizontal_margin',16),('coffee','body',8),('coffee','horizontal_margin',8)]:raise ValueError('KCC wrappers')
 for x in wrappers:
  if x['originalTriangleOrdinalPreserved'] is not True or x['physicalAuthority'] is not False:raise ValueError('KCC mesh/authority')
 from vtk_contract import validate_vtk
 vtk=validate_vtk(work/'vtk',entries)
 return {'kccRows':48,'kccWrappers':4,'vtk':vtk,'movementApplied':False,'physicalAuthority':False}

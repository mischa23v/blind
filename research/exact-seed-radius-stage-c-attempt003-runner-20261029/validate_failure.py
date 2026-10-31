"""Attempt003 export allowlist: controlled failure metadata, no raw native payload."""
import re
PREFLIGHT={'repository-head','tracked-status-before','selected-developer-directory','xcode-version','sdk-path','resolve-clangpp','resolve-swiftc','resolve-swift-frontend','resolve-ar','resolve-ld','resolve-xcodebuild','repository-head-after','tracked-status-after'}
def require(ok,why):
 if not ok:raise ValueError(why)
def validate_failure(row,recipe,schema):
 spec=schema['failureEvidence']
 require(type(row) is dict and set(row)==set(spec['exactKeys']),'failure keys')
 require(row['phase'] in spec['phases'] and row['reasonCode'] in spec['reasonCode'],'controlled phase/reason')
 require(row['failureStage'] in spec['failureStage'],'failure stage')
 metadata=row['safeMetadata'];ms=spec['safeMetadata']
 require(type(metadata) is dict and set(metadata)==set(ms['exactKeys']),'safe metadata keys')
 require(metadata['outputScope'] in ms['outputScope'] and metadata['entryKind'] in ms['entryKind'],'safe metadata enums')
 require(metadata['errno'] is None or type(metadata['errno']) is int and 0<=metadata['errno']<=4095,'safe errno')
 secondary=row['secondaryFailureCodes'];ss=spec['secondaryFailureCodes']
 require(type(secondary) is dict and len(secondary)<=ss['maximumEntries'] and set(secondary)<=set(ss['allowedKeys']) and all(v in spec['reasonCode'] for v in secondary.values()),'secondary failure codes')
 labels=[c['label'] for c in recipe['commands']]
 require(row['commandLabel'] is None or row['commandLabel'] in set(labels)|PREFLIGHT,'command label')
 for k in ['processStarted','processCompleted','commandWasFailureSite']:require(type(row[k]) is bool,'process flag')
 for k,bound in [('guardCommandIndex',128),('recipeCommandIndex',31)]:require(row[k] is None or type(row[k]) is int and 1<=row[k]<=bound,'command index')
 require(row['returnCode'] is None or type(row['returnCode']) is int and -128<=row['returnCode']<=255,'return code')
 if row['commandLabel'] in labels:require(row['recipeCommandIndex']==labels.index(row['commandLabel'])+1,'recipe index match')
 else:require(row['recipeCommandIndex'] is None,'nonrecipe index')
 d=row['compilerDiagnostic'];require(type(d) is dict and set(d)=={'status','stderrBytes','sampleBytes','lines','truncated'},'diagnostic keys')
 require(d['status'] in {'notCompilerPhase','notStarted','pinsNotVerified','exported','emptyStderr','noAllowlistedDiagnostics','readUnavailable'},'diagnostic status')
 require(d['stderrBytes'] is None or type(d['stderrBytes']) is int and 0<=d['stderrBytes']<=134217728,'stderr size')
 require(type(d['sampleBytes']) is int and 0<=d['sampleBytes']<=65536 and type(d['truncated']) is bool,'sample bounds')
 require(type(d['lines']) is list and len(d['lines'])<=20 and all(type(s) is str and len(s)<=384 and all(32<=ord(c)<=126 for c in s) for s in d['lines']) and sum(len(s)+1 for s in d['lines'])<=4096,'diagnostic text bounds')
 if d['lines']:
  label=row['commandLabel'];require(row['phase'] in {'cxx-compile','observer-compile','swift-compile'} and label in labels and (label.startswith('compile-') or label in ['observer-tests-compile','swift-probe-compile']) and row['processStarted'] and d['status']=='exported','compiler-only diagnostics')
  prefixes=[]
  for token in recipe['sourcePins']:
   if token.endswith(('.cpp','.h','.swift')):prefixes.append(token[1:])
  for name in recipe['generatedSources']:
   if name.endswith(('.cpp','.h','.swift')):prefixes.append('build/'+name)
  for line in d['lines']:
   require(re.match(r'^compiler: (?:fatal error|error|warning): ',line) is not None or any(re.match(re.escape(p)+r':\d+(?::\d+)?: (?:fatal error|error|warning): ',line) for p in prefixes),'public compiler diagnostic provenance')
   require(not re.search(r'(?:^|\s)[A-Za-z_][A-Za-z0-9_]*=',line),'environment assignment excluded')
 else:require(d['status']!='exported','nonempty exported diagnostics')

def validate_matrix(row,requests,masks):
 counts={'retainedSixNoContactCorridors':('retain-six-no-contact',6),'completeNoContactCorners':('seek-two-clear-corners',2),'retainedThreeTypedRefusals':('retain-three-typed-endpoint-refusals',3),'preservedOtherFourteenFailures':('preserve-fourteen-original-failures',14)}
 flags={'all50OriginalControlsReproduced','candidateExecuted','candidateGoalsMet','allCandidateInitialContactsUnchanged','allCandidateLayoutsMatched'}
 require(type(row) is dict and set(row)=={'status','candidateRequests','legacyControlsMatched','strictControlsMatched','legacy49aControlsMatched','controlChecks','candidateAcceptanceChecks'}|set(counts)|flags,'matrix keys')
 statuses={'original-controls-mismatch-candidate-not-executed','fixed-public-fixture-seed-radius-candidate-met-declared-goals','fixed-public-fixture-seed-radius-candidate-failed-declared-goals'}
 require(row['status'] in statuses and all(type(row[k]) is bool for k in flags),'matrix flags/status')
 require(type(row['candidateRequests']) is int and row['candidateRequests'] in (0,25),'matrix candidate count')
 ids=[r['id'] for r in requests['requests']];controls=row['controlChecks'];acceptance=row['candidateAcceptanceChecks'];require(type(controls) is list and len(controls)==25 and [x['requestID'] for x in controls]==ids,'matrix controls')
 for x in controls:require(set(x)=={'requestID','legacyMatch','strictMatch'} and type(x['legacyMatch']) is bool and type(x['strictMatch']) is bool,'control record')
 for k in ['legacyControlsMatched','strictControlsMatched','legacy49aControlsMatched']:require(type(row[k]) is int and 0<=row[k]<=25,'control count')
 require(row['legacyControlsMatched']==sum(x['legacyMatch'] for x in controls) and row['strictControlsMatched']==sum(x['strictMatch'] for x in controls),'control recount')
 controls_ok=row['legacyControlsMatched']==row['strictControlsMatched']==row['legacy49aControlsMatched']==25
 require(row['all50OriginalControlsReproduced']==controls_ok and row['candidateExecuted']==controls_ok and row['candidateRequests']==(25 if controls_ok else 0),'execution gate')
 require(type(acceptance) is list and len(acceptance)==row['candidateRequests'] and [x['requestID'] for x in acceptance]==ids[:len(acceptance)],'acceptance inventory')
 groupmap={}
 for key,name in [('retainSixNoContactCorridors','retain-six-no-contact'),('seekTwoCompleteNoContactCorners','seek-two-clear-corners'),('retainThreeTypedEndpointRefusals','retain-three-typed-endpoint-refusals'),('otherPreviouslyFailedRequests','preserve-fourteen-original-failures')]:
  for id in masks['fixedAcceptanceIDs'][key]:require(id not in groupmap,'unique group');groupmap[id]=name
 require(set(groupmap)==set(ids),'group partition')
 for x in acceptance:require(set(x)=={'requestID','group','criterionPassed','initialSourceContactUnchanged','fullLayoutValidated'} and x['group']==groupmap[x['requestID']] and all(type(x[k]) is bool for k in ['criterionPassed','initialSourceContactUnchanged','fullLayoutValidated']),'acceptance row')
 for k,(group,maximum) in counts.items():require(type(row[k]) is int and 0<=row[k]<=maximum and row[k]==sum(x['group']==group and x['criterionPassed'] for x in acceptance),'criterion count')
 require(row['allCandidateInitialContactsUnchanged']==(len(acceptance)==25 and all(x['initialSourceContactUnchanged'] for x in acceptance)) and row['allCandidateLayoutsMatched']==(len(acceptance)==25 and all(x['fullLayoutValidated'] for x in acceptance)),'candidate flags')
 goals=controls_ok and len(acceptance)==25 and row['allCandidateInitialContactsUnchanged'] and row['allCandidateLayoutsMatched'] and all(row[k]==v[1] for k,v in counts.items());require(row['candidateGoalsMet']==goals,'candidate goals')
 expected='original-controls-mismatch-candidate-not-executed' if not controls_ok else 'fixed-public-fixture-seed-radius-candidate-met-declared-goals' if goals else 'fixed-public-fixture-seed-radius-candidate-failed-declared-goals';require(row['status']==expected,'matrix status')

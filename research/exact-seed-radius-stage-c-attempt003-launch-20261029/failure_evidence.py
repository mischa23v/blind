"""Controlled failure evidence only; never exports native matrix stderr or arrays."""
import pathlib,re
from mac_guard import GuardFailure,controlled_reason
from public_aggregate import f32,points_digest,POINT_DOMAIN

PHASES={'preflight','cxx-compile','archive','observer-compile','observer-test','swift-compile','route-matrix','matrix-validation','postcheck','terminal-export'}
PREFLIGHT_LABELS={'repository-head','tracked-status-before','selected-developer-directory','xcode-version','sdk-path',
 'resolve-clangpp','resolve-swiftc','resolve-swift-frontend','resolve-ar','resolve-ld','resolve-xcodebuild',
 'repository-head-after','tracked-status-after'}
MATRIX_STATUSES={'original-controls-mismatch-candidate-not-executed',
 'fixed-public-fixture-seed-radius-candidate-met-declared-goals',
 'fixed-public-fixture-seed-radius-candidate-failed-declared-goals'}
CONFIGURATIONS=['original-erosion-legacy-endpoints','original-erosion-strict-endpoints','stock-AND-exact-seed-radius-veto-strict-endpoints']
INPUT_HASHES={'geometrySHA256':'0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7',
 'requestsSHA256':'e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51',
 'maskInputsSHA256':'13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a',
 'nativeReferenceSHA256':'0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893'}
GROUPS={'retainSixNoContactCorridors':('retain-six-no-contact','retainedSixNoContactCorridors',6),
 'seekTwoCompleteNoContactCorners':('seek-two-clear-corners','completeNoContactCorners',2),
 'retainThreeTypedEndpointRefusals':('retain-three-typed-endpoint-refusals','retainedThreeTypedRefusals',3),
 'otherPreviouslyFailedRequests':('preserve-fourteen-original-failures','preservedOtherFourteenFailures',14)}

def require(value,label):
    if not value:raise GuardFailure('matrix observation: '+label)

def matrix_observation(data,requests,masks):
    """Validate identity/structure and export failures without requiring goals true."""
    require(data['schema']=='blind.public-fixed-seed-radius-navigation.v1' and data['status'] in MATRIX_STATUSES,'schema/status')
    require(data['configurationOrder']==CONFIGURATIONS,'configuration order')
    for key,wanted in INPUT_HASHES.items():require(data[key]==wanted,'input digest')
    for key in ['physicalAuthority','appActivation','fullFootprintSupportVerified','continuousSourceClearanceGuarantee','centerClearanceObjectiveImplemented','iOSValidated']:
        require(data[key] is False,'authority')
    flags=['all50OriginalControlsReproduced','candidateExecuted','candidateGoalsMet','allCandidateInitialContactsUnchanged','allCandidateLayoutsMatched']
    for key in flags:require(type(data[key]) is bool,'flag type')
    require(type(data['candidateRequests']) is int and data['candidateRequests'] in (0,25),'candidate count')
    for key,count in [('legacyControls',25),('strictControls',25),('preservedUnrunJourneyStages',9)]:
        require(type(data[key]) is int and data[key]==count,'fixed count')
    count=data['candidateRequests'];rows=data['rows'];fixed=requests['requests'];ids=[r['id'] for r in fixed]
    require(len(fixed)==25 and len(set(ids))==25 and type(rows) is list and len(rows)==50+count,'row inventory')
    for block,start in enumerate(range(0,len(rows),25)):
        for row,request in zip(rows[start:start+25],fixed):
            require(row['requestID']==request['id'] and row['fixtureSHA256']==request['fixtureSHA256'] and row['profile']==request['profile'],'row input identity')
            require(row['configuration']==CONFIGURATIONS[block] and row['endpointPolicy']==('legacyNearestProjection' if block==0 else 'requireSuppliedXZOverPolygon'),'row policy')
            require(row['physicalAuthority'] is False and type(row['fullLayoutValidated']) is bool and type(row['baselineMatches49a']) is bool,'row flags')
            for key in ['rawRadius','effectiveRadius','effectiveHeight']:require(f32(row[key])[1]==f32(request[key])[1],'row body')
            for key in ['requestedStart','requestedGoal']:
                require(points_digest([row[key]],POINT_DOMAIN)==points_digest([request[key]],POINT_DOMAIN),'row supplied endpoint')
    controls=data['controlChecks'];acceptance=data['candidateAcceptanceChecks']
    require(type(controls) is list and len(controls)==25 and [x['requestID'] for x in controls]==ids,'control identities')
    for x in controls:
        require(set(x)=={'requestID','legacyMatch','strictMatch'} and type(x['legacyMatch']) is bool and type(x['strictMatch']) is bool,'control flags')
    controls_ok=all(x['legacyMatch'] and x['strictMatch'] for x in controls) and all(x['baselineMatches49a'] for x in rows[:25])
    require(data['all50OriginalControlsReproduced']==controls_ok and data['candidateExecuted']==controls_ok and count==(25 if controls_ok else 0),'execution gate consistency')
    expected_groups={}
    for key,(name,counter,expected_count) in GROUPS.items():
        members=masks['fixedAcceptanceIDs'][key];require(len(members)==expected_count,'fixed acceptance inventory')
        for id in members:require(id not in expected_groups,'overlapping acceptance groups');expected_groups[id]=name
    require(set(expected_groups)==set(ids),'acceptance identity partition')
    require(type(acceptance) is list and len(acceptance)==count and [x['requestID'] for x in acceptance]==ids[:count],'acceptance identities')
    for x in acceptance:
        require(set(x)=={'requestID','group','criterionPassed','initialSourceContactUnchanged','fullLayoutValidated'} and x['group']==expected_groups[x['requestID']],'acceptance group')
        for key in ['criterionPassed','initialSourceContactUnchanged','fullLayoutValidated']:require(type(x[key]) is bool,'acceptance flag')
    counters={}
    for key,(name,counter,maximum) in GROUPS.items():
        value=data[counter]
        require(type(value) is int and 0<=value<=maximum and value==sum(x['group']==name and x['criterionPassed'] for x in acceptance),'acceptance counter consistency')
        counters[counter]=value
    require(data['allCandidateInitialContactsUnchanged']==(count==25 and all(x['initialSourceContactUnchanged'] for x in acceptance)),'initial-contact flag')
    require(data['allCandidateLayoutsMatched']==(count==25 and all(x['fullLayoutValidated'] for x in acceptance)),'layout flag')
    goals=controls_ok and count==25 and data['allCandidateInitialContactsUnchanged'] and data['allCandidateLayoutsMatched'] and all(counters[counter]==maximum for _,counter,maximum in GROUPS.values())
    require(data['candidateGoalsMet']==goals,'goal consistency')
    expected_status=('original-controls-mismatch-candidate-not-executed' if not controls_ok else
      'fixed-public-fixture-seed-radius-candidate-met-declared-goals' if goals else
      'fixed-public-fixture-seed-radius-candidate-failed-declared-goals')
    require(data['status']==expected_status,'status consistency')
    return {'status':data['status'],'candidateRequests':count,**{k:data[k] for k in flags},**counters,
      'legacyControlsMatched':sum(x['legacyMatch'] for x in controls),'strictControlsMatched':sum(x['strictMatch'] for x in controls),
      'legacy49aControlsMatched':sum(x['baselineMatches49a'] for x in rows[:25]),
      'controlChecks':controls,'candidateAcceptanceChecks':acceptance}

def compiler_diagnostic_excerpt(raw,allowed_paths):
    """At most 64 KiB input, 20 diagnostic lines / 4 KiB ASCII output; no snippets."""
    lines=[];used=0;truncated=len(raw)>65536
    for line in raw[:65536].decode('utf-8',errors='replace').splitlines():
        source=re.fullmatch(r'(.+?):(\d+):(?:(\d+):)?\s*(fatal error|error|warning):\s*(.*)',line)
        if source and source[1] in allowed_paths:
            prefix=allowed_paths[source[1]]+':'+source[2]+(':'+source[3] if source[3] else '')+': '+source[4]+': '
            message=source[5]
        else:
            tool=re.fullmatch(r'(?:(?:clang(?:\+\+)?|swiftc|swift-frontend): )?(fatal error|error|warning):\s*(.*)',line)
            if not tool:continue
            prefix='compiler: '+tool[1]+': ';message=tool[2]
        # Never export source-context/caret/stack/env/command-dump lines. Only
        # reviewed compiler diagnostic records from verified public sources.
        if re.search(r'(?:^|\s)[A-Za-z_][A-Za-z0-9_]*=',message):continue
        message=re.sub(r'/(?:[^\s\"\'<>:])+','[path]',message)
        message=re.sub(r'\[[0-9eE.,+\s-]+\]','[numeric-array-withheld]',message)
        text=(prefix+message).encode('ascii',errors='replace').decode('ascii')
        text=''.join(x for x in text if 32<=ord(x)<=126)[:384]
        if len(lines)>=20 or used+len(text)+1>4096:truncated=True;break
        lines.append(text);used+=len(text)+1
    return lines,truncated

def failure_evidence(record,guard,recipe,roots,output):
    labels=[c['label'] for c in recipe['commands']] if recipe else []
    first=record.get('firstFailure') or (getattr(guard,'firstFailure',None) if guard is not None else None)
    rows=guard.records if guard is not None else []
    last=next((r for r in rows if first and r['index']==first['guardCommandIndex']),None) if first else (rows[-1] if rows else None)
    label=last['label'] if last and last['label'] in set(labels)|PREFLIGHT_LABELS else None
    index=labels.index(label)+1 if label in labels else None
    phase=record.get('firstFailurePhase',record.get('phase','preflight'));phase=phase if phase in PHASES else 'preflight'
    reason=first['reasonCode'] if first else record.get('controlledReasonCode','VALIDATION_REFUSED')
    row={'phase':phase,'guardCommandIndex':last['index'] if last else None,'recipeCommandIndex':index,
      'commandLabel':label,'processStarted':last['processStarted'] if last else False,
      'processCompleted':last['processCompleted'] if last else False,'returnCode':last['exitCode'] if last else None,
      'commandWasFailureSite':bool(last and last.get('reasonCode')),'reasonCode':reason,
      'compilerDiagnostic':{'status':'notCompilerPhase','stderrBytes':None,'sampleBytes':0,'lines':[],'truncated':False}}
    row['failureStage']=first['stage'] if first else 'launcher'
    row['safeMetadata']=first['metadata'] if first else {'outputScope':None,'entryKind':None,'errno':None}
    secondary={k:v['reasonCode'] for k,v in getattr(guard,'secondaryFailures',{}).items()} if guard is not None else {}
    secondary.update(record.get('secondaryFailureCodes',{}));row['secondaryFailureCodes']=secondary
    compiler=phase in {'cxx-compile','observer-compile','swift-compile'} and label in labels and (label.startswith('compile-') or label in ['observer-tests-compile','swift-probe-compile'])
    diag=row['compilerDiagnostic']
    if not compiler:return row
    if not row['processStarted']:diag['status']='notStarted';return row
    if not all(record.get(x) is True for x in ['sourcePinsBefore','sourcePinsAfter','toolPinsBefore','toolPinsAfter','generatedBuildPinsBefore','generatedBuildPinsAfter']):
        diag['status']='pinsNotVerified';return row
    allowed={}
    for token,pin in recipe['sourcePins'].items():
        prefix,relative=token.split('/',1)
        if pathlib.PurePosixPath(relative).suffix in ['.cpp','.h','.swift']:
            allowed[str(roots[prefix]/relative)]=prefix[1:]+'/'+relative
    for relative in recipe['generatedSources']:
        if pathlib.PurePosixPath(relative).suffix in ['.cpp','.h','.swift']:allowed[str(output/relative)]='build/'+relative
    path=output/(label+'.stderr.private.txt')
    try:
        diag['stderrBytes']=path.stat().st_size
        with path.open('rb') as stream:raw=stream.read(65536)
        lines,truncated=compiler_diagnostic_excerpt(raw,allowed)
        diag.update(status='exported' if lines else 'emptyStderr' if not raw else 'noAllowlistedDiagnostics',
                    sampleBytes=len(raw),lines=lines,truncated=truncated or diag['stderrBytes']>len(raw))
    except (OSError,ValueError):diag['status']='readUnavailable'
    return row

#!/usr/bin/env python3
"""Root-admitted Apple Stage C only. Never invokes Stage B, installs or uploads."""
import argparse,hashlib,json,os,pathlib,platform,shutil,signal,sys
sys.dont_write_bytecode=True
from mac_guard import Guard,GuardFailure,output_bytes,safe_command_label,controlled_reason,failure_event,remember_failure
from public_aggregate import load_json,candidate_receipts
from failure_evidence import failure_evidence,matrix_observation
HERE=pathlib.Path(__file__).resolve().parent
SOURCE_MANIFEST='b78b97365d458bcacdd7db19cf221a5bfd22ad7e3f712c55ed59061fd3e0a165'
SOURCE_REVIEW='72fb69bbce0f96f8131af3d085990f079334321d7448d17029a4c05ed8772fda' # Must be finalized from independent review before admission.
CAPS={'CPUSeconds':120,'wallSeconds':300,'observedRSSBytes':2147483648,'observedOutputBytes':134217728}
INPUT_HASHES={'geometrySHA256':'0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7',
 'requestsSHA256':'e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51',
 'maskInputsSHA256':'13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a',
 'nativeReferenceSHA256':'0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893'}
CONFIGURATIONS=['original-erosion-legacy-endpoints','original-erosion-strict-endpoints','stock-AND-exact-seed-radius-envelope-v2-strict-endpoints']

def require(value,reason):
    if not value:raise GuardFailure(reason)

def digest(path,guard=None):
    value=hashlib.sha256();total=0
    with pathlib.Path(path).open('rb') as f:
        while True:
            data=f.read(1048576)
            if not data:break
            value.update(data);total+=len(data)
            if guard is not None and total%16777216==0:guard.monitor()
    return value.hexdigest()

def under(root,relative):
    rel=pathlib.PurePosixPath(relative)
    require(not rel.is_absolute() and '..' not in rel.parts and relative,'invalid relative input path')
    p=(root/relative).resolve(strict=True)
    require(root in p.parents,'input path escapes declared root')
    return p

def verify_manifest(root,manifest,guard=None):
    for name,pin in manifest['files'].items():
        p=under(root,name)
        require(p.is_file() and p.stat().st_size==pin['bytes'] and digest(p,guard)==pin['sha256'],'manifest pin mismatch')

def verify_source_packet(source,original,material,guard=None):
    require(digest(source/'CANDIDATE_MANIFEST.json',guard)==SOURCE_MANIFEST,'original source manifest changed')
    require(material['sourceManifestSHA256']==SOURCE_MANIFEST,'materialization source binding')
    for name,pin in material['files'].items():require(original['files'].get(name)==pin,'materialized pin not original')
    omitted=material['omittedAuditOrStageBFiles']
    require(set(omitted)==set(original['files'])-set(material['files']),'omission inventory mismatch')
    for name,pin in omitted.items():require(original['files'][name]==pin,'omitted audit pin changed')
    verify_manifest(source,material,guard)
    recipe=json.loads((source/'prepared-stage-c-final/BUILD_RECIPE.json').read_text())
    required={'SOURCE_CHECKS.json','prepared-stage-c-final/BUILD_RECIPE.json'}
    required.update(x[len('@packet/'):] for x in recipe['sourcePins'] if x.startswith('@packet/'))
    required.update('prepared-stage-c-final/'+x for x in recipe['generatedSources'])
    require(set(material['files'])==required,'materialization is not exact runtime closure')
    return recipe

def validate_recipe_labels(recipe):
    labels=[x['label'] for x in recipe['commands']]
    require(len(labels)==31 and all(safe_command_label(x) for x in labels),'invalid native recipe labels')
    require(len({x.casefold() for x in labels})==len(labels),'casefold duplicate recipe label')
    return labels

def resolve_argument(value,roots):
    for token,root in roots.items():
        if value==token:return str(root)
        if value.startswith(token+'/'):
            relative=pathlib.PurePosixPath(value[len(token)+1:])
            require(not relative.is_absolute() and '..' not in relative.parts,'command path escape')
            return str(root/str(relative))
    require('@' not in value,'unresolved command root')
    return '/usr/bin/xcrun' if value=='xcrun' else value

def resolved_native_command(argv,resolved):
    if argv[0]=='/usr/bin/xcrun':
        require(argv[1] in ['clang++','ar','swiftc'],'unreviewed native tool')
        return [resolved[argv[1]]]+argv[2:]
    return argv

def verify_generated_sources(root,recipe,guard=None):
    for name,pin in recipe['generatedSources'].items():
        copied=under(root,name)
        require(copied.stat().st_size==pin['bytes'] and digest(copied,guard)==pin['sha256'],'copied build input changed')

def verify_tool_selections(selections):
    for entry in selections.values():
        require(str(pathlib.Path(entry['invocationPath']).resolve(strict=True))==entry['resolvedPath'],'selected tool alias changed')

def validate_observer(text,names):
    lines=text.strip().splitlines()
    require(len(lines)==22 and lines[:21]==['PASS observer/'+x for x in names],'observer fixture identities mismatch')
    row=json.loads(lines[-1]);require(set(row)=={'schema','scope','groups','checks','passed','physicalAuthority'},'observer summary fields')
    require(row['schema']==1 and row['scope']=='read-only-seed-observer' and row['groups']==21 and
            type(row['checks']) is int and row['checks']>0 and row['passed']==row['checks'] and
            row['physicalAuthority'] is False,'observer fixture aggregate failed')
    return row

def validate_result(data,requests):
    require(data['schema']=='blind.public-fixed-seed-radius-envelope-navigation.v2','result schema')
    require(data['status']=='fixed-public-fixture-seed-radius-envelope-candidate-met-declared-goals','result success status')
    require(data['configurationOrder']==CONFIGURATIONS,'result configuration order')
    for key,value in INPUT_HASHES.items():require(data[key]==value,'result input digest '+key)
    for key in ['physicalAuthority','appActivation','fullFootprintSupportVerified','continuousSourceClearanceGuarantee','centerClearanceObjectiveImplemented','iOSValidated']:
        require(data[key] is False,'unexpected authority')
    for key in ['all50OriginalControlsReproduced','candidateExecuted','candidateGoalsMet','allCandidateInitialContactsUnchanged','allCandidateLayoutsMatched']:
        require(data[key] is True,'route acceptance false: '+key)
    for key,count in {'legacyControls':25,'strictControls':25,'candidateRequests':25,'retainedSixNoContactCorridors':6,'completeNoContactCorners':2,'retainedThreeTypedRefusals':3,'preservedOtherFourteenFailures':14,'preservedUnrunJourneyStages':9}.items():
        require(type(data[key]) is int and data[key]==count,'route count: '+key)
    ids=[r['id'] for r in requests['requests']]
    require(len(ids)==25 and len(set(ids))==25 and len(data['rows'])==75,'request inventory')
    for block,start in enumerate([0,25,50]):
        selected=data['rows'][start:start+25]
        require([r['requestID'] for r in selected]==ids,'row identity/order changed')
        policy='legacyNearestProjection' if block==0 else 'requireSuppliedXZOverPolygon'
        require(all(r['configuration']==CONFIGURATIONS[block] and r['endpointPolicy']==policy for r in selected),'row configuration/endpoint policy changed')
    controls=data['controlChecks'];acceptance=data['candidateAcceptanceChecks']
    require(len(controls)==25 and [x['requestID'] for x in controls]==ids and
            all(x['legacyMatch'] is True and x['strictMatch'] is True for x in controls),'control record mismatch')
    require(len(acceptance)==25 and [x['requestID'] for x in acceptance]==ids and
            all(x['criterionPassed'] is True and x['initialSourceContactUnchanged'] is True and x['fullLayoutValidated'] is True for x in acceptance),'candidate acceptance record mismatch')
    for name,count in {'retain-six-no-contact':6,'seek-two-clear-corners':2,'retain-three-typed-endpoint-refusals':3,'preserve-fourteen-original-failures':14}.items():
        require(sum(x['group']==name for x in acceptance)==count,'candidate group identity/count')
    require(all(r['fullLayoutValidated'] is True for r in data['rows']),'row layout mismatch')
    return {k:data[k] for k in ['all50OriginalControlsReproduced','candidateRequests','candidateGoalsMet','retainedSixNoContactCorridors','completeNoContactCorners','retainedThreeTypedRefusals','preservedOtherFourteenFailures','allCandidateInitialContactsUnchanged','allCandidateLayoutsMatched']}

def validated_envelope_receipts(data,requests):
    keys={'requested','schema','algorithm','workUnit','status','width','height','spanCount','radiusCells','commonYVoxel',
          'realSeedCount','exteriorSeedCount','stockKeep','exactKeep','additionalRejected','buildSucceeded',
          'workLimit','workBound','workPerformed','paddedCells','workspaceBytesDeclared','physicalAuthority'}
    bools={'requested','buildSucceeded','physicalAuthority'}
    selected=data['rows'][50:];ids=[r['id'] for r in requests['requests']]
    require(len(selected)==25 and len(ids)==25,'complete envelope receipt inventory')
    output=[]
    for row,expectedID in zip(selected,ids):
        require(type(row['requestID']) is str and row['requestID']==expectedID,'envelope request identity')
        r=row['envelopeRadiusReceipt']
        require(type(r) is dict and set(r)==keys,'envelope exact scalar keys')
        require(all(type(r[k]) is bool for k in bools) and all(type(r[k]) is int for k in keys-bools),'envelope scalar types')
        require(r['requested'] is True and r['physicalAuthority'] is False and
                r['schema']==2 and r['algorithm']==1 and r['workUnit']==1 and r['status']==2,'envelope discriminators')
        w,h,n=r['width'],r['height'],r['spanCount'];padded=(w+2)*(h+2)
        require(1<=w<=250000 and 1<=h<=250000 and 1<=n<=min(w*h,65536) and
                1<=r['radiusCells']<=80 and 0<=r['commonYVoxel']<=65535,'envelope domain ranges')
        require(r['paddedCells']==padded and padded<=250000 and r['realSeedCount']>=0 and r['realSeedCount']<=n and
                r['exteriorSeedCount']==2*(w+h+2),'envelope seed/domain identity')
        require(0<=r['exactKeep']<=r['stockKeep']<=n and r['additionalRejected']==r['stockKeep']-r['exactKeep'],'envelope keep counts')
        require(r['workLimit']==10000000 and r['workBound']==14*padded and
                0<=r['workPerformed']<=r['workBound']<=r['workLimit'],'envelope work units/bounds')
        require(r['workspaceBytesDeclared']==11*padded+16*(max(w,h)+2)+n+448 and
                r['workspaceBytesDeclared']<=2*1024*1024,'envelope declared workspace')
        output.append({'requestID':expectedID,**{k:r[k] for k in sorted(keys)}})
    return output

def encode_public_aggregate(value):
    encoded=(json.dumps(value,indent=2,sort_keys=True,allow_nan=False)+'\n').encode('utf-8')
    require(len(encoded)<=131072,'public aggregate encoded-byte cap')
    return encoded

def retain_first_failure(record,guard,error,phase,secondary=None):
    if guard is not None:remember_failure(guard,error,secondary or 'launcher',secondary=secondary is not None)
    event=getattr(guard,'firstFailure',None) if guard is not None else None
    event=event or failure_event(error,secondary or 'launcher')
    if 'firstFailure' not in record:
        record['firstFailure']=event;record['firstFailurePhase']=phase
    record['controlledReasonCode']=record['firstFailure']['reasonCode']
    if secondary:record.setdefault('secondaryFailureCodes',{}).setdefault(secondary,controlled_reason(error))
    record['status']='failed-or-inconclusive'

def finalize_public_aggregate(output,aggregate,guard,record,save,failure_builder=None):
    try:return _finalize_public_aggregate(output,aggregate,guard,record,save,failure_builder)
    except BaseException as error:
        # Never rescan an output tree which just refused accounting. Preserve the
        # first cause and last completed sample, explicitly not terminal/compliant.
        retain_first_failure(record,guard,error,'terminal-export',secondary='terminal-export')
        aggregate['status']='failed-or-inconclusive';aggregate.pop('resources',None)
        if guard is not None and getattr(guard,'lastValidSample',None) is not None:
            aggregate['lastValidResourceSample']=guard.lastValidSample.copy()
        try:save()
        except BaseException as cleanup:retain_first_failure(record,guard,cleanup,'terminal-export',secondary='receipt-save')
        if failure_builder is not None:aggregate['failureEvidence']=failure_builder()
        encoded=encode_public_aggregate(aggregate)
        target=output/'AGGREGATE.review-required.json'
        # Best effort: inability to write even this failure receipt remains a
        # nonzero launcher; never turn absence of evidence into a pass.
        temporary=output/'AGGREGATE.failed.tmp';temporary.write_bytes(encoded);temporary.replace(target)
        return encoded,error

def _finalize_public_aggregate(output,aggregate,guard,record,save,failure_builder=None):
    """Observe after initial export write, then bounded metadata-only refresh.

    No native command or monitor runs after the declared terminal snapshot. The
    exact final owned-output byte count includes the final export itself. This
    avoids silently reporting an earlier pre-finish sample as final resources.
    """
    target=output/'AGGREGATE.review-required.json';terminal_error=None
    provisional=dict(aggregate);provisional['status']='failed-or-inconclusive'
    if failure_builder is not None:provisional['failureEvidence']=failure_builder()
    target.write_bytes(encode_public_aggregate(provisional))
    if guard is None:return encode_public_aggregate(aggregate),None
    completed=False
    try:guard.finish();completed=True
    except BaseException as error:
        terminal_error=error;retain_first_failure(record,guard,error,'terminal-export',secondary='terminal-export')
        record['phase']='terminal-export'
        record['terminalFinalizationFailure']=type(error).__name__+': '+str(error)[:300]
        guard.failure=record['terminalFinalizationFailure'];guard.save();save()
    wall=time_elapsed(guard)
    resources={'wallSeconds':wall,'observedAggregateCPUSeconds':guard.maximumCPU,
      'observedPeakRSSBytes':guard.maximumRSS,'observedPeakOutputBytes':guard.maximumOutput,
      'finalOwnedOutputBytes':0,'terminalObservationCompleted':completed,
      'measurementBoundary':'terminal-guard-observation-before-bounded-metadata-export-refresh',
      'limitBreached':{'cpu':guard.maximumCPU>CAPS['CPUSeconds'],'wall':wall>CAPS['wallSeconds'],
        'rss':guard.maximumRSS>CAPS['observedRSSBytes'],'output':guard.maximumOutput>CAPS['observedOutputBytes']},
      'exportReserveUnavailable':False}
    # Conservative headroom for the final <=128 KiB metadata refresh; never
    # extend a cap to finish an export. CPU/RSS values remain explicitly sampled.
    if record['status']=='passed-fixed-source-route-matrix' and (
       guard.maximumCPU>119 or wall>299 or guard.maximumRSS>CAPS['observedRSSBytes']-2097152 or
       guard.maximumOutput>CAPS['observedOutputBytes']-262144):
        resources['exportReserveUnavailable']=True;record['status']='failed-or-inconclusive'
        terminal_error=GuardFailure('terminal export reserve unavailable')
        record['phase']='terminal-export';retain_first_failure(record,guard,terminal_error,'terminal-export',secondary='terminal-export');save()
    aggregate['resources']=resources;aggregate['status']=record['status']
    if not completed and getattr(guard,'lastValidSample',None) is not None:
        aggregate['lastValidResourceSample']=guard.lastValidSample.copy()
    if aggregate['status']=='failed-or-inconclusive' and failure_builder is not None:aggregate['failureEvidence']=failure_builder()
    for _ in range(10):
        other=output_bytes(output)-target.stat().st_size
        encoded=encode_public_aggregate(aggregate);total=other+len(encoded)
        peak=max(guard.maximumOutput,total)
        stable=resources['finalOwnedOutputBytes']==total and resources['observedPeakOutputBytes']==peak
        resources['finalOwnedOutputBytes']=total;resources['observedPeakOutputBytes']=peak
        resources['limitBreached']['output']=peak>CAPS['observedOutputBytes']
        if resources['limitBreached']['output'] and record['status']=='passed-fixed-source-route-matrix':
            record['status']='failed-or-inconclusive';aggregate['status']=record['status']
            terminal_error=GuardFailure('terminal aggregate output cap')
            record['phase']='terminal-export';retain_first_failure(record,guard,terminal_error,'terminal-export',secondary='terminal-export')
            if failure_builder is not None:aggregate['failureEvidence']=failure_builder()
            save();stable=False
        if stable:break
    else:raise GuardFailure('terminal aggregate size did not stabilize')
    encoded=encode_public_aggregate(aggregate);target.write_bytes(encoded)
    require(output_bytes(output)==resources['finalOwnedOutputBytes'],'owned output changed during terminal export')
    return encoded,terminal_error

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for key in ['repository','source-packet','admission','output']:parser.add_argument('--'+key,type=pathlib.Path,required=True)
    args=parser.parse_args()
    require(sys.platform=='darwin' and platform.machine()=='arm64','installed Apple arm64 host required')
    require(os.environ.get('GITHUB_REPOSITORY')=='mischa23v/blind','wrong repository environment')
    require(os.environ.get('GITHUB_REF') in ['refs/heads/master','refs/heads/codex/recovery-hazard-order-20261027'],'wrong branch environment')
    repo=args.repository.resolve(strict=True);source=args.source_packet.resolve(strict=True)
    admission=json.loads(args.admission.read_text());launch_manifest=json.loads((HERE/'LAUNCH_MANIFEST.json').read_text())
    require(admission['schema']==1 and admission['stage']=='C' and admission['singleAttempt'] is True,'wrong admission scope')
    require(admission['attemptID']=='envelope001','wrong attempt admission')
    require(SOURCE_REVIEW!='0'*64,'independent envelope source review not finalized')
    require(admission['sourceManifestSHA256']==SOURCE_MANIFEST and admission['sourceReviewSHA256']==SOURCE_REVIEW,'wrong source admission')
    require(admission['launchManifestSHA256']==digest(HERE/'LAUNCH_MANIFEST.json'),'wrong launch admission')
    require(admission['limits']==CAPS and admission['freePublicAppleRunner'] is True,'wrong resource/runner admission')
    require(admission['toolPinPolicy']=='validate-installed-Xcode-27.0-freeze-executable-hashes-before-compile-and-check-after','tool pin policy not admitted')
    require(admission['acknowledgesObservedPollingLimits'] is True,'observational resource limitations not admitted')
    require(admission['repositoryCommit']==os.environ.get('GITHUB_SHA'),'admitted repository commit mismatch')
    output=args.output.resolve();temp=pathlib.Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    require(output.parent==temp and output.name=='blind-exact-seed-radius-envelope-stage-c-attempt001' and not output.exists(),'fresh single-attempt003 output required')
    output.mkdir();guard=None;record={'schema':1,'status':'started','sourceManifestSHA256':SOURCE_MANIFEST,
      'sourceReviewSHA256':SOURCE_REVIEW,'physicalAuthority':False,'appActivation':False,'nativeCompileStarted':False,
      'sourcePinsBefore':False,'sourcePinsAfter':False,'toolPinsBefore':False,'toolPinsAfter':False,'nativeCommandsCompleted':0,'phase':'preflight','attemptID':'envelope001'}
    tools={};resolved_tools={};tool_selections={};result=None;recipe=None;roots={}
    def save():
        (output/'LAUNCH_RECEIPT.private.json').write_text(json.dumps(record,indent=2)+'\n')
    try:
        guard=Guard(output,repo);guard.monitor();verify_manifest(HERE,launch_manifest,guard)
        require(digest(source/'CANDIDATE_MANIFEST.json')==SOURCE_MANIFEST,'source manifest changed')
        source_manifest=json.loads((source/'CANDIDATE_MANIFEST.json').read_text())
        material=json.loads((HERE/'MATERIALIZATION_MANIFEST.json').read_text())
        recipe=verify_source_packet(source,source_manifest,material,guard)
        validate_recipe_labels(recipe)
        roots={'@repository':repo,'@packet':source,'@build':output}
        def source_pins():
            for token,pin in recipe['sourcePins'].items():
                prefix,name=token.split('/',1);p=under(roots[prefix],name)
                require(p.stat().st_size==pin['bytes'] and digest(p,guard)==pin['sha256'],'runtime source/input mismatch')
        source_pins();record['sourcePinsBefore']=True
        transfer=json.loads((HERE/'INPUT_TRANSFER_SCOPE.json').read_text())
        for item in transfer['provenanceAndLicensePins']:
            require(digest(under(repo,item['path']),guard)==item['sha256'],'provenance/license pin mismatch')
        head=guard.run(['/usr/bin/git','rev-parse','HEAD'],'repository-head').strip()
        require(head==admission['repositoryCommit'],'checkout head mismatch')
        require(not guard.run(['/usr/bin/git','status','--porcelain','--untracked-files=no'],'tracked-status-before').strip(),'dirty tracked checkout')
        selected=os.environ.get('DEVELOPER_DIR') or guard.run(['/usr/bin/xcode-select','-p'],'selected-developer-directory').strip()
        developer=pathlib.Path(selected).resolve(strict=True)
        require(str(developer).startswith('/Applications/') and developer.is_dir() and str(developer).endswith('/Contents/Developer'),'unexpected selected developer directory')
        guard.environment['DEVELOPER_DIR']=str(developer);record['selectedDeveloperDirectory']=str(developer)
        version=guard.run(['/usr/bin/xcodebuild','-version'],'xcode-version').strip();record['xcodeVersion']=version
        require(version.splitlines()[0]=='Xcode 27.0','wrong installed Xcode')
        sdk=pathlib.Path(guard.run(['/usr/bin/xcrun','--sdk','macosx','--show-sdk-path'],'sdk-path').strip()).resolve(strict=True)
        require(str(sdk).startswith('/Applications/') and sdk.is_dir(),'unexpected SDK root')
        settings=[p for p in [sdk/'SDKSettings.json',sdk/'SDKSettings.plist'] if p.is_file()]
        require(settings,'missing SDK metadata');record['sdk']={'path':str(sdk),'settings':{p.name:digest(p,guard) for p in settings},'scope':'metadata identity, not every SDK/library/header byte'}
        roots['@sdk']=sdk
        for name in ['clang++','swiftc','swift-frontend','ar','ld','xcodebuild']:
            selected_path=pathlib.Path(guard.run(['/usr/bin/xcrun','--find',name],'resolve-'+name.replace('+','p')).strip())
            require(selected_path.is_absolute() and selected_path.name==name,'unexpected tool invocation identity')
            p=selected_path.resolve(strict=True)
            require(str(p).startswith('/Applications/') and p.is_file(),'unexpected installed tool root')
            tools[str(p)]=digest(p,guard);resolved_tools[name]=str(selected_path)
            tool_selections[name]={'invocationPath':str(selected_path),'resolvedPath':str(p)}
        for p in ['/usr/bin/xcrun','/usr/bin/xcodebuild','/usr/bin/xcode-select','/usr/bin/git','/bin/ps',sys.executable]:
            path=pathlib.Path(p).resolve(strict=True);tools[str(path)]=digest(path,guard)
        verify_tool_selections(tool_selections)
        record['toolPins']=tools;record['toolSelections']=tool_selections;record['toolPinsBefore']=True;save()
        for name,pin in recipe['generatedSources'].items():
            src=under(source/'prepared-stage-c-final',name);dst=output/name
            require(digest(src,guard)==pin['sha256'],'generated source mismatch');dst.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(src,dst)
        def generated_pins():
            verify_generated_sources(output,recipe,guard)
        generated_pins();record['generatedBuildPinsBefore']=True;save()
        observer_names=json.loads((source/'SOURCE_CHECKS.json').read_text())['observerGroups']
        require(len(recipe['commands'])==31,'native command inventory changed')
        for command in recipe['commands']:
            record['phase']=('cxx-compile' if command['label'].startswith('compile-') else
              {'archive':'archive','observer-tests-compile':'observer-compile','observer-tests-run':'observer-test',
               'swift-probe-compile':'swift-compile','probe-run':'route-matrix'}[command['label']])
            argv=[resolve_argument(x,roots) for x in command['argv']]
            # Sole declared launch-only addition: keep Swift's generated Clang
            # modules under the observed output budget, not the user's cache.
            if command['label']=='swift-probe-compile':argv[2:2]=['-module-cache-path',str(output/'module-cache')]
            # Keep clang++/swiftc alias basenames (driver mode), but bind their
            # resolved targets. Never perform another xcrun selection for native work.
            verify_tool_selections(tool_selections)
            argv=resolved_native_command(argv,resolved_tools)
            record['nativeCompileStarted']=True;save()
            text=guard.run(argv,command['label'])
            record['nativeCommandsCompleted']+=1
            if command['label']=='observer-tests-run':
                record['observer']=validate_observer(text,observer_names)
                require((output/'observer-tests-run.stderr.private.txt').stat().st_size==0,'observer emitted stderr')
        record['phase']='matrix-validation'
        result_path=output/'RESULT.private.json'
        require(result_path.stat().st_size<=1048576,'route result cap')
        data=load_json(result_path.read_text())
        request_path=repo/'research/native-floor-import-repair-20261028/strict-endpoint-probe/REQUESTS_49A.json'
        requests=load_json(request_path.read_text())
        reference_path=repo/'research/native-floor-import-repair-20261028/native-strict-result-40791907324/RESULT.json'
        masks_path=repo/'research/native-floor-import-repair-20261028/edt-navigation-probe/EDT_MASK_INPUTS.json'
        record['matrixObservation']=matrix_observation(data,requests,load_json(masks_path.read_text()))
        # Safe scalar/digest receipts are retained even if the new candidate fails
        # its goals; this never changes the engine's acceptance or native result.
        record['candidatePublicReceipts']=candidate_receipts(data,requests,load_json(reference_path.read_text()))
        old_envelope_path=HERE/'ACTUAL003_EXPECTED_ENVELOPE.json'
        require(digest(old_envelope_path,guard)=='cfae06b474540a7e0bed91c09ced9f6ad47add1eda4e49da03354aae3d5da4cc','actual003 expected envelope drift')
        old_envelope=load_json(old_envelope_path.read_text())
        expected=old_envelope['aggregate']['candidateReceipts']
        require(old_envelope['launcherExit']==0 and len(expected)==25,'actual003 successful reference required')
        record['actual003CandidateReceiptsExactMatch']=record['candidatePublicReceipts']==expected
        require(record['actual003CandidateReceiptsExactMatch'],'actual003 candidate digest/scalar parity mismatch')
        record['envelopeWorkReceipts']=validated_envelope_receipts(data,requests)
        result=validate_result(data,requests)
        record['routeResultSHA256']=digest(result_path,guard);record['routeAcceptance']=result
        record['phase']='postcheck'
        source_pins();verify_source_packet(source,source_manifest,material,guard);verify_manifest(HERE,launch_manifest,guard)
        generated_pins();record['generatedBuildPinsAfter']=True
        require(digest(HERE/'LAUNCH_MANIFEST.json',guard)==admission['launchManifestSHA256'],'launch manifest changed')
        record['sourcePinsAfter']=True
        for p,wanted in tools.items():require(digest(p,guard)==wanted,'tool executable changed')
        verify_tool_selections(tool_selections)
        for p in settings:require(digest(p,guard)==record['sdk']['settings'][p.name],'SDK metadata changed')
        record['toolPinsAfter']=True
        require(guard.run(['/usr/bin/git','rev-parse','HEAD'],'repository-head-after').strip()==head,'checkout head changed')
        require(not guard.run(['/usr/bin/git','status','--porcelain','--untracked-files=no'],'tracked-status-after').strip(),'tracked checkout changed')
        record['status']='passed-fixed-source-route-matrix';save();guard.monitor()
    except BaseException as error:
        record['status']='failed-or-inconclusive';record['errorType']=type(error).__name__;record['error']=str(error)[:1000]
        record['controlledReasonCode']=controlled_reason(error)
        if record['phase']=='matrix-validation':
            observed=record.get('matrixObservation')
            record['controlledReasonCode']=('MATRIX_STRUCTURE_REFUSED' if observed is None else
              'CONTROL_BASELINE_MISMATCH' if not observed['all50OriginalControlsReproduced'] else
              'CANDIDATE_CRITERION_FAILED' if not observed['candidateGoalsMet'] else 'MATRIX_STRUCTURE_REFUSED')
        if record['phase']=='matrix-validation' and getattr(guard,'firstFailure',None) is None:
            event=failure_event(error,'launcher');event['reasonCode']=record['controlledReasonCode']
            record.setdefault('firstFailure',event);record.setdefault('firstFailurePhase',record['phase'])
        retain_first_failure(record,guard,error,record['phase'])
        if guard is not None:
            guard.failure=record['errorType']+': '+record['error']
            try:guard.retire();guard.save()
            except BaseException as terminal:
                record['retirementError']=type(terminal).__name__+': '+str(terminal)[:200]
                retain_first_failure(record,guard,terminal,record['phase'],secondary='retirement')
            if record['nativeCompileStarted']:
                # After failure, only bounded read-only reconciliation; never
                # a second compile/run. If the cap is already exhausted, retain
                # the unperformed postcheck rather than extending the budget.
                try:
                    guard.monitor();source_pins();verify_source_packet(source,source_manifest,material,guard)
                    if 'generated_pins' in locals():generated_pins();record['generatedBuildPinsAfter']=True
                    verify_manifest(HERE,launch_manifest,guard)
                    require(digest(HERE/'LAUNCH_MANIFEST.json',guard)==admission['launchManifestSHA256'],'launch manifest changed')
                    record['sourcePinsAfter']=True
                    for p,wanted in tools.items():require(digest(p,guard)==wanted,'tool executable changed')
                    verify_tool_selections(tool_selections)
                    for p in settings:require(digest(p,guard)==record['sdk']['settings'][p.name],'SDK metadata changed')
                    record['toolPinsAfter']=True
                except BaseException as postcheck:
                    record['postcheckFailure']=type(postcheck).__name__+': '+str(postcheck)[:200]
                    retain_first_failure(record,guard,postcheck,record['phase'],secondary='postcheck')
        try:save()
        except BaseException as cleanup:retain_first_failure(record,guard,cleanup,record['phase'],secondary='receipt-save')
        raise
    finally:
        # Only this fixed aggregate is an upload candidate. No raw arrays, logs,
        # argv, admission token, machine tool paths or binaries are exported.
        aggregate={'schema':'blind.exact-seed-radius-envelope-stage-c.aggregate.v2','status':record['status'],
          'nativeCommandsCompleted':record['nativeCommandsCompleted'],'sourcePinsBefore':record['sourcePinsBefore'],
          'sourcePinsAfter':record['sourcePinsAfter'],'toolPinsBefore':record['toolPinsBefore'],
          'toolPinsAfter':record['toolPinsAfter'],'physicalAuthority':False,'appActivation':False}
        aggregate['frozenInputSHA256']={
          'packedRoutingGeometry':'0731735bf24f198288efea26d79c8a29929d49b10d3be0637e9e15fb983c63b7',
          'requests25':'e5d2e07c7564869d2abde1d4a947e022d1a166c64641a81f2b92fcdbab73ac51',
          'expectedMasksAndLayouts':'13f436a77608178789c6ba19db1f6de7f91d07229b3af3771106d7c4b218ed2a',
          'nativeReference50':'0858272d1faca7e16268b772f0cd164652c08eb22277d36514d2eae72b803893'}
        if result is not None:aggregate['routeAcceptance']=result
        if 'observer' in record:aggregate['observerGroupsPassed']=record['observer']['groups']
        if 'matrixObservation' in record:aggregate['matrixObservation']=record['matrixObservation']
        aggregate['actual003CandidateReceiptsExactMatch']=record.get('actual003CandidateReceiptsExactMatch',False)
        if 'envelopeWorkReceipts' in record:aggregate['envelopeWorkReceipts']=record['envelopeWorkReceipts']
        if 'candidatePublicReceipts' in record:
            aggregate['candidateReceipts']=record['candidatePublicReceipts']
            aggregate['pathDigestEncoding']='blind.ordered-float32-xyz-path.v1\\0 + UInt32LE point count + ordered XYZ IEEE754 Float32LE components; SHA256; negative zero preserved'
        build_failure=lambda:failure_evidence(record,guard,recipe,roots,output)
        if record['status']=='failed-or-inconclusive':aggregate['failureEvidence']=build_failure()
        encoded,terminal_error=finalize_public_aggregate(output,aggregate,guard,record,save,build_failure)
        signal.setitimer(signal.ITIMER_REAL,0)
        sys.stdout.write(encoded.decode('utf-8'))
        if terminal_error is not None:raise terminal_error

def time_elapsed(guard):
    import time
    return time.monotonic()-guard.started

if __name__=='__main__':main()

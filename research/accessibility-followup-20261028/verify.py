#!/usr/bin/env python3
"""Portable proposal checks only. No native build, install, or remote execution."""
from pathlib import Path
import hashlib, json, subprocess, tempfile, importlib.util, unittest
D=Path(__file__).resolve().parent; R=D.parents[1]
with tempfile.TemporaryDirectory() as td:
    root=Path(td)
    pins=json.loads((D/'SOURCE_PINS.json').read_text())
    for name, hashes in pins.items():
        raw=(R/name).read_bytes()
        assert hashlib.sha256(raw).hexdigest()==hashes['base_sha256'], 'Source changed: review/rebase proposal, do not force apply'
        p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(raw)
    subprocess.run(['git','apply',str(D/'fresh-ask-proposal.patch')],cwd=root,check=True,capture_output=True)
    for name, hashes in pins.items():
        assert hashlib.sha256((root/name).read_bytes()).hexdigest()==hashes['candidate_sha256']
    source=(root/'ios/BlindAssistUITests/LaunchTests.swift').read_text()
    old=(R/'ios/BlindAssistUITests/LaunchTests.swift').read_text()
    start=old.index('    @MainActor\n    func testAccessibilityAuditOfCameraAndAsk')
    end=old.index('    func testOfflineCommunityLibraryKeepsLocalImportAvailable', start)
    assert old[start:end] in source, 'Original combined case changed'
    assert source.count('try auditFullDestination("askfresh"')==1
    assert 'continueAfterFailure = false' in source
    # Existing exporter regressions remain relevant, run against candidate only.
    tests=root/'tools/test/full-audit-evidence.test.py';tests.parent.mkdir(parents=True,exist_ok=True)
    tests.write_bytes((R/'tools/test/full-audit-evidence.test.py').read_bytes())
    legacy=subprocess.run(['python',str(tests)],capture_output=True,text=True,check=True)
    spec=importlib.util.spec_from_file_location('candidate',root/'tools/ci/export-full-audit-evidence.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
    def run(roles, *, duplicate=False, corrupt=False):
        with tempfile.TemporaryDirectory() as case:
            c=Path(case);src=c/'source';src.mkdir();items=[]
            for i,role in enumerate(roles):
                f=f'{i}.png';(src/f).write_bytes(b'\x89PNG\r\n\x1a\nfixture')
                items.append({'suggestedHumanReadableName':f'full-audit-{role}.png','exportedFileName':f})
            if duplicate:items.append(items[-1])
            if corrupt:(src/'0.png').write_bytes(b'invalid')
            (src/'manifest.json').write_text(json.dumps([{'attachments':items}]))
            return m.collect(src,c/'dest',require_fresh_ask=True)
    both=['camera-before','camera-after','askfresh-before','askfresh-after']
    a=run(both);assert a['evidenceComplete'];assert a['nativeAuditOutcome']=='not_inferred_from_attachments'
    assert not run(both[:2])['evidenceComplete']
    assert not run(both[:-1])['evidenceComplete']
    assert not run(both,duplicate=True)['evidenceComplete']
    assert not run(both,corrupt=True)['evidenceComplete']
    assert run(both+['ask-before','ask-after'])['evidenceComplete']
    assert not run(['askfresh-before','askfresh-after'])['evidenceComplete']
    result={'schema':1,'status':'portable_proposal_checks_pass','legacy_exporter_tests':legacy.stderr.strip(),'new_fixture_checks':7,'native_execution':'not_run','production_files_modified':False}
    print(json.dumps(result,indent=2))

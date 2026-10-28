#!/usr/bin/env python3
"""Bounded synthetic payloads and real workflow/exporter execution; not native USD."""
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import plistlib
import shutil
import stat
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ROOT = Path(__file__).resolve().parents[2]
def module(name, path):
    spec=importlib.util.spec_from_file_location(name,path);value=importlib.util.module_from_spec(spec);spec.loader.exec_module(value);return value
m=module('public_export',Path(__file__).with_name('export-public-apple-same-export.py'))
samples=module('route_samples',Path(__file__).with_name('test-native-route-diagnostic-evidence.py'))
early=module('early_fixture',ROOT/'research/early-native-summary-repair-20261028/test-export-order.py')


def archive(name='scene.usda', content=b'#usda 1.0\ndef Xform "PublicFixture" {}\n', compression=zipfile.ZIP_STORED, symlink=False):
    output=io.BytesIO()
    with zipfile.ZipFile(output,'w',compression=compression) as zip:
        info=zipfile.ZipInfo(name);info.compress_type=compression
        if symlink:info.external_attr=(stat.S_IFLNK|0o777)<<16
        zip.writestr(info,content)
    return output.getvalue()


def payloads():
    result={};inventory=samples.metadata_inventory();records=[]
    for fixture in inventory['fixtures']:
        room=fixture['fixtureID'];uuid=fixture['metadataEntries'][0]['uuid']
        metadata=plistlib.dumps({'Wall0':uuid},fmt=plistlib.FMT_BINARY)
        fixture.update(metadataFormat='binaryPlist',metadataByteCount=len(metadata))
        asset_name='APPLE_ROOM_ROUTE_'+room+'_SAME_EXPORT.usdz'
        metadata_name='APPLE_ROOM_ROUTE_'+room+'_SAME_EXPORT_METADATA.bin'
        result[asset_name]=archive();result[metadata_name]=metadata
        records.append({'fixtureID':room,'sourceSHA256':m.routes.FIXTURES[room],
            'assetAttachmentName':asset_name,'metadataAttachmentName':metadata_name,
            'assetSHA256':hashlib.sha256(result[asset_name]).hexdigest(),'metadataSHA256':hashlib.sha256(metadata).hexdigest(),
            'assetByteCount':len(result[asset_name]),'metadataByteCount':len(metadata),'metadataFormat':'binaryPlist'})
    result[m.INVENTORY]=json.dumps(inventory).encode()
    result[m.MANIFEST]=json.dumps({'schema':'blind.saved-room-route-same-export.v1','physicalAuthority':False,
        'exportRole':'diagnostic-export','productionAdapterExport':'separate-unretained','testIdentifier':m.TEST,
        'inventoryAttachmentName':m.INVENTORY,'inventorySHA256':hashlib.sha256(result[m.INVENTORY]).hexdigest(),
        'fixtures':records}).encode()
    return result


def export_fixture(directory, values):
    directory.mkdir(parents=True)
    records=[]
    for i,(name,raw) in enumerate(values.items()):
        filename='attachment-'+str(i)+'.bin';(directory/filename).write_bytes(raw)
        records.append({'suggestedHumanReadableName':name,'exportedFileName':filename,
            'uniformTypeIdentifier':'public.json' if name.endswith('.json') else 'public.data','payloadSize':len(raw)})
    (directory/'manifest.json').write_text(json.dumps([{'attachments':records}]))


def case_evidence():
    return {'complete':True,'source_verified':True,'aggregate_counts_match':True,
        'expected_commit':'a'*40,'source_commit':'a'*40,'case_count':1,
        'cases':[{'identifier':'BlindAssistTests/'+m.TEST+'()','result':'Failed'}],
        'counts':{'Passed':0,'Failed':1,'Skipped':0,'Expected Failure':0}}


class ValidationTests(unittest.TestCase):
    def validate(self, value):return m.validate_payloads(value,samples.DOCS,samples.UUIDS)
    def test_complete_fixed_manifest_inventory_and_binary_binding(self):
        result=self.validate(payloads());self.assertEqual([row['fixtureID'] for row in result],list(m.ROOMS))
        self.assertTrue(all(row['archive']['geometryLayerCount']==1 for row in result))
    def test_wrong_manifest_source_role_test_name_hash_size_and_authority_rejected(self):
        for change in ('source','role','test','name','inventory_hash','asset_hash','metadata_hash','size','authority','private','duplicate'):
            data=payloads();manifest=json.loads(data[m.MANIFEST]);row=manifest['fixtures'][0]
            if change=='source':row['sourceSHA256']='0'*64
            elif change=='role':manifest['productionAdapterExport']='same-as-production'
            elif change=='test':manifest['testIdentifier']='PrivateTests/testCapture'
            elif change=='name':row['assetAttachmentName']='private.usdz'
            elif change=='inventory_hash':manifest['inventorySHA256']='0'*64
            elif change=='asset_hash':row['assetSHA256']='0'*64
            elif change=='metadata_hash':row['metadataSHA256']='0'*64
            elif change=='size':row['assetByteCount']=True
            elif change=='authority':manifest['physicalAuthority']=True
            elif change=='private':manifest['privateHistory']='secret'
            else:manifest['fixtures'][1]=copy.deepcopy(row)
            data[m.MANIFEST]=json.dumps(manifest).encode()
            with self.subTest(change=change),self.assertRaises(m.Error):self.validate(data)
    def test_payload_set_and_all_size_caps_closed(self):
        for name,cap in m.FILES.items():
            data=payloads();data[name]=b'x'*(cap+1)
            with self.subTest(name=name),self.assertRaisesRegex(m.Error,'payload_set_or_budget_mismatch'):self.validate(data)
        data=payloads();data['private-frame.png']=b'private'
        with self.assertRaises(m.Error):self.validate(data)
    def test_raw_metadata_must_match_inventory_and_only_public_feature_ids(self):
        for change in ('unknown_uuid','unknown_key','format','entry_count'):
            data=payloads();manifest=json.loads(data[m.MANIFEST]);row=manifest['fixtures'][0];name=row['metadataAttachmentName']
            values=plistlib.loads(data[name]);inventory=json.loads(data[m.INVENTORY])
            if change=='unknown_uuid':values['Wall0']='00000000-0000-0000-0000-000000000000'
            elif change=='unknown_key':values={'Other':values['Wall0']}
            elif change=='format':row['metadataFormat']='json'
            else:inventory['fixtures'][0]['metadataEntryCount']=2
            data[name]=plistlib.dumps(values,fmt=plistlib.FMT_BINARY)
            row['metadataSHA256']=hashlib.sha256(data[name]).hexdigest();row['metadataByteCount']=len(data[name])
            data[m.INVENTORY]=json.dumps(inventory).encode();manifest['inventorySHA256']=hashlib.sha256(data[m.INVENTORY]).hexdigest()
            data[m.MANIFEST]=json.dumps(manifest).encode()
            with self.subTest(change=change),self.assertRaises(m.Error):self.validate(data)
    def test_usdz_no_images_paths_symlinks_compression_or_unbounded_directory(self):
        for name in ('photo.png','../scene.usda','/scene.usda','file://scene.usda','dir\\scene.usda'):
            with self.subTest(name=name),self.assertRaises(m.Error):m.validate_usdz(archive(name))
        for raw in (archive(compression=zipfile.ZIP_DEFLATED),archive(symlink=True),archive(content=b'private data'),b'not zip'):
            with self.assertRaises(m.Error):m.validate_usdz(raw)
        raw=bytearray(archive());end=raw.rfind(b'PK\x05\x06');struct.pack_into('<HH',raw,end+8,65,65)
        with self.assertRaisesRegex(m.Error,'unsupported_usdz_directory'):m.validate_usdz(bytes(raw))
    def test_exact_test_identifier_only_and_case_verification(self):
        self.assertEqual(m.canonical('BlindAssistTests/'+m.TEST+'()'),m.TEST)
        for identifier in ('Unknown/'+m.TEST,m.TEST+'Extra()',m.TEST+'/child'):
            self.assertIsNone(m.canonical(identifier))
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'cases.json';data=case_evidence();path.write_text(json.dumps(data))
            self.assertEqual(m.observed_case(path,'a'*40)['result'],'Failed')
            for change in ('source','complete','counts','duplicate','skipped','unknown'):
                data=case_evidence()
                if change=='source':data['source_commit']='b'*40
                elif change=='complete':data['complete']=False
                elif change=='counts':data['counts']['Failed']=True
                elif change=='duplicate':data['cases']*=2;data['case_count']=2;data['counts']['Failed']=2
                elif change=='skipped':data['cases'][0]['result']='Skipped';data['counts'].update(Failed=0,Skipped=1)
                else:data['cases'][0]['identifier']='Private/test'
                path.write_text(json.dumps(data))
                with self.subTest(change=change),self.assertRaises(m.Error):m.observed_case(path,'a'*40)


class BoundaryTests(unittest.TestCase):
    def test_exact_names_known_exporter_suffix_and_type(self):
        for name in m.FILES:
            self.assertEqual(m.attachment_name(name),name)
            stem,ext=name.rsplit('.',1)
            self.assertEqual(m.attachment_name(stem+'_1_ABCD.'+ext),name)
            if ext!='json':self.assertEqual(m.attachment_name(name+'_1_ABCD.data'),name)
        self.assertIsNone(m.attachment_name('camera-frame.json'))
        with tempfile.TemporaryDirectory() as tmp:
            directory=Path(tmp)/'export';export_fixture(directory,payloads())
            self.assertEqual(m.attachments(directory),payloads())
    def test_unapproved_attachment_filename_symlink_and_extra_file_fail_closed(self):
        for change in ('name','path','type','symlink','extra','size'):
            with tempfile.TemporaryDirectory() as tmp:
                directory=Path(tmp)/'export';export_fixture(directory,payloads())
                path=directory/'manifest.json';manifest=json.loads(path.read_text());entry=manifest[0]['attachments'][0]
                if change=='name':entry['suggestedHumanReadableName']='camera-frame.jpg'
                elif change=='path':entry['exportedFileName']='../private.bin'
                elif change=='type':entry['uniformTypeIdentifier']='public.jpeg'
                elif change=='size':entry['payloadSize']=True
                elif change=='symlink':
                    selected=directory/entry['exportedFileName'];selected.unlink();selected.symlink_to('/etc/passwd')
                else:(directory/'private.txt').write_text('not read')
                path.write_text(json.dumps(manifest))
                with self.subTest(change=change),self.assertRaises(m.Error):m.attachments(directory)
    def test_export_owned_timeout(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);stub=root/'xcrun';stub.write_text('#!'+sys.executable+'\nimport time;time.sleep(10)\n');stub.chmod(0o755)
            with patch.dict(os.environ,{'PATH':str(root)+os.pathsep+os.environ.get('PATH','')}),patch.object(m.time,'monotonic',side_effect=[0,16]):
                with self.assertRaisesRegex(m.Error,'attachment_export_timeout'):m.export_test(Path('unused'),m.TEST,root/'out')
    def test_main_atomic_success_or_error_receipt_only_and_cleanup(self):
        for change in ('success','bad_hash','private_error','source_changed','write_failure'):
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp);case=root/'cases.json';case.write_text(json.dumps(case_evidence()));out=root/'public'
                data=payloads()
                if change=='bad_hash':data['APPLE_ROOM_ROUTE_Hallway2_SAME_EXPORT.usdz']+=b'changed'
                exported=[]
                def exporter(bundle,identifier,directory):
                    exported.append(directory.parent)
                    if change=='private_error':raise OSError('/Users/private/camera.jpg')
                    export_fixture(directory,data)
                proof={'actual_head':'a'*40,'tracked_source_clean':True}
                after={'actual_head':'b'*40} if change=='source_changed' else proof
                original=Path.write_bytes
                def write(path,raw):
                    if path.parent.name.startswith('.blind-public'):
                        self.assertEqual(list(out.iterdir()),[]) # Fixed upload names remain absent until atomic rename.
                    if change=='write_failure' and path.name.endswith('METADATA.bin') and path.parent.name.startswith('.blind-public'):
                        raise OSError('private disk failure')
                    return original(path,raw)
                with patch.object(sys,'argv',['exporter','unit.xcresult',str(case),str(out)]),patch.dict(os.environ,{'GITHUB_SHA':'a'*40}),\
                     patch.object(m.statuses,'provenance',side_effect=[proof,after]),patch.object(m,'export_test',side_effect=exporter),\
                     patch.object(Path,'write_bytes',write),contextlib.redirect_stdout(io.StringIO()):
                    code=m.main()
                receipt=json.loads((out/'receipt.json').read_text())
                self.assertTrue(all(not directory.exists() for directory in exported))
                self.assertNotIn('private',json.dumps(receipt));self.assertNotIn('camera.jpg',json.dumps(receipt))
                if change=='success':
                    self.assertEqual(code,0);self.assertTrue(receipt['sourceVerified']);self.assertEqual(receipt['testResult'],'Failed')
                    self.assertEqual({p.name for p in out.iterdir()},set(m.FILES)|{'receipt.json'})
                    for name,raw in data.items():self.assertEqual((out/name).read_bytes(),raw)
                else:
                    self.assertEqual(code,1);self.assertFalse(receipt['sourceVerified'])
                    self.assertEqual({p.name for p in out.iterdir()},{'receipt.json'})
                self.assertFalse(list(root.glob('.blind-public-same-export-*')))
    def test_interruption_before_atomic_publication_leaves_no_uploadable_partial(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);case=root/'cases.json';case.write_text(json.dumps(case_evidence()));out=root/'public'
            def exporter(bundle,identifier,directory):export_fixture(directory,payloads())
            original=Path.write_bytes
            def interrupt(path,raw):
                if path.parent.name.startswith('.blind-public') and path.name.endswith('METADATA.bin'):
                    self.assertEqual(list(out.iterdir()),[])
                    raise KeyboardInterrupt('synthetic interruption')
                return original(path,raw)
            with patch.object(sys,'argv',['exporter','unit.xcresult',str(case),str(out)]),patch.dict(os.environ,{'GITHUB_SHA':'a'*40}),\
                 patch.object(m.statuses,'provenance',return_value={'actual_head':'a'*40}),patch.object(m,'export_test',side_effect=exporter),\
                 patch.object(Path,'write_bytes',interrupt),contextlib.redirect_stdout(io.StringIO()),self.assertRaises(KeyboardInterrupt):
                m.main()
            self.assertEqual(list(out.iterdir()),[])
            self.assertFalse(list(root.glob('.blind-public-same-export-*')))
    def test_existing_output_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as tmp:
            out=Path(tmp)/'public';out.mkdir();sentinel=out/'receipt.json';sentinel.write_text('existing')
            with patch.object(sys,'argv',['exporter','unused','unused',str(out)]),contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(m.main(),1)
            self.assertEqual(sentinel.read_text(),'existing')


class ActualWorkflowIntegrationTests(unittest.TestCase):
    def fixture(self, include_test=True):
        harness=early.EarlySummaryIntegrationTests();harness.setUp();self.addCleanup(harness.doCleanups)
        if include_test:
            harness.cases.append({'nodeType':'Test Case','nodeIdentifier':m.TEST+'()','result':'Failed'})
            harness.summary.update(totalTestCount=4,failedTests=2)
        # Exact original fixture/protocol/source files required by the actual collector.
        relative=['tools/ci/export-public-apple-same-export.py']+list(samples.HASHES)
        for name in relative:
            destination=harness.repo/name;destination.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(ROOT/name,destination)
        inputs=harness.base/'payloads';inputs.mkdir();data=payloads()
        for name,raw in data.items():(inputs/name).write_bytes(raw)
        harness.env['PUBLIC_PAYLOADS']=str(inputs)
        extension='''if args[:3]==['xcresulttool','export','attachments']:
        assert args==['xcresulttool','export','attachments','--path',str(out/'unit.xcresult'),'--test-id',
            'SavedRoomRouteMeshAppleFixtureTests/testOriginalAppleSameExportForOpenUSDComparison()', '--output-path',args[-1]]
        destination=pathlib.Path(args[-1]);destination.mkdir()
        records=[]
        for i,source in enumerate(sorted(pathlib.Path(os.environ['PUBLIC_PAYLOADS']).iterdir())):
            raw=source.read_bytes();filename='payload-'+str(i)+'.bin';(destination/filename).write_bytes(raw)
            records.append({'suggestedHumanReadableName':source.name,'exportedFileName':filename,
                'payloadSize':len(raw),'uniformTypeIdentifier':'public.json' if source.name.endswith('.json') else 'public.data'})
        (destination/'manifest.json').write_text(json.dumps([{'attachments':records}]))
        sys.exit(0)
    assert args[:3]==['xcresulttool','get','test-results']'''
        stub=early.STUB.replace("assert args[:3]==['xcresulttool','get','test-results']",extension)
        (harness.bin/'xcrun').write_text('#!'+sys.executable+'\n'+stub)
        self.assertIn('export-public-apple-same-export.py',early.workflow_command())
        return harness,data
    def test_full_current_workflow_real_summary_case_exporter_and_binary_extractor(self):
        harness,data=self.fixture();completed,cases,calls=harness.execute()
        self.assertEqual(completed.returncode,0,completed.stderr)
        self.assertNotIn('No such file',completed.stderr)
        self.assertTrue(cases['complete']);self.assertTrue(cases['source_verified'])
        self.assertEqual(cases['counts']['Failed'],2)
        output=harness.out/'public-apple-same-export';receipt=json.loads((output/'receipt.json').read_text())
        self.assertEqual(receipt['status'],'complete');self.assertTrue(receipt['sourceVerified']);self.assertEqual(receipt['testResult'],'Failed')
        self.assertEqual({p.name for p in output.iterdir()},set(m.FILES)|{'receipt.json'})
        for name,raw in data.items():self.assertEqual((output/name).read_bytes(),raw)
        queries=[call for call in calls if call['tool']=='xcrun']
        self.assertEqual([call['args'][:4] for call in queries],[['xcresulttool','get','test-results','summary'],
            ['xcresulttool','get','test-results','tests'],['xcresulttool','export','attachments','--path']])
        self.assertNotIn('base64',(harness.out/'unit-case-statuses.json').read_text())
        self.assertLess((harness.out/'unit-case-statuses.json').stat().st_size,1024*1024)
    def test_full_workflow_incomplete_cases_never_export_binaries(self):
        harness,_=self.fixture();harness.env['SUMMARY_FAILURE']='1'
        completed,cases,calls=harness.execute();self.assertEqual(completed.returncode,0)
        self.assertFalse(cases['complete']);output=harness.out/'public-apple-same-export'
        receipt=json.loads((output/'receipt.json').read_text());self.assertEqual(receipt['status'],'unverified_case_evidence')
        self.assertEqual({p.name for p in output.iterdir()},{'receipt.json'})
        self.assertFalse(any(call['tool']=='xcrun' and call['args'][1]=='export' for call in calls))
    def test_full_workflow_absent_exact_test_emits_only_explicit_receipt(self):
        harness,_=self.fixture(False);completed,cases,calls=harness.execute()
        self.assertTrue(cases['complete']);output=harness.out/'public-apple-same-export'
        self.assertEqual(json.loads((output/'receipt.json').read_text())['status'],'test_not_observed')
        self.assertEqual({p.name for p in output.iterdir()},{'receipt.json'})
        self.assertFalse(any(call['tool']=='xcrun' and call['args'][1]=='export' for call in calls))


if __name__=='__main__':unittest.main()

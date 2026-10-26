#!/usr/bin/env python3
"""Mocked protocol tests; never use a credential or real network."""
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('mirror', Path(__file__).with_name('navigation-test-data-release.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
SOURCE = 'a' * 40
ACT = 'b' * 40
ROOT = Path(__file__).resolve().parents[2]


def env_event():
    env = dict(GITHUB_ACTIONS='true', RUNNER_ENVIRONMENT='github-hosted', RUNNER_OS='Linux',
               GITHUB_REPOSITORY=m.REPO, GITHUB_REF='refs/heads/master', GITHUB_RUN_ATTEMPT='1',
               GITHUB_EVENT_NAME='push', GITHUB_SERVER_URL='https://github.com',
               GITHUB_API_URL='https://api.github.com', GITHUB_SHA=ACT)
    event = dict(repository=dict(full_name=m.REPO, private=False), ref='refs/heads/master', after=ACT,
                 head_commit=dict(id=ACT, message='transfer ' + m.marker(SOURCE)), deleted=False, forced=False)
    return env,event


def release():
    return dict(id=12, tag_name=m.TAG, name=m.TITLE, draft=False, prerelease=True, body='body',
                html_url='https://github.com/' + m.REPO + '/releases/tag/' + m.TAG)


def expected(data=b'hello', name='tiny.dat'):
    return dict(name=name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest())


def remote_asset(e=None):
    e = e or expected()
    return dict(id=19, name=e['name'], size=e['bytes'], digest='sha256:' + e['sha256'], state='uploaded',
                browser_download_url='https://github.com/' + m.REPO + '/releases/download/' + m.TAG + '/' + e['name'])


class FakeAPI:
    def __init__(self, responses):
        self.responses = list(responses)
        self.calls = []
    def request(self, method, path, **kwargs):
        self.calls.append((method,path,kwargs))
        if not self.responses:
            raise AssertionError('unexpected request ' + method + ' ' + path)
        result = self.responses.pop(0)
        if isinstance(result, Exception):
            raise result
        return copy.deepcopy(result)
    def posts(self):
        return [x for x in self.calls if x[0] == 'POST']


class DummyBudget:
    def __init__(self): self.downloaded = 0
    def check(self): pass
    def add(self, n): self.downloaded += n


class Response:
    def __init__(self, data, status=200, headers=None):
        self.stream = io.BytesIO(data)
        self.status = status
        self.headers = headers or {}
    def read(self, size=-1): return self.stream.read(size)
    def getheader(self, name, default=None): return self.headers.get(name, default)


class Connection:
    def __init__(self, response):
        self.response = response
        self.calls = []
    def request(self, method, path, body=None, headers=None):
        self.calls.append((method,path,body.read() if hasattr(body,'read') else body,headers))
    def getresponse(self): return self.response
    def close(self): pass


class Tests(unittest.TestCase):
    def test_allowlist_exact(self):
        manifest=json.loads((ROOT/m.DATA/'assets.json').read_text())
        self.assertEqual(sum(a['bytes'] for a in m.pinned_assets(manifest)), 602159665)
        for key,value in [('url','https://example.org/file'),('sha256','0'*64),('bytes',1),('license','CC0')]:
            bad=copy.deepcopy(manifest);bad[0][key]=value
            with self.assertRaises(m.Refusal): m.pinned_assets(bad)
        with self.assertRaises(m.Refusal): m.pinned_assets(manifest + [manifest[0]])

    def test_event_accepts_exact(self):
        env,event=env_event();self.assertEqual(m.check_event(env,event,SOURCE),ACT)

    def test_environment_guards(self):
        env,event=env_event()
        for key,value in [('GITHUB_ACTIONS','false'),('RUNNER_ENVIRONMENT','self-hosted'),('RUNNER_OS','Windows'),
                          ('GITHUB_REPOSITORY','other/repo'),('GITHUB_REF','refs/heads/other'),('GITHUB_RUN_ATTEMPT','2'),
                          ('GITHUB_EVENT_NAME','workflow_dispatch'),('GITHUB_SERVER_URL','http://github.com'),
                          ('GITHUB_API_URL','https://evil.test'),('GITHUB_SHA','main')]:
            bad=dict(env);bad[key]=value
            with self.subTest(key=key),self.assertRaises(m.Refusal):m.check_event(bad,event,SOURCE)

    def test_payload_guards(self):
        env,event=env_event()
        mutations=[lambda x:x['repository'].update(private=True),lambda x:x['repository'].update(full_name='evil/repo'),
                   lambda x:x.update(after=SOURCE),lambda x:x.update(deleted=True),lambda x:x.update(forced=True),
                   lambda x:x.update(ref='refs/heads/other'),lambda x:x['head_commit'].update(message='no marker'),
                   lambda x:x['head_commit'].update(id=SOURCE)]
        for mutate in mutations:
            bad=copy.deepcopy(event);mutate(bad)
            with self.assertRaises(m.Refusal):m.check_event(env,bad,SOURCE)
        for bad in ['master','a'*39,'A'*40,'']:
            with self.assertRaises(m.Refusal):m.check_event(env,event,bad)

    def test_pinned_source_guard(self):
        source=ROOT;workspace=ROOT.parent
        with patch.object(m.subprocess,'check_output',side_effect=[SOURCE+'\n','']):
            self.assertEqual(m.check_source(source,SOURCE,workspace),source)
        for result in [[ACT+'\n'],[SOURCE+'\n',' M tools/ci/navigation-test-data-release.py']]:
            with patch.object(m.subprocess,'check_output',side_effect=result), self.assertRaises(m.Refusal):
                m.check_source(source,SOURCE,workspace)
        with self.assertRaises(m.Refusal):m.check_source(source,SOURCE,source)
        with self.assertRaises(m.Refusal):m.check_source(Path('/tmp'),SOURCE,Path('/'))

    def test_body_records_both_shas(self):
        body=m.release_body(SOURCE,ACT,'attribution\n')
        self.assertIn(SOURCE,body);self.assertIn(ACT,body);self.assertIn('not an app release',body)

    def test_create_once_then_get_reconciliation(self):
        tag=dict(object=dict(type='commit',sha=ACT))
        api=FakeAPI([m.RemoteError(404),m.RemoteError(404),m.RemoteError(502),m.RemoteError(404),release(),tag])
        self.assertEqual(m.ensure_release(api,'body',ACT,sleep=lambda _:None)['id'],12)
        self.assertEqual(len(api.posts()),1)
        payload=api.posts()[0][2]['payload']
        self.assertEqual(payload['make_latest'],'false');self.assertIs(payload['prerelease'],True)
        self.assertEqual(payload['target_commitish'],ACT)

    def test_existing_release_no_write(self):
        tag=dict(object=dict(type='commit',sha=ACT))
        api=FakeAPI([release(),tag,tag])
        m.ensure_release(api,'body',ACT);self.assertEqual(api.posts(),[])

    def test_release_conflict_and_tag_conflict(self):
        for field,value in [('name','other'),('body','different'),('prerelease',False),('draft',True),('immutable',True)]:
            bad=release();bad[field]=value
            api=FakeAPI([bad,dict(object=dict(type='commit',sha=ACT))])
            with self.assertRaises(m.Refusal):m.ensure_release(api,'body',ACT)
            self.assertEqual(api.posts(),[])
        for obj in [dict(type='commit',sha=SOURCE),dict(type='tag',sha=ACT)]:
            api=FakeAPI([m.RemoteError(404),dict(object=obj)])
            with self.assertRaises(m.Refusal):m.ensure_release(api,'body',ACT)
            self.assertEqual(api.posts(),[])

    def test_unresolved_release_never_posts_twice(self):
        api=FakeAPI([m.RemoteError(404),m.RemoteError(404),TimeoutError()]+[m.RemoteError(404)]*5)
        with self.assertRaises(m.Refusal):m.ensure_release(api,'body',ACT,sleep=lambda _:None)
        self.assertEqual(len(api.posts()),1)

    def test_asset_upload_timeout_reconciles_once(self):
        a=remote_asset();api=FakeAPI([[],TimeoutError(),[],[a],a])
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'tiny.dat';p.write_bytes(b'hello')
            self.assertEqual(m.ensure_asset(api,12,expected(),p,sleep=lambda _:None)['id'],19)
        self.assertEqual(len(api.posts()),1)

    def test_unresolved_asset_never_posts_twice(self):
        api=FakeAPI([[],m.RemoteError(502)]+[[]]*5)
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'tiny.dat';p.write_bytes(b'hello')
            with self.assertRaises(m.Refusal):m.ensure_asset(api,12,expected(),p,sleep=lambda _:None)
        self.assertEqual(len(api.posts()),1)

    def test_existing_asset_skip_no_file_read(self):
        a=remote_asset();api=FakeAPI([[a],a])
        m.ensure_asset(api,12,expected(),Path('/does-not-exist'))
        self.assertEqual(api.posts(),[])

    def test_bad_existing_asset_never_overwrites(self):
        for field,value in [('digest',None),('digest','sha256:'+'0'*64),('state','starter'),('size',999),
                            ('browser_download_url','https://evil.test/file')]:
            a=remote_asset();a[field]=value;api=FakeAPI([[a],a])
            with self.assertRaises(m.Refusal):m.ensure_asset(api,12,expected(),Path('/unused'))
            self.assertEqual(api.posts(),[])

    def test_duplicate_and_unexpected_assets(self):
        a=remote_asset()
        with self.assertRaises(m.Refusal):m.asset_by_name(FakeAPI([[a,a]]),12,a['name'])
        for listing in [[a,a],[dict(name='unexpected')],[a]*100]:
            with self.assertRaises(m.Refusal):m.validate_inventory(FakeAPI([listing]),12,[expected()])
        with self.assertRaises(m.Refusal):m.validate_inventory(FakeAPI([[]]),12,[expected()],complete=True)
        m.validate_inventory(FakeAPI([[a]]),12,[expected()],complete=True)

    def test_local_corruption_never_uploads(self):
        for data in [b'hellO',b'hell',b'hello!']:
            api=FakeAPI([[]])
            with tempfile.TemporaryDirectory() as tmp:
                p=Path(tmp)/'tiny.dat';p.write_bytes(data)
                with self.assertRaises(m.Refusal):m.ensure_asset(api,12,expected(),p)
            self.assertEqual(api.posts(),[])

    def test_no_redirect_authenticated(self):
        for status in [301,302,307,308]:
            conn=Connection(Response(b'',status,{'Location':'https://evil.test'}))
            with patch.object(m.http.client,'HTTPSConnection',return_value=conn) as factory:
                with self.assertRaises(m.RemoteError):m.HTTP('fake-token',DummyBudget()).request('GET',m.PREFIX)
                factory.assert_called_once_with('api.github.com',timeout=90)
            self.assertEqual(len(conn.calls),1)

    def test_streamed_upload_headers(self):
        conn=Connection(Response(b'{"id":1}',201))
        with tempfile.TemporaryDirectory() as tmp,patch.object(m.http.client,'HTTPSConnection',return_value=conn) as factory:
            p=Path(tmp)/'tiny.dat';p.write_bytes(b'hello')
            with m.verified_upload(p,expected()) as upload:
                m.HTTP('fake-token',DummyBudget()).request('POST',m.PREFIX+'/releases/12/assets?name=tiny.dat',upload=upload)
            factory.assert_called_once_with('uploads.github.com',timeout=90)
        self.assertEqual(conn.calls[0][2],b'hello');self.assertEqual(conn.calls[0][3]['Content-Length'],'5')

    def test_method_and_origin_scope(self):
        api=m.HTTP('fake-token',DummyBudget())
        for method,path in [('DELETE',m.PREFIX+'/releases/1'),('PATCH',m.PREFIX+'/releases/1'),
                            ('GET','/repos/evil/repo'),('GET',m.PREFIX+'/\r\n')]:
            with self.assertRaises(m.Refusal):api.request(method,path)

    def test_download_unauthed_and_integrity(self):
        a=expected();a.update(url='https://zenodo.org/test')
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp);d=source/m.DATA;d.mkdir(parents=True);(d/'assets.json').write_text('[]')
            for data,status,headers,valid in [(b'hello',200,{'Content-Length':'5'},True),(b'hellO',200,{},False),
                 (b'hell',200,{},False),(b'hello!',200,{},False),(b'hello',302,{},False),
                 (b'hello',200,{'Content-Length':'6'},False),(b'hello',200,{'Content-Encoding':'gzip'},False)]:
                conn=Connection(Response(data,status,headers));api=m.HTTP('fake-token',DummyBudget());api.source=source
                target=source/'download';target.unlink(missing_ok=True)
                with patch.object(m,'pinned_assets',return_value=[a]),patch.object(m.http.client,'HTTPSConnection',return_value=conn):
                    if valid:api.download(a,target)
                    else:
                        with self.assertRaises(m.Refusal):api.download(a,target)
                self.assertNotIn('Authorization',conn.calls[0][3]);self.assertEqual(len(conn.calls),1)

    def test_download_rejects_alternate_origins(self):
        with tempfile.TemporaryDirectory() as tmp:
            source=Path(tmp);d=source/m.DATA;d.mkdir(parents=True);(d/'assets.json').write_text('[]')
            for url in ['http://zenodo.org/x','https://user@zenodo.org/x','https://zenodo.org.evil/x','https://zenodo.org/x?y=1']:
                a=expected();a['url']=url;api=m.HTTP('fake-token',DummyBudget());api.source=source
                with patch.object(m,'pinned_assets',return_value=[a]),self.assertRaises(m.Refusal):api.download(a,source/'file')

    def test_upload_path_replacement_rejected(self):
        class SwapAPI(FakeAPI):
            def request(self, method, path, **kwargs):
                if method == 'POST':
                    upload=kwargs['upload']
                    p=upload.path if hasattr(upload,'path') else upload
                    p.unlink();p.symlink_to(p.parent/'replacement')
                    return m.HTTP('fake-token',DummyBudget()).request(method,path,upload=upload)
                return super().request(method,path,**kwargs)
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'tiny.dat';p.write_bytes(b'hello');(p.parent/'replacement').write_bytes(b'wrong')
            conn=Connection(Response(json.dumps(remote_asset()).encode(),201))
            api=SwapAPI([[],[remote_asset()],remote_asset()])
            with patch.object(m.http.client,'HTTPSConnection',return_value=conn), self.assertRaises(m.Refusal):
                m.ensure_asset(api,12,expected(),p)
            self.assertEqual(conn.calls,[])

    def test_post_send_integrity_change_reconciles_without_success(self):
        class ChangeAfterSend(Connection):
            def request(self, *args, **kwargs):
                super().request(*args, **kwargs)
                self.path.write_bytes(b'wrong')
        class SendAPI(FakeAPI):
            def request(self, method, path, **kwargs):
                if method == 'POST':
                    self.calls.append((method,path,kwargs))
                    return m.HTTP('fake-token',DummyBudget()).request(method,path,**kwargs)
                return super().request(method,path,**kwargs)
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'tiny.dat';p.write_bytes(b'hello')
            conn=ChangeAfterSend(Response(b'{}',201));conn.path=p
            api=SendAPI([[],[remote_asset()],remote_asset()])
            with patch.object(m.http.client,'HTTPSConnection',return_value=conn),self.assertRaises(m.IntegrityChanged):
                m.ensure_asset(api,12,expected(),p)
            self.assertEqual(len(api.posts()),1)
            self.assertEqual(conn.calls[0][2],b'hello')
            self.assertEqual(api.responses,[])  # list/detail GET reconciliation happened after POST.


    def test_post_send_unlink_reconciles_without_success(self):
        class ChangeAfterSend(Connection):
            def request(self, *args, **kwargs):
                super().request(*args, **kwargs)
                self.path.unlink()
        class SendAPI(FakeAPI):
            def request(self, method, path, **kwargs):
                if method == 'POST':
                    self.calls.append((method,path,kwargs))
                    return m.HTTP('fake-token',DummyBudget()).request(method,path,**kwargs)
                return super().request(method,path,**kwargs)
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp)/'tiny.dat';p.write_bytes(b'hello')
            conn=ChangeAfterSend(Response(b'{}',201));conn.path=p
            api=SendAPI([[],[remote_asset()],remote_asset()])
            with patch.object(m.http.client,'HTTPSConnection',return_value=conn),self.assertRaises(m.IntegrityChanged):
                m.ensure_asset(api,12,expected(),p)
            self.assertEqual(len(api.posts()),1)
            self.assertEqual(conn.calls[0][2],b'hello')
            self.assertEqual(api.responses,[])  # list/detail GET reconciliation happened after POST.


    def test_pending_chunk_reserves_space(self):
        with tempfile.TemporaryDirectory() as tmp:
            b=m.Budget(Path(tmp));disk=type('Disk',(),{'free':4*m.GIB})
            with patch.object(m.shutil,'disk_usage',return_value=disk),self.assertRaises(m.Refusal):
                b.add(1)


    def test_resource_budgets(self):
        with tempfile.TemporaryDirectory() as tmp:
            b=m.Budget(Path(tmp));disk=type('Disk',(),{'free':5*m.GIB})
            with patch.object(m.shutil,'disk_usage',return_value=disk):
                b.check();b.downloaded=m.GIB
                with self.assertRaises(m.Refusal):b.check()
                b.downloaded=0;b.start-=m.MAX_SECONDS
                with self.assertRaises(m.Refusal):b.check()
            b=m.Budget(Path(tmp));disk.free=4*m.GIB-1
            with patch.object(m.shutil,'disk_usage',return_value=disk),self.assertRaises(m.Refusal):b.check()

    def test_receipt_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);f=p/'receipt.json';f.write_text('{}');m.validate_receipt(p)
            f.write_bytes(b' '*65537)
            with self.assertRaises(m.Refusal):m.validate_receipt(p)
            f.write_text('{}');(p/'secret.txt').write_text('not real')
            with self.assertRaises(m.Refusal):m.validate_receipt(p)
            (p/'secret.txt').unlink();f.unlink();f.symlink_to('/etc/hosts')
            with self.assertRaises(m.Refusal):m.validate_receipt(p)

    def test_local_execution_refuses_before_file_or_network_access(self):
        with patch.object(m,'HTTP') as network:
            with self.assertRaisesRegex(m.Refusal,'GitHub-hosted Linux only'):
                m.execute(ROOT,SOURCE,{})
            network.assert_not_called()


    def test_manifest_checksum_file_consistency(self):
        assets=m.pinned_assets(json.loads((ROOT/m.DATA/'assets.json').read_text()))
        self.assertEqual((ROOT/m.DATA/'SHA256SUMS.txt').read_text(),
                         ''.join(a['sha256']+'  '+a['name']+'\n' for a in assets))
        attribution=(ROOT/m.DATA/'ATTRIBUTION.md').read_text()
        for a in assets:
            self.assertIn(a['record'],attribution);self.assertIn(a['name'],attribution)
        self.assertIn('CC BY 4.0',attribution)

    def test_full_mocked_execution_downloads_before_writes(self):
        class StatefulAPI:
            def __init__(self, token, budget):
                self.budget=budget;self.events=[];self.release=None;self.assets=[];self.downloads=[]
                self.tag=None;self.posts=[]
            def download(self, asset, target):
                target.write_bytes(b'hello');self.budget.add(5);self.downloads.append(asset['name'])
            def request(self, method, path, payload=None, upload=None):
                self.events.append(dict(method=method,path=path,status=200))
                if method=='POST':
                    assert len(self.downloads)==2, 'write before both verified downloads'
                    self.posts.append(path)
                    if upload is None:
                        self.release=dict(id=12,html_url='https://github.com/'+m.REPO+'/releases/tag/'+m.TAG,**payload)
                        self.tag=dict(object=dict(type='commit',sha=ACT))
                        return self.release
                    a=remote_asset(expected(upload.stream.read(),upload.path.name));a['id']=19+len(self.assets)
                    self.assets.append(a);return a
                if path==m.PREFIX:return dict(full_name=m.REPO,private=False,default_branch='master')
                if path.endswith('/heads/master'):return dict(object=dict(sha=ACT))
                if path.endswith('/git/ref/tags/'+m.TAG):
                    if self.tag is None:raise m.RemoteError(404)
                    return self.tag
                if path.endswith('/releases/tags/'+m.TAG):
                    if self.release is None:raise m.RemoteError(404)
                    return self.release
                if path.endswith('/assets?per_page=100'):return self.assets
                if '/releases/assets/' in path:return next(a for a in self.assets if str(a['id'])==path.rsplit('/',1)[1])
                raise AssertionError(path)
        with tempfile.TemporaryDirectory() as tmp:
            base=Path(tmp);eventpath=base/'event.json';env,event=env_event();eventpath.write_text(json.dumps(event))
            env.update(GITHUB_WORKSPACE=str(base),RUNNER_TEMP=str(base),GITHUB_EVENT_PATH=str(eventpath),
                       GITHUB_RUN_ID='12345',GITHUB_TOKEN='fake-token')
            tiny=[expected(name='one.tar.gz'),expected(name='two.tar.gz')]
            disk=type('Disk',(),{'free':8*m.GIB})
            instances=[]
            def factory(*args):
                api=StatefulAPI(*args);instances.append(api);return api
            with patch.object(m,'check_source',return_value=ROOT),patch.object(m,'pinned_assets',return_value=tiny),\
                 patch.object(m.shutil,'disk_usage',return_value=disk),patch.object(m,'HTTP',side_effect=factory):
                receipt=m.execute(ROOT,SOURCE,env)
            self.assertTrue(receipt['success']);self.assertEqual(len(receipt['assets']),5)
            self.assertEqual(receipt['downloadedBytes'],10);self.assertEqual(len(instances[0].posts),6)
            m.validate_receipt(m.receipt_dir(env))
            self.assertNotIn('fake-token', (m.receipt_dir(env)/'receipt.json').read_text())


    def test_workflow_is_inert_and_scoped(self):
        text=(ROOT/'.github/workflows/navigation-test-data-release.yml').read_text()
        self.assertIn('if: ${{ false }}',text);self.assertIn('SOURCE_REVISION: UNACTIVATED',text)
        self.assertNotIn('  push:',text);self.assertNotIn('pull_request',text);self.assertIn('timeout-minutes: 15',text)
        self.assertIn('persist-credentials: false',text);self.assertIn('path: pinned-source',text)
        self.assertEqual(text.count('contents: write'),1);self.assertNotIn('secrets.',text)
        self.assertIn("steps.receipt_guard.outcome == 'success'",text)

if __name__ == '__main__': unittest.main(verbosity=2)

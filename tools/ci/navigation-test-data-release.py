#!/usr/bin/env python3
"""One-shot, pinned public dataset release transfer. No extraction or execution."""
import argparse
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import time
from urllib.parse import quote, urlsplit

REPO = 'mischa23v/blind'
TAG = 'navigation-test-data-20261026'
TITLE = 'Experimental navigation test data — Koivu (2026-10-26)'
PREFIX = '/repos/' + REPO
DATA = 'research/evaluations/navigation-test-data-release'
SCRIPT = 'tools/ci/navigation-test-data-release.py'
GIB = 1024 ** 3
MAX_JSON = 2 * 1024 ** 2
MAX_SECONDS = 14 * 60
ALLOWLIST = (
    ('10230733', 'koivu_iphone.tar.gz', 146575749,
     '68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518'),
    ('10222321', 'koivu_mesh_pd.tar.gz', 455583916,
     'e16605f237f0850fd069fb9aca39d300eb1aa3a3b1f5f3f660cb64230a91dd26'),
)

class Refusal(Exception):
    pass

class IntegrityChanged(Refusal):
    pass

class RemoteError(Exception):
    def __init__(self, status):
        self.status = status
        super().__init__('remote status ' + str(status))

def require(ok, code):
    if not ok:
        raise Refusal(code)

def sha(data):
    return hashlib.sha256(data).hexdigest()

def marker(source):
    return '[navigation-test-data-' + source[:7] + '-once]'

def source_url(record, name):
    return 'https://zenodo.org/api/records/' + record + '/files/' + name + '/content'

def pinned_assets(manifest):
    expected = [{'record': r, 'name': n, 'bytes': b, 'sha256': s,
                 'url': source_url(r, n), 'license': 'CC-BY-4.0'} for r,n,b,s in ALLOWLIST]
    require(manifest == expected, 'asset allowlist mismatch')
    require(sum(a['bytes'] for a in manifest) < GIB, 'download cap')
    require(all(a['bytes'] < 2 * GIB for a in manifest), 'individual asset cap')
    return manifest

def check_event(env, event, source):
    require(re.fullmatch('[0-9a-f]{40}', source) is not None, 'immutable source SHA required')
    require(env.get('GITHUB_ACTIONS') == 'true' and env.get('RUNNER_ENVIRONMENT') == 'github-hosted'
            and env.get('RUNNER_OS') == 'Linux', 'GitHub-hosted Linux only')
    require(env.get('GITHUB_REPOSITORY') == REPO and env.get('GITHUB_REF') == 'refs/heads/master'
            and env.get('GITHUB_RUN_ATTEMPT') == '1' and env.get('GITHUB_EVENT_NAME') == 'push',
            'repository event attempt guard')
    require(env.get('GITHUB_SERVER_URL') == 'https://github.com'
            and env.get('GITHUB_API_URL') == 'https://api.github.com', 'GitHub origin guard')
    activation = env.get('GITHUB_SHA', '')
    require(re.fullmatch('[0-9a-f]{40}', activation) is not None, 'activation SHA required')
    require(event.get('repository', {}).get('full_name') == REPO
            and event.get('repository', {}).get('private') is False, 'public repository required')
    require(event.get('ref') == 'refs/heads/master' and event.get('after') == activation
            and event.get('head_commit', {}).get('id') == activation
            and marker(source) in event.get('head_commit', {}).get('message', '')
            and event.get('deleted') is False and event.get('forced') is False,
            'explicit one-shot activation required')
    return activation

def check_source(source, expected, workspace):
    source = source.resolve()
    require(source.is_relative_to(workspace.resolve()) and source != workspace.resolve(), 'source checkout containment')
    require(Path(__file__).resolve() == source / SCRIPT, 'execute pinned checkout script')
    actual = subprocess.check_output(['git','rev-parse','HEAD'], cwd=source, text=True, timeout=10).strip()
    require(actual == expected, 'source HEAD mismatch')
    clean = subprocess.check_output(['git','status','--porcelain','--untracked-files=all'], cwd=source,
                                    text=True, timeout=10)
    require(not clean, 'source checkout modified')
    return source

def release_body(source, activation, attribution):
    return (attribution.rstrip() + '\n\nUploader source: `' + source + '`.\n'
            'Release tag/activation: `' + activation + '`.\n'
            'Unchanged official archive mirrors; no extraction or dataset execution by this job.\n'
            'These are experimental test inputs, not an app release or evidence of safe navigation.\n')

class Budget:
    def __init__(self, work):
        self.work = work
        self.start = time.monotonic()
        self.downloaded = 0
    def check(self):
        require(time.monotonic() - self.start < MAX_SECONDS, 'time budget exceeded')
        require(shutil.disk_usage(self.work).free >= 4 * GIB, '4 GiB free reserve violated')
        require(self.downloaded < GIB, 'download budget exceeded')
    def reserve(self, count):
        require(shutil.disk_usage(self.work).free >= 4 * GIB + count, 'pending write violates 4 GiB reserve')
    def add(self, count):
        self.reserve(count)
        self.downloaded += count
        self.check()

class VerifiedUpload:
    def __init__(self, path, stream, identity, size):
        self.path, self.stream, self.identity, self.size = path, stream, identity, size
    def check(self):
        try:
            current = os.stat(self.path, follow_symlinks=False)
            descriptor = os.fstat(self.stream.fileno())
        except OSError as error:
            raise IntegrityChanged('verified upload file became unavailable') from error
        if not (stat.S_ISREG(current.st_mode) and stat.S_ISREG(descriptor.st_mode)
                and file_identity(current) == self.identity and file_identity(descriptor) == self.identity):
            raise IntegrityChanged('verified upload file changed')

def file_identity(value):
    return (value.st_dev, value.st_ino, value.st_size, value.st_mtime_ns, value.st_ctime_ns)

@contextmanager
def verified_upload(path, expected):
    require(path.is_file() and not path.is_symlink(), 'local upload file size/type')
    descriptor = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(descriptor, 'rb') as stream:
        info = os.fstat(stream.fileno())
        require(stat.S_ISREG(info.st_mode) and info.st_size == expected['bytes'], 'local upload file size/type')
        identity = file_identity(info)
        digest = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 ** 2), b''):
            digest.update(block)
        require(digest.hexdigest() == expected['sha256'], 'local upload checksum mismatch')
        stream.seek(0)
        upload = VerifiedUpload(path, stream, identity, expected['bytes'])
        upload.check()
        yield upload


class HTTP:
    """No redirects, proxy use, cookies, automatic retries, response-body logs or dynamic hosts."""
    def __init__(self, token, budget):
        self.token = token
        self.budget = budget
        self.events = []
    def request(self, method, path, payload=None, upload=None):
        self.budget.check()
        require(method in ('GET', 'POST') and (path == PREFIX or path.startswith(PREFIX + '/')), 'API scope')
        require(not any(c in path for c in '\r\n#'), 'API path characters')
        host = 'uploads.github.com' if upload is not None else 'api.github.com'
        if upload is not None:
            upload.check()
        conn = http.client.HTTPSConnection(host, timeout=90)
        headers = {'Accept':'application/vnd.github+json', 'Authorization':'Bearer ' + self.token,
                   'X-GitHub-Api-Version':'2022-11-28', 'User-Agent':'blind-test-data-mirror'}
        body = None
        record = {'method':method, 'host':host, 'path':path, 'status':'unresolved'}
        self.events.append(record)
        try:
            if upload is not None:
                require(method == 'POST' and re.fullmatch(re.escape(PREFIX) + r'/releases/[0-9]+/assets\?name=[A-Za-z0-9_.-]+', path), 'upload endpoint')
                headers.update({'Content-Type':'application/octet-stream', 'Content-Length':str(upload.size)})
                conn.request(method, path, body=upload.stream, headers=headers)
                upload.check()
            else:
                if payload is not None:
                    body = json.dumps(payload).encode()
                    headers['Content-Type'] = 'application/json'
                conn.request(method, path, body=body, headers=headers)
            response = conn.getresponse()
            record['status'] = response.status
            raw = response.read(MAX_JSON + 1)
            if len(raw) > MAX_JSON:
                raise RemoteError('API JSON response cap')
            if response.status not in (200, 201):
                raise RemoteError(response.status)
            return json.loads(raw)
        finally:
            conn.close()

    def download(self, asset, target):
        require(asset in pinned_assets(json.loads((self.source / DATA / 'assets.json').read_text())), 'download not allowlisted')
        parsed = urlsplit(asset['url'])
        require(parsed.scheme == 'https' and parsed.netloc == 'zenodo.org' and not parsed.query, 'official origin only')
        self.budget.check()
        conn = http.client.HTTPSConnection('zenodo.org', timeout=90)
        digest = hashlib.sha256()
        count = 0
        try:
            # Deliberately unauthenticated; GitHub token never goes to data providers.
            conn.request('GET', parsed.path, headers={'User-Agent':'blind-test-data-mirror', 'Accept-Encoding':'identity'})
            response = conn.getresponse()
            require(response.status == 200, 'official download HTTP status (redirects forbidden)')
            require(response.getheader('Content-Encoding', 'identity') == 'identity', 'unexpected content encoding')
            length = response.getheader('Content-Length')
            require(length is None or length == str(asset['bytes']), 'download content length mismatch')
            with target.open('xb') as output:
                while True:
                    block = response.read(min(1024 ** 2, asset['bytes'] - count + 1))
                    if not block:
                        break
                    count += len(block)
                    self.budget.add(len(block))
                    require(count <= asset['bytes'], 'download byte overflow')
                    output.write(block)
                    output.flush()
                    self.budget.check()
                    digest.update(block)
            require(count == asset['bytes'] and digest.hexdigest() == asset['sha256'], 'download checksum mismatch')
        finally:
            conn.close()

def optional_get(api, path):
    try:
        return api.request('GET', path)
    except RemoteError as error:
        if error.status == 404:
            return None
        raise

def reconcile(fetch, description, sleep=time.sleep):
    # GET-only eventual-consistency reconciliation. A POST is never automatically repeated.
    for delay in (0, 1, 2, 4, 8):
        if delay:
            sleep(delay)
        try:
            result = fetch()
            if result is not None:
                return result
        except (RemoteError, OSError, http.client.HTTPException, json.JSONDecodeError):
            pass
    raise Refusal(description + ' outcome unresolved; no repeated write')

def validate_release(release, body):
    require(type(release.get('id')) is int and release['id'] > 0, 'release id')
    require(release.get('tag_name') == TAG and release.get('name') == TITLE
            and release.get('draft') is False and release.get('prerelease') is True
            and release.get('body') == body and release.get('immutable') is not True,
            'release metadata conflict')
    require(release.get('html_url') == 'https://github.com/' + REPO + '/releases/tag/' + TAG,
            'release URL conflict')
    return release

def check_tag(api, activation):
    ref = optional_get(api, PREFIX + '/git/ref/tags/' + TAG)
    if ref is not None:
        require(ref.get('object', {}).get('type') == 'commit'
                and ref.get('object', {}).get('sha') == activation, 'existing tag target conflict')
    return ref

def ensure_release(api, body, activation, sleep=time.sleep):
    path = PREFIX + '/releases/tags/' + TAG
    release = optional_get(api, path)
    check_tag(api, activation)
    if release is None:
        payload = {'tag_name':TAG, 'target_commitish':activation, 'name':TITLE, 'body':body,
                   'draft':False, 'prerelease':True, 'make_latest':'false', 'generate_release_notes':False}
        try:
            api.request('POST', PREFIX + '/releases', payload=payload)
        except (RemoteError, OSError, http.client.HTTPException, json.JSONDecodeError):
            pass
        release = reconcile(lambda: optional_get(api, path), 'release creation', sleep)
    validate_release(release, body)
    require(check_tag(api, activation) is not None, 'release tag absent')
    return release

def asset_by_name(api, release_id, name):
    assets = api.request('GET', PREFIX + '/releases/' + str(release_id) + '/assets?per_page=100')
    require(isinstance(assets, list) and len(assets) < 100, 'asset listing bound')
    matches = [a for a in assets if a.get('name') == name]
    require(len(matches) <= 1, 'duplicate remote asset name')
    if not matches:
        return None
    require(type(matches[0].get('id')) is int and matches[0]['id'] > 0, 'asset id')
    return api.request('GET', PREFIX + '/releases/assets/' + str(matches[0]['id']))

def validate_asset(remote, expected):
    require(type(remote.get('id')) is int and remote['id'] > 0, 'remote asset id')
    require(remote.get('name') == expected['name'] and remote.get('size') == expected['bytes']
            and remote.get('state') == 'uploaded' and remote.get('digest') == 'sha256:' + expected['sha256'],
            'remote asset digest/size/state conflict')
    require(remote.get('browser_download_url') == 'https://github.com/' + REPO + '/releases/download/' + TAG + '/' + expected['name'],
            'remote download URL conflict')
    return {k:remote[k] for k in ('id','name','size','state','digest','browser_download_url')}

def validate_inventory(api, release_id, expected, complete=False):
    assets = api.request('GET', PREFIX + '/releases/' + str(release_id) + '/assets?per_page=100')
    require(isinstance(assets, list) and len(assets) < 100, 'asset listing bound')
    names = [a.get('name') for a in assets]
    wanted = {a['name'] for a in expected}
    require(len(names) == len(set(names)) and set(names) <= wanted, 'unexpected or duplicate remote assets')
    require(not complete or set(names) == wanted, 'incomplete remote inventory')


def ensure_asset(api, release_id, expected, path, sleep=time.sleep):
    current = asset_by_name(api, release_id, expected['name'])
    if current is not None:
        return validate_asset(current, expected)
    local_error = None
    with verified_upload(path, expected) as upload:
        try:
            api.request('POST', PREFIX + '/releases/' + str(release_id) + '/assets?name=' + quote(expected['name'], safe=''), upload=upload)
        except IntegrityChanged as error:
            # A post-send integrity refusal may have happened after bytes reached GitHub.
            # Reconcile read-only, but never turn that local refusal into successful transfer.
            local_error = error
        except (RemoteError, OSError, http.client.HTTPException, json.JSONDecodeError):
            pass
    remote = reconcile(lambda: asset_by_name(api, release_id, expected['name']), 'asset upload', sleep)
    result = validate_asset(remote, expected)
    if local_error is not None:
        raise local_error
    return result

def receipt_dir(env):
    run = env.get('GITHUB_RUN_ID', '')
    require(re.fullmatch('[0-9]+', run) is not None, 'run ID')
    return Path(env['RUNNER_TEMP']) / ('blind-test-data-' + run + '-1') / 'receipt'

def validate_receipt(path):
    require(path.is_dir() and not path.is_symlink(), 'receipt missing/type')
    files = list(path.iterdir())
    require(len(files) == 1 and files[0].name == 'receipt.json' and not files[0].is_symlink()
            and files[0].is_file() and files[0].stat().st_size <= 65536, 'receipt allowlist/cap')
    json.loads(files[0].read_text())

def execute(source, expected, env):
    require(env.get('GITHUB_ACTIONS') == 'true' and env.get('RUNNER_ENVIRONMENT') == 'github-hosted'
            and env.get('RUNNER_OS') == 'Linux', 'GitHub-hosted Linux only')
    event = json.loads(Path(env['GITHUB_EVENT_PATH']).read_text())
    activation = check_event(env, event, expected)
    source = check_source(source, expected, Path(env['GITHUB_WORKSPACE']))
    assets = pinned_assets(json.loads((source / DATA / 'assets.json').read_text()))
    token = env.get('GITHUB_TOKEN', '')
    require(bool(token) and not any(c.isspace() for c in token), 'ephemeral token unavailable')
    destination = receipt_dir(env)
    work = destination.parent
    require(not work.exists(), 'fresh owned work directory required')
    require(shutil.disk_usage(work.parent).free >= 4 * GIB + sum(a['bytes'] for a in assets) + MAX_JSON,
            'insufficient preflight disk reserve')
    destination.mkdir(parents=True)
    receipt = {'schema':1, 'repository':REPO, 'tag':TAG, 'sourceRevision':expected,
               'activationRevision':activation, 'success':False, 'phase':'preflight', 'assets':[]}
    budget = Budget(work)
    api = HTTP(token, budget)
    api.source = source
    try:
        repo = api.request('GET', PREFIX)
        require(repo.get('full_name') == REPO and repo.get('private') is False
                and repo.get('default_branch') == 'master', 'remote public repository guard')
        head = api.request('GET', PREFIX + '/git/ref/heads/master')
        require(head.get('object', {}).get('sha') == activation, 'activation is no longer master')
        attribution = (source / DATA / 'ATTRIBUTION.md').read_text()
        body = release_body(expected, activation, attribution)
        receipt['phase'] = 'official downloads'
        for asset in assets:
            api.download(asset, work / asset['name'])
        # Small attribution/checksum/manifest release assets are source-pinned, never downloaded.
        for name in ('ATTRIBUTION.md', 'SHA256SUMS.txt', 'assets.json'):
            data = (source / DATA / name).read_bytes()
            require(len(data) <= 65536, 'release metadata size cap')
            path = work / name
            budget.reserve(len(data))
            path.write_bytes(data)
            budget.check()
            assets.append({'name':name, 'bytes':len(data), 'sha256':sha(data)})
        receipt['phase'] = 'release creation/reconciliation'
        # Check default branch again immediately before the one possible release creation.
        require(api.request('GET', PREFIX + '/git/ref/heads/master').get('object', {}).get('sha') == activation,
                'activation is no longer master')
        release = ensure_release(api, body, activation)
        receipt['releaseID'] = release['id']
        receipt['releaseURL'] = release['html_url']
        validate_inventory(api, release['id'], assets)
        receipt['phase'] = 'asset upload/reconciliation'
        for asset in assets:
            receipt['assets'].append(ensure_asset(api, release['id'], asset, work / asset['name']))
        validate_release(api.request('GET', PREFIX + '/releases/tags/' + TAG), body)
        require(check_tag(api, activation) is not None, 'release tag absent')
        validate_inventory(api, release['id'], assets, complete=True)
        for asset in assets:
            validate_asset(asset_by_name(api, release['id'], asset['name']), asset)
        receipt['phase'] = 'complete'
        receipt['success'] = True
    except Exception as error:
        receipt['error'] = str(error) if isinstance(error, Refusal) else type(error).__name__
        raise
    finally:
        receipt['requests'] = api.events
        receipt['downloadedBytes'] = budget.downloaded
        receipt['elapsedSeconds'] = round(time.monotonic() - budget.start, 3)
        (destination / 'receipt.json').write_text(json.dumps(receipt, indent=2) + '\n')
    return receipt

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path)
    parser.add_argument('--expected-source')
    parser.add_argument('--validate-receipt', action='store_true')
    args = parser.parse_args()
    try:
        if args.validate_receipt:
            validate_receipt(receipt_dir(os.environ))
            return 0
        require(args.source is not None and args.expected_source is not None, 'explicit pinned source required')
        signal.signal(signal.SIGALRM, lambda *_: (_ for _ in ()).throw(Refusal('wall deadline exceeded')))
        signal.alarm(MAX_SECONDS)
        result = execute(args.source, args.expected_source, os.environ)
        print(json.dumps({'success':result['success'], 'releaseURL':result['releaseURL'], 'assetCount':len(result['assets'])}))
        return 0
    except Exception as error:
        # Never print remote bodies, request headers, credentials or exception text from transports.
        code = str(error) if isinstance(error, Refusal) else type(error).__name__
        print('REFUSED: ' + code, file=sys.stderr)
        return 1

if __name__ == '__main__':
    sys.exit(main())

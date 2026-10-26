"""Read-only consistency validation; no network, installation or native import."""
from pathlib import Path
import hashlib,json
from packaging.requirements import Requirement
from packaging.version import Version
from packaging.specifiers import SpecifierSet
from packaging.utils import parse_wheel_filename,canonicalize_name
from packaging.tags import sys_tags

ROOT=Path(__file__).resolve().parent
def read(name):return json.loads((ROOT/name).read_text())
def sha(data):return hashlib.sha256(data).hexdigest()
d=read('DEPENDENCY_CLOSURE.json');a=read('ACQUISITION_PROPOSAL.json');l=read('FETCH_LEDGER.json')
packages={r['name']:r for r in d['packages']};env={**d['platformMarkers'],'extra':''}
assert len(packages)==74 and sum(r['reuseInstalled'] for r in packages.values())==46
assert len(a['artifacts'])==28
active_edges=0
for name,r in packages.items():
    if r['requiresPython']:assert Version(env['python_full_version']) in SpecifierSet(r['requiresPython'])
    for text in r['requires']:
        req=Requirement(text)
        if req.marker is None or req.marker.evaluate(env):
            assert not req.extras
            dependency=packages[canonicalize_name(req.name)]
            assert Version(dependency['version']) in req.specifier,(name,text)
            active_edges+=1
for row in a['artifacts']:
    r=packages[row['name']];w=r['wheel'];iv=r['inventory']
    assert row['bytes']==w['size'] and row['sha256']==w['digests']['sha256']
    assert row['uncompressedBytes']==sum(m['expandedBytes'] for m in iv['members'])
    _,version,_,tags=parse_wheel_filename(row['filename'])
    assert version==Version(row['version']) and set(tags).intersection(sys_tags())
    assert row['url'].startswith('https://files.pythonhosted.org/')
    assert iv['entries']==len(iv['members'])
assert sum(r['bytes'] for r in a['artifacts'])==d['archiveBytes']==a['totalBytes']==121400340
assert sum(r['uncompressedBytes'] for r in a['artifacts'])==d['declaredExpandedBytes']==a['uncompressedBytes']==368764121
assert sum(r['bytes'] for r in l)==d['metadataTransferredBytes']==1406414<5*1024**2
for row in l:
    raw=(ROOT/'metadata'/row['cache']).read_bytes()
    assert len(raw)==row['bytes'] and sha(raw)==row['sha256']
    if row['range']:assert row['status']==206 and row['kind'].startswith('ZIP ')
    else:assert row['url'].endswith('/json') or row['url'].endswith('.metadata')
assert all(d[k]==0 for k in ['fullWheelDownloads','installations','nativeImports'])
assert not any(n.startswith(('torch','nvidia','cuda')) for n in packages)
assert packages['numpy']['reuseInstalled'] and packages['numpy']['version']=='2.3.5'
print(f'Validated 74-package closure / {active_edges} active requirement edges; 46 installed reused; 28 official wheel identities and central inventories. No install, import or network.')

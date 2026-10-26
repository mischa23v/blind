"""Metadata-only fixed-candidate dependency proposal; no install or full wheel fetch."""
from pathlib import Path
import sys, json, hashlib, urllib.request, urllib.parse, struct, importlib.metadata as im
from dataclasses import dataclass
from concurrent.futures import ThreadPoolExecutor
from threading import Lock
FETCH_LOCK=Lock()
from packaging.requirements import Requirement
from packaging.version import Version
from packaging.specifiers import SpecifierSet
from packaging.utils import canonicalize_name, parse_wheel_filename
from packaging.tags import sys_tags
from packaging.markers import default_environment
from pip._vendor.resolvelib import Resolver, BaseReporter
from pip._vendor.resolvelib.providers import AbstractProvider

ROOT=Path(__file__).resolve().parent
CACHE=ROOT/'metadata';CACHE.mkdir(exist_ok=True)
CAP=5*1024**2
# Deliberately bounded compatible release proposal, not a claim to latest versions.
PINS={'open3d-cpu':'0.19.0','dash':'3.2.0','plotly':'6.3.1','flask':None,'werkzeug':None,
 'nbformat':'5.10.4','configargparse':'1.7.1','ipywidgets':'8.1.7','addict':'2.4.0',
 'tqdm':'4.67.1','pyquaternion':'0.9.9','requests':None,'jinja2':'3.1.6','markupsafe':'3.0.3',
 'itsdangerous':'2.2.0','blinker':'1.9.0','nest-asyncio':'1.6.0','retrying':'1.4.2',
 'importlib-metadata':'8.7.0','zipp':'3.23.0','narwhals':'2.7.0','comm':'0.2.3',
 'widgetsnbextension':'4.0.14','jupyterlab-widgets':'3.0.15','fastjsonschema':'2.21.2',
 'jupyter-core':'5.8.1','platformdirs':'4.4.0','urllib3':None}
env=default_environment();tags=list(sys_tags());tag_order={t:i for i,t in enumerate(tags)}
ledger= json.loads((ROOT/'FETCH_LEDGER.json').read_text()) if (ROOT/'FETCH_LEDGER.json').exists() else []

def sha(b):return hashlib.sha256(b).hexdigest()
def write(name,data): (ROOT/name).write_text(json.dumps(data,indent=2,sort_keys=True)+'\n')
def fetch(url,kind,byte_range=None):
    assert urllib.parse.urlparse(url).hostname in {'pypi.org','files.pythonhosted.org'}
    key=sha((url+' '+str(byte_range)).encode());path=CACHE/(key+'.bin')
    if path.exists():
        row=next(x for x in ledger if x['cache']==path.name)
        body=path.read_bytes();assert sha(body)==row['sha256'];return body
    remaining=CAP-sum(x['bytes'] for x in ledger)
    if remaining<=0:raise RuntimeError('metadata budget exhausted')
    headers={'User-Agent':'bounded-open3d-dependency-metadata-audit/1','Accept-Encoding':'identity'}
    if byte_range:headers['Range']='bytes='+byte_range
    with urllib.request.urlopen(urllib.request.Request(url,headers=headers),timeout=30) as response:
        assert urllib.parse.urlparse(response.url).hostname in {'pypi.org','files.pythonhosted.org'}
        if byte_range:assert response.status==206, 'server ignored Range; refused full wheel'
        else:assert response.status==200
        with FETCH_LOCK:
            remaining=CAP-sum(x['bytes'] for x in ledger)
            length=int(response.headers.get('Content-Length',remaining+1))
            assert length<=remaining, ('metadata cap',length,remaining)
            if byte_range and not byte_range.startswith('-'):
                a,b=map(int,byte_range.split('-'));assert length==b-a+1
            body=response.read(length+1);assert len(body)==length
            row={'url':url,'kind':kind,'range':byte_range,'status':response.status,
                 'contentRange':response.headers.get('Content-Range'),'bytes':len(body),
                 'sha256':sha(body),'cache':path.name}
            path.write_bytes(body);ledger.append(row);write('FETCH_LEDGER.json',ledger)
    return body

installed={canonicalize_name(d.metadata['Name']):d for d in im.distributions()}
@dataclass(frozen=True)
class Candidate:
    name:str
    version:Version
    reused:bool

records={}
def load_candidate(name):
    if name in records:return records[name]['candidate']
    if name in installed:
        d=installed[name];c=Candidate(name,Version(d.version),True)
        requires=d.requires or [];meta=d.read_text('METADATA') or ''
        records[name]={'candidate':c,'requires':requires,'installedMetadataSHA256':sha(meta.encode()),
                       'requiresPython':d.metadata.get('Requires-Python'),
                       'license':d.metadata.get('License-Expression') or d.metadata.get('License'),
                       'wheel':None}
        return c
    if name not in PINS:raise RuntimeError('Unreviewed missing dependency: '+name)
    version=PINS[name];url='https://pypi.org/pypi/'+name+('/'+version if version else '')+'/json'
    data=json.loads(fetch(url,'official PyPI release JSON'))
    info=data['info'];version=info['version'];c=Candidate(name,Version(version),False)
    if data.get('vulnerabilities'):raise RuntimeError('PyPI advisory blocks proposed version '+name+' '+version+': '+str(data['vulnerabilities']))
    wheels=[]
    for f in data['urls']:
        if f['packagetype']!='bdist_wheel' or f['yanked']:continue
        _,v,_,ftags=parse_wheel_filename(f['filename'])
        compatible=[tag_order[t] for t in ftags if t in tag_order]
        if compatible and (not f['requires_python'] or Version(env['python_full_version']) in SpecifierSet(f['requires_python'])):
            wheels.append((min(compatible),f))
    if not wheels:raise RuntimeError('No compatible non-yanked wheel for '+name+' '+version)
    wheel=min(wheels,key=lambda x:(x[0],x[1]['filename']))[1]
    records[name]={'candidate':c,'requires':info.get('requires_dist') or [],'requiresPython':info['requires_python'],
                  'license':info.get('license_expression') or info.get('license'),
                  'releaseJSON':url,'wheel':wheel,'metadataVerified':False}
    return c

class Provider(AbstractProvider):
    def identify(self,requirement_or_candidate):return canonicalize_name(requirement_or_candidate.name)
    def get_preference(self,identifier,resolutions,candidates,information,backtrack_causes):return identifier
    def find_matches(self,identifier,requirements,incompatibilities):
        rs=list(requirements[identifier]);assert not any(r.extras for r in rs),'extras require explicit provider extension'
        c=load_candidate(identifier)
        return [c] if c not in incompatibilities[identifier] and all(self.is_satisfied_by(r,c) for r in rs) else []
    def is_satisfied_by(self,requirement,candidate):return candidate.version in requirement.specifier
    def get_dependencies(self,candidate):
        rec=records[candidate.name]
        if rec['requiresPython'] and Version(env['python_full_version']) not in SpecifierSet(rec['requiresPython']):
            raise RuntimeError('Requires-Python mismatch '+candidate.name)
        rs=[Requirement(s) for s in rec['requires']]
        return [r for r in rs if r.marker is None or r.marker.evaluate({**env,'extra':''})]

def wheel_inventory(wheel):
    url=wheel['url'];tail=fetch(url,'ZIP EOCD only','-22')
    if tail[:4]!=b'PK\x05\x06':
        tail=fetch(url,'ZIP EOCD search only','-65557');offset=tail.rfind(b'PK\x05\x06')
        assert offset>=0;tail=tail[offset:]
    signature,disk,cd_disk,disk_entries,entries,cd_size,cd_offset,comment=struct.unpack('<4s4H2LH',tail[:22])
    assert disk==cd_disk==0 and disk_entries==entries and entries<65535
    assert cd_size<2**32-1 and cd_offset<2**32-1 and len(tail)==22+comment
    assert cd_offset+cd_size+len(tail)==wheel['size']
    central=fetch(url,'ZIP central directory only',f'{cd_offset}-{cd_offset+cd_size-1}')
    cursor=0;files=[]
    while cursor<len(central):
        v=struct.unpack_from('<4s6H3L5H2L',central,cursor);assert v[0]==b'PK\x01\x02'
        flag,method,compressed,expanded=v[3],v[4],v[8],v[9];n,e,c=v[10:13]
        name=central[cursor+46:cursor+46+n].decode('utf-8' if flag&0x800 else 'cp437')
        assert method in {0,8} and not flag&1
        assert not name.startswith('/') and '..' not in Path(name).parts and '\\' not in name
        assert compressed<2**32-1 and expanded<2**32-1
        files.append({'name':name,'compressedBytes':compressed,'expandedBytes':expanded,'method':method})
        cursor+=46+n+e+c
    assert cursor==len(central) and len(files)==entries
    return {'entries':entries,'declaredExpandedBytes':sum(f['expandedBytes'] for f in files),
            'centralDirectoryBytes':cd_size,'centralDirectorySHA256':sha(central),'members':files,
            'meaning':'Range metadata only; not verified full archive SHA or extracted bytes.'}

def describe(item):
    name,candidate=item
    rec=records[name];row={'name':name,'version':str(candidate.version),'reuseInstalled':candidate.reused,
                         'requires':rec['requires'],'activeRequirements':[str(r) for r in Provider().get_dependencies(candidate)],
                         'requiresPython':rec['requiresPython'],'license':rec['license']}
    if candidate.reused:row['installedMetadataSHA256']=rec['installedMetadataSHA256']
    else:
        wheel=rec['wheel'];metadata=wheel.get('core-metadata') or wheel.get('dist-info-metadata')
        if metadata:
            raw=fetch(wheel['url']+'.metadata','PEP 658 wheel metadata')
            if isinstance(metadata,dict):assert sha(raw)==metadata['sha256']
            from email.parser import BytesParser
            m=BytesParser().parsebytes(raw)
            assert canonicalize_name(m['Name'])==name and Version(m['Version'])==candidate.version
            assert sorted(str(Requirement(x)) for x in m.get_all('Requires-Dist',[]))==sorted(str(Requirement(x)) for x in rec['requires']), 'JSON and wheel semantic requirements differ'
            row['wheelMetadataSHA256']=sha(raw)
        else:row['wheelMetadataUnavailable']=True
        row['releaseJSON']=rec['releaseJSON']
        row['wheel']={k:wheel[k] for k in ['filename','url','size','digests','upload_time_iso_8601']}
        row['inventory']=wheel_inventory(wheel)
    print(name,str(candidate.version),'installed' if candidate.reused else 'metadata verified',flush=True)
    return row

if __name__=='__main__':
    with ThreadPoolExecutor(max_workers=8) as pool:
        for c in pool.map(load_candidate,[n for n in PINS if n not in installed]):
            print('CANDIDATE',c.name,str(c.version),flush=True)
    result=Resolver(Provider(),BaseReporter()).resolve([Requirement('open3d-cpu==0.19.0')],max_rounds=200)
    quick=[]
    for name,c in sorted(result.mapping.items()):
        rec=records[name]
        if not c.reused:
            w=rec['wheel'];quick.append({'name':name,'version':str(c.version),'filename':w['filename'],'url':w['url'],'sha256':w['digests']['sha256'],'bytes':w['size'],'requiresDist':rec['requires'],'reusedInstalled':False})
    write('RESOLVED_ARCHIVES_PENDING_INVENTORY.json',{'artifacts':quick,'totalBytes':sum(r['bytes'] for r in quick),'resolvedPackageCount':len(result.mapping),'installedReuseCount':len(result.mapping)-len(quick),'inventoryStatus':'pending ZIP central-directory verification; no installation authorized'})
    with ThreadPoolExecutor(max_workers=8) as pool:
        selected=list(pool.map(describe,sorted(result.mapping.items())))
    missing=[r for r in selected if not r['reuseInstalled']]
    closure={'scope':'Metadata-only compatible fixed-release proposal; no install/import/full wheel fetched',
       'python':sys.version,'platformMarkers':env,'resolver':'pip._vendor.resolvelib 1.2.1 via pip '+im.version('pip'),
       'candidatePolicy':'Reuse installed compatible packages; missing packages use declared stable pins, except Flask/Werkzeug/requests/urllib3 latest PyPI release queried. No claim all packages are latest.',
       'packages':selected,'counts':{'total':len(selected),'reuseInstalled':len(selected)-len(missing),'missingWheels':len(missing)},
       'archiveBytes':sum(r['wheel']['size'] for r in missing),
       'declaredExpandedBytes':sum(r['inventory']['declaredExpandedBytes'] for r in missing),
       'metadataTransferredBytes':sum(x['bytes'] for x in ledger),'metadataPayloadCapBytes':CAP,
       'fullWheelDownloads':0,'installations':0,'nativeImports':0}
    write('DEPENDENCY_CLOSURE.json',closure)
    (ROOT/'missing-wheel-pins.txt').write_text('\n'.join(r['name']+'=='+r['version']+' --hash=sha256:'+r['wheel']['digests']['sha256'] for r in missing)+'\n')
    (ROOT/'installed-constraints.txt').write_text('\n'.join(r['name']+'=='+r['version'] for r in selected if r['reuseInstalled'])+'\n')
    print(json.dumps({k:v for k,v in closure.items() if k!='packages'},indent=2))

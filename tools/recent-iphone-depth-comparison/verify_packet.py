"""Offline publication verification only; no native replay, decoding or downloads."""
from pathlib import Path, PurePosixPath
import ast, hashlib, json, math, struct

ROOT = Path(__file__).resolve().parent
IDS = {'EM1-1093': [0,56,112,168,224,280,336,393],
       'EM1-0387': [0,12,25,37,50,62,75,88]}

def sha(data):
    return hashlib.sha256(data).hexdigest()

def read_json(path):
    return json.loads(path.read_text())

def safe_path(name):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or '\\' in name:
        raise ValueError('unsafe manifest path')
    return ROOT.joinpath(*p.parts)

def main():
    if not __debug__:
        raise RuntimeError('Run without Python optimization; assertions are required')
    manifest = read_json(ROOT/'PACKAGE_MANIFEST.json')
    listed = {x['path'] for x in manifest['files']}
    actual = {p.relative_to(ROOT).as_posix() for p in ROOT.rglob('*') if p.is_file()}
    assert actual == listed | {'PACKAGE_MANIFEST.json'}, 'unlisted or missing package file'
    assert len(listed) == len(manifest['files'])
    for row in manifest['files']:
        path = safe_path(row['path'])
        assert not path.is_symlink()
        data = path.read_bytes()
        assert len(data) == row['bytes'] and sha(data) == row['sha256'], row['path']
        # Only publication metadata is parsed; no copied script is executed/imported.
        if path.suffix == '.json' or path.name == 'metadata':
            json.loads(data)
        if path.suffix == '.py':
            ast.parse(data, filename=row['path'])
        if path.suffix in ('.json','.md','.py','.swift','.log') or path.name == 'metadata':
            for prefix in (b'/' + b'workspace' + b'/', b'/' + b'home' + b'/'):
                assert prefix not in data, 'private executor path in public text'
    mapping = read_json(ROOT/'PUBLIC_NORMALIZATION.json')
    changed = []
    for row in mapping['files']:
        data = safe_path(row['publicPath']).read_bytes()
        assert sha(data) == row['publicSHA256'] and len(data) == row['publicBytes']
        if row['transformation'] == 'byte-identical':
            assert row['originalSHA256'] == row['publicSHA256']
            assert row['originalBytes'] == row['publicBytes']
        else:
            changed.append(row['publicPath'])
    assert set(changed) == {
        'audited/EM1-0387/NATIVE_MANIFEST.json',
        'audited/EM1-1093/NATIVE_MANIFEST.json',
        'native/run/RECEIPT.json','native/run/SOURCE_DATA_PINS.json',
        'native/run/resolved-libraries.log','decoder/BUILD_RECEIPT.json'}
    assert sha((ROOT/'native/NativeCameraAudit.swift').read_bytes()) == '0346a5dc37acf4c8bc21e7042eae925ac3b7d534c13ea66575862ee82ae890ac'
    assert sha((ROOT/'native/run_native_audit.py').read_bytes()) == '1dfce365da423506b0980d19f3266029129e44240817a14cdec1bcd76c6296cb'
    assert sha((ROOT/'source-cuts/NativeDepthObservationPolicy.swift').read_bytes()) == '0e6e55ddc3321b6b89998ca43c9fcd3711ec8e54d7395ea99b6edeb52e2b6e7c'
    assert (ROOT/'source-cuts/compiled-wrapper/NativeDepthObservationPolicy.swift').read_bytes() == b'import BlindCore\n' + (ROOT/'source-cuts/NativeDepthObservationPolicy.swift').read_bytes()
    for item in read_json(ROOT/'decoder/UPSTREAM_MANIFEST.json')['files']:
        b=(ROOT/'decoder/upstream'/item['path']).read_bytes()
        assert len(b)==item['bytes'] and sha(b)==item['sha256']

    summaries=[]
    predicates={x['clipID']:x for x in read_json(ROOT/'INDEPENDENT_PREDICATE_RECHECK.json')}
    for clip, ids in IDS.items():
        base=ROOT/'audited'/clip
        field=read_json(base/'FIELD_AUDIT.json')
        native=read_json(ROOT/'native/run'/f'{clip}.json')
        metadata=read_json(base/'selected/metadata')
        assert field['frozenFrameIDs']==ids
        assert [x['frameID'] for x in native['frames']]==ids
        assert [k*(len(metadata['frameTimestamps'])-1)//7 for k in range(8)]==ids
        assert [metadata[k] for k in ('dw','dh','w','h')]==[256,192,1920,1440]
        assert native['scalarBoundaryProbesPassed']==9 and len(native['goldenProbes'])==5
        for item in field['selectedMembers']:
            p=base/'selected'/item['name'];b=p.read_bytes()
            assert len(b)==item['bytes'] and sha(b)==item['sha256']
        full=[0,0,0];admitted_total=0
        for f,n,pred in zip(field['frames'],native['frames'],predicates[clip]['frames']):
            i=f['frameID'];assert i==n['frameID']==pred['id']
            depth_bytes=(base/'decoded'/f'{i}.depth.f32le').read_bytes()
            conf=(base/'decoded'/f'{i}.confidence.u8').read_bytes()
            assert len(depth_bytes)==256*192*4 and len(conf)==256*192
            assert sha(depth_bytes)==f['depthSHA256'] and sha(conf)==f['confidenceSHA256']
            depth=struct.unpack('<49152f',depth_bytes)
            cc=[conf.count(k) for k in range(3)];assert sum(cc)==49152
            assert cc==f['originalConfidenceCounts012']
            full=[a+b for a,b in zip(full,cc)]
            buckets={'c0':0,'c1':0,'other':0,'nonfinite':0,'below':0,'above':0,'admitted':0}
            for y in range(0,192,2):
                for x in range(0,256,2):
                    j=y*256+x;c=conf[j];d=depth[j]
                    if c==0:key='c0'
                    elif c==1:key='c1'
                    elif c!=2:key='other'
                    elif not math.isfinite(d):key='nonfinite'
                    elif d<0.15:key='below'
                    elif d>5:key='above'
                    else:key='admitted'
                    buckets[key]+=1
            assert sum(buckets.values())==n['attemptedStridePixels']==12288
            for key,target in [('c0','rejectedConfidence0'),('c1','rejectedConfidence1'),('other','rejectedOtherConfidence'),('nonfinite','rejectedDepthNonfinite'),('below','rejectedDepthBelowRange'),('above','rejectedDepthAboveRange'),('admitted','scalarAdmitted')]:
                assert buckets[key]==n[target], (clip,i,key)
            assert buckets['admitted']==n['projectedPoints']==pred['admitted']
            assert n['maxRoundTripPixelResidual']<=1e-8 and n['maxRoundTripDepthResidual']<=1e-12
            admitted_total+=buckets['admitted']
        assert full==field['confidenceCounts012']
        assert admitted_total==predicates[clip]['total']['admitted']
        summaries.append({'clipID':clip,'frames':len(ids),'admitted':admitted_total,'candidates':98304})
    omitted=read_json(ROOT/'OMITTED_ARTIFACTS.json')
    assert omitted['rawArchivesIncluded'] is False
    assert not list(ROOT.rglob('*.r3d')) and not list(ROOT.rglob('*.so'))
    print(json.dumps({'status':'passed','scope':'Offline public-packet hash and saved-result reconciliation only; no native replay or new experiment','filesChecked':len(manifest['files']),'privatePathNormalizedCopies':len(changed),'clips':summaries},indent=2))

if __name__=='__main__':
    main()

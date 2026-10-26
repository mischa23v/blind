"""Prepare exact Git snapshots and only three depth frames; no downloads/installs.

Usage: python prepare_review.py --iphone-archive PATH/koivu_iphone.tar.gz
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import zipfile

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'artifacts/mapping-audit-20261026'
DIAGNOSTIC='research/tools/koivu-floor-routing-diagnostic-v1'
COMPARATOR='research/mapping-audit-opus-20261026'

def sha(p):
    h=hashlib.sha256()
    with p.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):h.update(chunk)
    return h.hexdigest()

def preserve(path,data):
    if path.exists():
        if path.read_bytes()!=data:raise ValueError('Existing file differs; preserved: '+str(path))
        return
    path.parent.mkdir(parents=True,exist_ok=True)
    with path.open('xb') as stream:stream.write(data)

def snapshot(commit,folder,subtree):
    data=subprocess.check_output(['git','-c','core.autocrlf=false','archive','--format=zip',commit,subtree],cwd=ROOT)
    destination=(BASE/folder).resolve()
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for member in archive.infolist():
            target=(destination/member.filename).resolve()
            if not target.is_relative_to(destination):raise ValueError('Archive escapes snapshot')
            if member.is_dir():continue
            preserve(target,archive.read(member))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--iphone-archive',required=True,type=Path)
    args=parser.parse_args()
    expected='68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518'
    if sha(args.iphone_archive)!=expected:raise ValueError('Original iPhone archive checksum mismatch')
    snapshot('7506ad9cd2fa171bf53cb2e1ec66628f20d4f61d','checkpoint-7506ad9',DIAGNOSTIC)
    snapshot('57fdf25f2c17b3f1cf6c5aba1156756c1e808eee','checkpoint-57fdf25',COMPARATOR)
    packet=BASE/'checkpoint-7506ad9'/DIAGNOSTIC
    manifest=json.loads((packet/'blind-koivu-game-07/map/depths/DEPTH_INPUT_MANIFEST.json').read_text())
    entries={r['file']:r for r in manifest['files'] if r['poseIndex'] in (61,62,63)}
    prefix='room_datasets/koivu/iphone/long_capture/'
    wanted={prefix+'depth/'+name:('depth/'+name,row['sha256']) for name,row in entries.items()}
    wanted[prefix+'transformations.json']=('transformations.json',manifest['poseSHA256'])
    seen=set()
    with tarfile.open(args.iphone_archive,'r:gz') as archive:
        for member in archive:
            name=member.name.removeprefix('./')
            if name not in wanted or not member.isfile():continue
            if name in seen:raise ValueError('Duplicate source member')
            data=archive.extractfile(member).read();relative,digest=wanted[name]
            if hashlib.sha256(data).hexdigest()!=digest:raise ValueError('Source member checksum mismatch')
            preserve(BASE/'prepared'/relative,data);seen.add(name)
    if seen!=set(wanted):raise ValueError('Missing source members')
    print(json.dumps({'prepared':True,'depthFrames':len(entries),'poseFiles':1,'sourceArchiveSHA256':expected,
                      'nativeLibrariesRequired':False,'fusionOrMovementExecuted':False},indent=2))

if __name__=='__main__':main()

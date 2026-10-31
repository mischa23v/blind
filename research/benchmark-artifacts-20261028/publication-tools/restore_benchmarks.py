#!/usr/bin/env python3
"""Reconstruct pinned research archives; no download or extraction."""
import argparse, hashlib, json, os, pathlib, sys, tempfile

class Invalid(ValueError): pass

def safe_input(root,name):
    relative=pathlib.PurePosixPath(name)
    if relative.is_absolute() or '..' in relative.parts or '\\' in name or str(relative)!=name: raise Invalid('unsafe path: '+name)
    candidate=root.joinpath(*relative.parts)
    if candidate.is_symlink() or not candidate.is_file() or not candidate.resolve().is_relative_to(root.resolve()): raise Invalid('missing/unsafe input: '+name)
    return candidate

def verify_hash(count,sha,git,expected):
    if (count,sha.hexdigest(),git.hexdigest())!=(expected['bytes'],expected['sha256'],expected['gitBlobSha']): raise Invalid('size/SHA-256/Git blob SHA mismatch: '+expected['repoPath'])

def reconstruct(root,out,row):
    storage=row['storage']
    if not storage['blobUploadsComplete']: raise Invalid('archive blob uploads incomplete: '+row['repoPath'])
    destination=out/pathlib.PurePosixPath(row['repoPath']).name
    if destination.exists(): raise Invalid('refusing existing destination: '+str(destination))
    total=0;sha=hashlib.sha256();git=hashlib.sha1(b'blob '+str(row['bytes']).encode()+b'\0')
    fd,temp=tempfile.mkstemp(prefix=destination.name+'.',suffix='.tmp',dir=out)
    try:
        with os.fdopen(fd,'wb') as target:
            for entry in storage['objects']:
                if not entry['blobUploadConfirmed']: raise Invalid('unconfirmed object: '+entry['repoPath'])
                source=safe_input(root,entry['repoPath']);count=0;partsha=hashlib.sha256();partgit=hashlib.sha1(b'blob '+str(entry['bytes']).encode()+b'\0')
                with source.open('rb') as stream:
                    while chunk:=stream.read(1024*1024):
                        count+=len(chunk);total+=len(chunk);partsha.update(chunk);partgit.update(chunk);sha.update(chunk);git.update(chunk);target.write(chunk)
                verify_hash(count,partsha,partgit,entry)
            target.flush();os.fsync(target.fileno())
        verify_hash(total,sha,git,row)
        # Link is atomic and, unlike replace(), cannot overwrite a concurrent destination.
        os.link(temp,destination)
        return {'archive':row['repoPath'],'output':str(destination),'bytes':total,'sha256':sha.hexdigest(),'gitBlobSha':git.hexdigest(),'verified':True,'extracted':False}
    finally:
        os.unlink(temp)

def main():
    p=argparse.ArgumentParser();p.add_argument('--repo-root',type=pathlib.Path,default=pathlib.Path('.'));p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--archive');p.add_argument('--index',type=pathlib.Path,default=pathlib.Path(__file__).with_name('ARCHIVE_RESTORE_INDEX.json'));a=p.parse_args()
    index=json.loads(a.index.read_text());rows=index['archives']
    if a.archive:
        rows=[r for r in rows if r['repoPath']==a.archive or pathlib.PurePosixPath(r['repoPath']).name==a.archive]
        if len(rows)!=1:raise Invalid('archive selector must match exactly one original')
    a.output.mkdir(parents=True,exist_ok=True)
    if a.output.is_symlink():raise Invalid('output must not be a symlink')
    for row in rows:print(json.dumps(reconstruct(a.repo_root,a.output,row)))
if __name__=='__main__':
    try:main()
    except (Invalid,KeyError,ValueError,OSError) as error:print('ERROR: '+str(error),file=sys.stderr);sys.exit(1)

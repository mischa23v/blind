"""Offline, dry-run-first verifier for explicitly indexed research checkpoint ZIPs."""
import argparse, hashlib, json, os, re, stat, zipfile
from pathlib import Path, PurePosixPath

H = Path(__file__).resolve().parent
MAX_FILE = 128 << 20
MAX_TOTAL = 512 << 20

def sha(data): return hashlib.sha256(data).hexdigest()
def path_ok(name):
    if not isinstance(name,str) or not name or '\\' in name or ':' in name or '\x00' in name or name.startswith('/') or any(x in ('','.','..') for x in name.split('/')):
        raise ValueError('unsafe path: '+repr(name))
    return name

def pairs(items):
    out={}
    for k,v in items:
        if k in out: raise ValueError('duplicate JSON key: '+k)
        out[k]=v
    return out

def read_json(b): return json.loads(b,object_pairs_hook=pairs)
def digest_file(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(1<<20),b''): h.update(b)
    return h.hexdigest()

def safe_existing(root, rel):
    p=root
    for part in PurePosixPath(path_ok(rel)).parts:
        p=p/part
        if p.is_symlink(): raise ValueError('symlink destination: '+str(p))
        if p.exists() and p!=root/rel and not p.is_dir(): raise ValueError('non-directory parent')
    return p

def verify(archive, entry, workspace, restore=False):
    root=Path(workspace).absolute()
    # Reject symlink ancestors, including selected workspace itself.
    for p in (root,*root.parents):
        if p.is_symlink(): raise ValueError('symlink workspace')
    if not root.is_dir(): raise ValueError('workspace must already be a directory')
    if digest_file(archive)!=entry['sha256']: raise ValueError('archive checksum mismatch')
    with zipfile.ZipFile(archive) as z:
        infos=z.infolist(); names=[i.filename for i in infos]
        if len(names)!=len(set(names)): raise ValueError('duplicate ZIP entry')
        total=0
        for i in infos:
            path_ok(i.filename); mode=i.external_attr>>16
            if i.is_dir() or stat.S_ISLNK(mode) or stat.S_IFMT(mode) not in (0,stat.S_IFREG): raise ValueError('nonregular ZIP entry')
            if i.flag_bits&1: raise ValueError('encrypted entry')
            total+=i.file_size
            if i.file_size>MAX_FILE or total>MAX_TOTAL: raise ValueError('archive size budget')
        if 'MANIFEST.json' not in names: raise ValueError('missing manifest')
        manifest=read_json(z.read('MANIFEST.json')); rows=manifest['files']; expected={}
        for row in rows:
            name=path_ok(row['path'])
            if name=='MANIFEST.json' or name in expected: raise ValueError('duplicate/reserved manifest path')
            if not re.fullmatch('[0-9a-f]{64}',row['sha256']): raise ValueError('bad file hash')
            expected[name]=row
        selected={k:v for k,v in expected.items() if entry.get('group') is None or v.get('group')==entry['group']}
        if set(names)!=(set(selected)|{'MANIFEST.json'}): raise ValueError('missing or unlisted ZIP entries')
        for name in selected:
            if any(str(parent) in selected for parent in PurePosixPath(name).parents): raise ValueError('file/directory path conflict')
        missing=[]; present=[]; dependencies={}
        # Validate every member and every destination BEFORE writing any member.
        for name,row in selected.items():
            b=z.read(name)
            if len(b)!=row['bytes'] or sha(b)!=row['sha256']: raise ValueError('member checksum/size mismatch: '+name)
            p=safe_existing(root,name)
            if p.exists():
                if not p.is_file() or digest_file(p)!=row['sha256']: raise ValueError('divergent destination: '+name)
                present.append(name)
            else: missing.append(name)
            if name.endswith('/FROZEN.json'):
                doc=read_json(b)
                if isinstance(doc.get('files'),dict):
                    for dep,value in doc['files'].items():
                        if isinstance(value,str) and re.fullmatch('[0-9a-f]{64}',value): dependencies.setdefault(path_ok(dep),set()).add(value)
        missing_deps=[]; mismatch_deps=[]; conflicting_deps=[]
        for dep,hashes in dependencies.items():
            if len(hashes)>1: conflicting_deps.append(dep); continue
            targethash=next(iter(hashes))
            if dep in selected and selected[dep]['sha256']==targethash: continue
            p=safe_existing(root,dep)
            if not p.is_file(): missing_deps.append(dep)
            elif digest_file(p)!=targethash: mismatch_deps.append(dep)
        if restore:
            # Exclusive creation, no symlink following at any destination component.
            for name in missing:
                fd=os.open(root,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
                try:
                    parts=name.split('/')
                    for part in parts[:-1]:
                        try: os.mkdir(part,dir_fd=fd)
                        except FileExistsError: pass
                        nxt=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=fd);os.close(fd);fd=nxt
                    out=os.open(parts[-1],os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=fd)
                    with os.fdopen(out,'wb') as f: f.write(z.read(name))
                finally: os.close(fd)
        return dict(mode='restore' if restore else 'dry-run',archiveVerified=True,filesVerified=len(selected),alreadyIdentical=len(present),missingFiles=missing,restoredFiles=missing if restore else [],rootManifestRestored=False,missingPinnedDependencies=missing_deps,mismatchedPinnedDependencies=mismatch_deps,conflictingHistoricalDependencyPins=conflicting_deps,standaloneCompletenessClaimed=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('checkpoint');p.add_argument('archive',type=Path);p.add_argument('--workspace',type=Path,required=True);p.add_argument('--restore',action='store_true');a=p.parse_args()
    index=read_json((H/'INDEX.json').read_bytes());entry=index['checkpoints'][a.checkpoint]
    print(json.dumps(verify(a.archive,entry,a.workspace,a.restore),indent=2))
if __name__=='__main__': main()

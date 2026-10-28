#!/usr/bin/env python3
"""Read-only publication preparation. Never contacts GitHub or mutates inputs."""
import argparse, copy, datetime, hashlib, json, pathlib, re, sys

REPOSITORY = 'mischa23v/blind'
PREFIX = 'research/benchmark-artifacts-20261028/'
MAX_PART = 8 * 1024 * 1024
CONFIRMED_STATUSES = {'uploaded', 'verified_uploaded', 'confirmed_uploaded', 'root_confirmed_uploaded'}
RETURNED_FIELDS = ('GitHubSHA', 'returnedGitblobSHA', 'returnedGitBlobSha', 'returnedGitHubSHA')

class Invalid(ValueError): pass

def require(condition, message):
    if not condition: raise Invalid(message)

def repo_path(value):
    require(isinstance(value, str) and bool(value), 'missing repository path')
    p = pathlib.PurePosixPath(value)
    require(not p.is_absolute() and '\\' not in value and '..' not in p.parts and str(p) == value, 'unsafe repository path: '+value)
    return value

def snapshot(path, input_hashes):
    path = pathlib.Path(path)
    before = path.stat(); raw = path.read_bytes(); after = path.stat()
    require((before.st_size,before.st_mtime_ns,before.st_ino)==(after.st_size,after.st_mtime_ns,after.st_ino), 'input changed during read: '+str(path))
    input_hashes[str(path)] = hashlib.sha256(raw).hexdigest()
    return json.loads(raw)

def hash_files(paths, size):
    sha = hashlib.sha256(); git = hashlib.sha1(b'blob '+str(size).encode()+b'\0'); count = 0
    for path in paths:
        path = pathlib.Path(path)
        require(path.is_file() and not path.is_symlink(), 'missing/nonregular/symlink input: '+str(path))
        with path.open('rb') as src:
            while chunk := src.read(1024*1024):
                count += len(chunk); sha.update(chunk); git.update(chunk)
    return {'bytes':count,'sha256':sha.hexdigest(),'gitBlobSha':git.hexdigest()}

def check_metadata(actual, expected, label):
    for key in ('bytes','sha256','gitBlobSha'):
        require(actual.get(key)==expected.get(key), f'{label}: {key} mismatch')

def metadata(row):
    values=[row.get(k) for k in ('gitBlobSha','expectedGitblobSHA','sha') if row.get(k) is not None]
    require(len(set(values))<=1,'conflicting expected Git blob SHAs')
    return {'bytes':row.get('bytes'), 'sha256':row.get('sha256'), 'gitBlobSha':values[0] if values else None}

def confirmed_sha(row):
    values = [row.get(k) for k in RETURNED_FIELDS if row.get(k) is not None]
    require(len(set(values)) <= 1, 'conflicting explicit returned GitHub SHAs')
    if not values: return None
    require(row.get('status') in CONFIRMED_STATUSES, 'explicit returned SHA has unconfirmed status: '+str(row.get('status')))
    require(re.fullmatch('[0-9a-f]{40}', values[0]) is not None, 'invalid returned SHA')
    return values[0]

def row_path(row): return repo_path(row.get('repoPath',row.get('path')))

def assemble(manifest_path, receipts, parts_paths, root_receipt, output):
    input_hashes={}; missing=[]
    manifest=snapshot(manifest_path,input_hashes)
    require(not manifest.get('errors'), 'publication manifest has errors')
    rows=manifest['files']; all_paths=[row_path(x) for x in rows]
    require(len(all_paths)==len(set(all_paths)), 'duplicate publication manifest paths')
    binary={row_path(x):x for x in rows if x['encoding']=='base64'}
    index_row=next(x for x in rows if row_path(x)==PREFIX+'ARCHIVE_RESTORE_INDEX.json')
    index=snapshot(index_row['localPath'],input_hashes)
    check_metadata(hash_files([index_row['localPath']],index_row['bytes']),metadata(index_row),'source restore index')
    originals={row_path(x):x for x in index['archives']}
    expected_archives={p for p in binary if p.endswith('.tar.gz')}
    require(set(originals)==expected_archives, 'restore index/archive manifest membership mismatch')
    for path,row in originals.items():
        require((row['bytes'],row['sha256'])==(binary[path]['bytes'],binary[path]['sha256']), 'original restore metadata mismatch: '+path)
    # Every original remains byte-for-byte pinned, even when later represented by parts.
    for path,row in binary.items():
        require(row.get('mode')=='100644', 'unsupported binary mode: '+path)
        check_metadata(hash_files([row['localPath']],row['bytes']),metadata(row),'original '+path)
    split={}; objects=dict(binary); reconstruction=[]
    for source in parts_paths:
        if not pathlib.Path(source).exists(): missing.append(str(source)); continue
        doc=snapshot(source,input_hashes)
        require(doc.get('repo',REPOSITORY)==REPOSITORY, 'parts repository mismatch')
        for original in doc['originals']:
            path=row_path(original)
            require(path in expected_archives and path not in split, 'unknown/duplicate split original: '+path)
            check_metadata(metadata(original),metadata(binary[path]),'split original '+path)
            parts=original['parts']; require(len(parts)>=2,'split must have at least two parts')
            total=0; local=[]
            for n,part in enumerate(parts,1):
                q=row_path(part)
                require(q==path+f'.part{n:03d}', 'parts must be contiguous ordered .partNNN paths: '+q)
                require(q not in objects, 'duplicate part path: '+q)
                require(type(part['bytes']) is int and 0<part['bytes']<=MAX_PART,'part outside 8 MiB cap: '+q)
                require(part.get('mode','100644')=='100644', 'unsupported part mode')
                check_metadata(hash_files([part['localPath']],part['bytes']),metadata(part),'part '+q)
                objects[q]=part; total+=part['bytes']; local.append(part['localPath'])
            require(total==binary[path]['bytes'],'split total size mismatch: '+path)
            result=hash_files(local,total); check_metadata(result,metadata(binary[path]),'concatenation '+path)
            split[path]=parts; reconstruction.append({'original':path,'partCount':len(parts),**result,'passed':True})
    confirmed={}; receipt_sources={}; pending=[]
    for source in list(receipts)+[root_receipt]:
        if not pathlib.Path(source).exists(): missing.append(str(source)); continue
        doc=snapshot(source,input_hashes)
        if isinstance(doc,dict):
            require(doc.get('repo',REPOSITORY)==REPOSITORY,'receipt repository mismatch')
            rows=doc['receipts']
        else: rows=doc
        require(isinstance(rows,list),'receipt rows must be a list')
        for row in rows:
            path=row_path(row)
            require(path in objects,'receipt path absent from allowlist and split manifests: '+path)
            # A computed SHA or verified=true alone is never upload confirmation.
            check_metadata(metadata(row),metadata(objects[path]),'receipt '+path)
            returned=confirmed_sha(row)
            if returned is None: pending.append({'path':path,'status':row.get('status','unknown')}); continue
            require(returned==objects[path]['gitBlobSha'],'GitHub returned SHA differs from pinned bytes: '+path)
            require(path not in confirmed or confirmed[path]==returned,'conflicting confirmed receipt: '+path)
            confirmed[path]=returned; receipt_sources.setdefault(path,[]).append(str(source))
    tree=[]; states={}
    # Prefer a confirmed original; otherwise publish only individually confirmed parts.
    for path,original in binary.items():
        if path in confirmed:
            selected=[original]; kind='single'; complete=True
        elif path in split:
            selected=split[path]; kind='concatenated-parts'; complete=all(row_path(p) in confirmed for p in selected)
        else:
            selected=[original]; kind='single'; complete=False
        stored=[]
        for part in selected:
            q=row_path(part); confirmed_here=q in confirmed
            stored.append({'repoPath':q,**metadata(part),'blobUploadConfirmed':confirmed_here})
            if confirmed_here: tree.append({'path':q,'mode':'100644','type':'blob','sha':confirmed[q]})
        states[path]={'kind':kind,'blobUploadsComplete':complete,'objects':stored}
    tree.sort(key=lambda x:x['path']); require(len(tree)==len({x['path'] for x in tree}),'duplicate final tree path')
    updated=copy.deepcopy(index)
    updated['schemaVersion']=2
    updated['storageNote']='Original bytes, hashes and member inventory are unchanged. Some large archives use ordered raw byte parts solely for transport. blobUploadsComplete reports confirmed blob creation receipts, not branch publication; verify a commit tree separately.'
    updated['restore']='Use restore_benchmarks.py to reconstruct and hash-check originals without overwriting sources, then extract each archive into a separate temporary directory. Verify member hashes against this index before copying research/ paths. Never overwrite the newer reviewed text with historical archive snapshots.'
    for row in updated['archives']:
        row['gitBlobSha']=binary[row['repoPath']]['gitBlobSha']; row['storage']=states[row['repoPath']]
    complete=all(x['blobUploadsComplete'] for x in states.values())
    readme='''# Preserved benchmark outputs\n\nDerived outputs only; no raw photographs, raw depth, mapper databases, original FARO mesh, runtime dependencies or credentials. These research artifacts do not establish navigation safety.\n\n`ARCHIVE_RESTORE_INDEX.json` preserves the original archive byte counts, SHA-256 hashes and per-member hashes. Larger archives may be stored as `.part001`, `.part002`, etc. These are consecutive raw byte slices, **not** independent gzip archives. No recompression, repacking or geometry transformation occurred.\n\n## Restore\n\nFrom a repository checkout, use Python 3's standard library:\n\n```sh\npython research/benchmark-artifacts-20261028/restore_benchmarks.py --repo-root . --output /tmp/blind-restored --archive ARCHIVE_NAME.tar.gz\n```\n\nOmit `--archive` to reconstruct all complete archives. The helper verifies every object, ordered concatenation, the original SHA-256 and Git blob SHA. It refuses missing/incomplete inputs and existing output files. It performs no downloads and does not extract tar files. Extract each verified archive into a **separate** temporary directory and verify members against the index before selectively restoring paths. Never mix root-level provenance metadata between archives.\n\nPreserve MuSHRoom Koivu attribution and applicable dataset terms. Private storage does not grant permission to redistribute source scans. Engine/source versions and licenses remain in the recorded protocols. RTAB/OctoMap/Open3D outputs are separate experiments, not interchangeable app-ready navigation maps.\n\nThe range-5m reports archive is a dated snapshot; its independent-review paragraph predates the final review. Do not replace `research/geometry-range-audit-20261028-1836/` with that older snapshot.\n\n## This checkpoint\n\n'''
    readme+=f"Confirmed binary objects: {len(tree)}. Complete original binary files: {sum(x['blobUploadsComplete'] for x in states.values())}/{len(states)} (22 archives plus one image).\n\n"
    if not complete: readme+='Pending files remain explicitly incomplete in the restore index; blob creation and publication are distinct.\n'
    output=pathlib.Path(output); require(not output.exists(),'output already exists; use a fresh snapshot directory')
    output.mkdir(parents=True)
    (output/'ARCHIVE_RESTORE_INDEX.json').write_text(json.dumps(updated,indent=2)+'\n')
    (output/'README.md').write_text(readme)
    restore_source=pathlib.Path(__file__).with_name('restore_benchmarks.py').read_text()
    (output/'restore_benchmarks.py').write_text(restore_source)
    (output/'BINARY_TREE_ENTRIES.json').write_text(json.dumps(tree,indent=2)+'\n')
    text_entries=[{'path':PREFIX+name,'mode':'100644','type':'blob','content':(output/name).read_text()} for name in ['ARCHIVE_RESTORE_INDEX.json','README.md','restore_benchmarks.py']]
    (output/'METADATA_TREE_ENTRIES.json').write_text(json.dumps(text_entries,indent=2)+'\n')
    receipt={'schemaVersion':1,'repository':REPOSITORY,'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'validationPassed':True,'allBinaryUploadsConfirmed':complete,'originalBinaryCount':len(binary),'originalArchiveCount':len(originals),'completeOriginalCount':sum(x['blobUploadsComplete'] for x in states.values()),'confirmedTreeEntries':len(tree),'pendingOriginals':[p for p,s in states.items() if not s['blobUploadsComplete']],'missingInputs':missing,'inputSha256':input_hashes,'splitReconstructionChecks':reconstruction,'receiptSources':receipt_sources,'scope':'Local hashes plus explicit successful GitHub blob receipts; no remote tree/ref mutation or branch-publication assertion.','sourceArchiveIndexSha256':index_row['sha256'],'artifacts':{name:hashlib.sha256((output/name).read_bytes()).hexdigest() for name in ['ARCHIVE_RESTORE_INDEX.json','README.md','restore_benchmarks.py','BINARY_TREE_ENTRIES.json','METADATA_TREE_ENTRIES.json']}}
    (output/'ASSEMBLY_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n')
    return receipt

def main():
    p=argparse.ArgumentParser();p.add_argument('--input-dir',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parent.parent);p.add_argument('--output',required=True,type=pathlib.Path);p.add_argument('--require-complete',action='store_true');a=p.parse_args()
    root=a.input_dir
    receipt_paths=[root/f'BINARY_BATCH_{i}_RECEIPTS.json' for i in (1,2,3)]
    receipt_paths += sorted(root.glob('BINARY_BATCH_*_REASSIGNED_RECEIPTS.json'))
    receipt_paths += sorted(root.glob('BINARY_BATCH_*_ROOT_RECEIPTS.json'))
    r=assemble(root/'PUBLICATION_MANIFEST.json',receipt_paths,[root/f'BINARY_BATCH_{i}_PARTS.json' for i in (1,2,3)],pathlib.Path(__file__).with_name('ROOT_CONFIRMED_BLOBS.json'),a.output)
    print(json.dumps({k:r[k] for k in ['validationPassed','allBinaryUploadsConfirmed','completeOriginalCount','originalBinaryCount','confirmedTreeEntries','pendingOriginals','missingInputs']},indent=2))
    return 2 if a.require_complete and not r['allBinaryUploadsConfirmed'] else 0
if __name__=='__main__':
    try: sys.exit(main())
    except (Invalid,KeyError,ValueError,OSError) as error: print('ERROR: '+str(error),file=sys.stderr);sys.exit(1)

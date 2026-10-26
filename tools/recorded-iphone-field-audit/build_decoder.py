"""Build only the pinned official decoder using installed gcc, serially."""
from pathlib import Path
import hashlib,json,resource,shutil,subprocess,time

ROOT=Path(__file__).resolve().parent

def main():
    root=ROOT/'decoder';manifest=json.loads((root/'UPSTREAM_MANIFEST.json').read_text())
    if manifest['revision']!='e634ca58b4821d9f3d560cdc6df5dec02ffc93fd':raise ValueError('wrong codec pin')
    for entry in manifest['files']:
        p=root/'upstream'/entry['path'];b=p.read_bytes()
        if len(b)!=entry['bytes'] or hashlib.sha256(b).hexdigest()!=entry['sha256']:raise ValueError('changed official source')
    if shutil.disk_usage(root).free<768*1024**2:raise RuntimeError('disk reserve')
    sources=['lzfse_decode.c','lzfse_decode_base.c','lzfse_fse.c','lzvn_decode_base.c']
    gcc=shutil.which('gcc')
    if not gcc:raise RuntimeError('installed gcc unavailable; no install permitted')
    output=root/'liblzfse_decode.so.pending'
    if output.exists() or (root/'liblzfse_decode.so').exists():raise RuntimeError('refuse binary overwrite')
    command=[gcc,'-O2','-std=c99','-fPIC','-shared','-Wall','-Wextra','-pedantic',
        *[str(root/'upstream/src'/s) for s in sources],'-o',str(output)]
    started=time.monotonic()
    completed=subprocess.run(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60,text=True)
    (root/'build.log').write_text(completed.stdout)
    receipt={'command':command,'exitCode':completed.returncode,'wallSeconds':time.monotonic()-started,
        'peakChildRSSKiB':resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
        'compiler':subprocess.check_output([gcc,'--version'],text=True).splitlines()[0],
        'upstreamRevision':manifest['revision'],'sourcesUnmodified':True,'scope':'decoder only, no navigation/sensor evaluation'}
    if completed.returncode==0:
        output.rename(root/'liblzfse_decode.so');b=(root/'liblzfse_decode.so').read_bytes()
        receipt.update({'binaryBytes':len(b),'binarySHA256':hashlib.sha256(b).hexdigest()})
    total=sum(p.stat().st_size for p in root.rglob('*') if p.is_file());receipt['workingFileBytes']=total
    if total>10*1024**2:raise RuntimeError('decoder working cap exceeded')
    (root/'BUILD_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt,indent=2))
    if completed.returncode:raise SystemExit(completed.returncode)

if __name__=='__main__':main()

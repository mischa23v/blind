from pathlib import Path
import json,hashlib
F=Path(__file__).resolve().parent;R=F.parent;p=F/'PUBLICATION_MANIFEST.json';j=json.loads(p.read_text())
paths={Path(x['localPath']) for x in j['textFiles']}
paths.update([F/'EXPLORATORY_EDGE_STRATA.json',F/'diagnose_reference_edges.py',F/'refresh_publication.py'])
paths.update((R/'independent-review').glob('*.json'));paths.update((R/'independent-review').glob('*.py'));paths.update((R/'independent-review').glob('*.md'))
def row(p):
 b=p.read_bytes();return {'localPath':str(p.resolve()),'repositoryPath':'research/open3d-same-data-benchmark-20261028/'+str(p.relative_to(R)),'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
j['textFiles']=[row(p)for p in sorted(paths)];j['optionalDerivedBinaryFiles']=[row(Path(x['localPath']))for x in j['optionalDerivedBinaryFiles']];p.write_text(json.dumps(j,indent=2)+'\n')
(F/'SHA256SUMS.txt').write_text(''.join(f"{x['sha256']}  {Path(x['localPath']).relative_to(R)}\n"for x in j['textFiles']+j['optionalDerivedBinaryFiles']))
print('text',len(j['textFiles']),sum(x['bytes']for x in j['textFiles']),'binaries',len(j['optionalDerivedBinaryFiles']),sum(x['bytes']for x in j['optionalDerivedBinaryFiles']))

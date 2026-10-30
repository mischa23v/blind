"""Read saved JSON/gzip only. No geometry/native imports or execution."""
import collections, gzip, hashlib, json, pathlib, sys
root = pathlib.Path(sys.argv[1])
p = root / 'vtk/contacts.jsonl.gz'
h = hashlib.sha256()
with p.open('rb') as f:
    for chunk in iter(lambda: f.read(1024*1024), b''): h.update(chunk)
count = size = 0
scenes = collections.Counter()
last = None
with gzip.open(p, 'rb') as f:
    for line in f:
        row = json.loads(line)
        count += 1
        size += len(line)
        scenes[row['scene']] += 1
        last = {k: row[k] for k in ('scene','name','eventIndex','arm','envelope','lowerTrimMetres')}
        assert row['movementApplied'] is False and row['physicalAuthority'] is False
receipt = json.loads((root/'GUARD_RUN/RESULT.json').read_text())
height = json.loads((root/'height/SUMMARY.json').read_text())
assert receipt['status'] == 'failed'
assert receipt['inputHashesBefore'] == receipt['inputHashesAfter']
assert height['eventRows'] == sum(s['validEvents'] for s in height['scenes']) == 3696
print(json.dumps({'schema':1,'method':'streaming stdlib JSON/gzip audit; no native execution',
 'aggregateStatus':receipt['status'],'guardBeforeAfterHashesEqual':True,
 'stageExitCodes':{r['label']:r['exitCode'] for r in receipt['commands']},
 'savedCompleteRecords':count,'scheduledRecords':29568,'missingRecords':29568-count,
 'decompressedSavedBytes':size,'rawGzipBytes':p.stat().st_size,'rawGzipSHA256':h.hexdigest(),
 'gzipReadToEOFWithoutError':True,'recordsByScene':dict(scenes),'lastSavedRecord':last,
 'allNativeHeightEventsValid':True,'nativeHeightEvents':3696,
 'physicalMovementApplied':False,'completeCollisionVerdict':None},indent=2,sort_keys=True))

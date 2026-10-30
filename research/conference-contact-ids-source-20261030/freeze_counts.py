#!/usr/bin/env python3
"""Verify compact count freeze against every saved record; stdlib, no native work."""
import gzip, hashlib, json, pathlib
H=pathlib.Path(__file__).resolve().parent;W=H.parents[2]
P=W/'conference-body-comparison-attempt-001/comparison'
CONTACTS_SHA='f1b930185ee94b4b61fd8dbd2b85815ebe1d22148e34bbc3e796b010d91395be'
RECEIPT_SHA='1f772214cbf62fa9c78f5a6891d17d4794abdc57d0fb9351809153cd99075b3f'
def sha(path):
    with path.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def main():
    if sha(P/'CONTACTS.jsonl.gz')!=CONTACTS_SHA or sha(P/'RECEIPT.json')!=RECEIPT_SHA:
        raise ValueError('original saved worker bytes changed')
    rows=[];events=hits=candidates=0;candidate_digest=hashlib.sha256()
    with gzip.open(P/'CONTACTS.jsonl.gz','rb') as stream:
        while True:
            line=stream.readline(65537)
            if not line:break
            if len(line)>65536 or not line.endswith(b'\n') or events>=13704:raise ValueError('source stream bounds')
            q=json.loads(line)
            if not rows or rows[-1]['name']!=q['path']:rows.append({'name':q['path'],'counts':[]})
            if len(rows)>7 or q['event']!=len(rows[-1]['counts']):raise ValueError('source event sequence')
            pair=[q['contacts'][kind]['rawContactCount'] for kind in ('actualBody','horizontalMargin')]
            cp=[q['contacts'][kind]['candidateTriangles'] for kind in ('actualBody','horizontalMargin')]
            rows[-1]['counts'].append(pair);events+=1;hits+=sum(pair);candidates+=sum(cp)
            candidate_digest.update(('%d,%d\n'%tuple(cp)).encode())
    result={'sourceContactsSHA256':CONTACTS_SHA,'sourceReceiptSHA256':RECEIPT_SHA,
            'sourceAggregateOutcome':'failed','postrunWorkerEvidenceReconciled':True,
            'eventCount':events,'totalHitOccurrences':hits,'paths':rows,
            'candidateCountStreamSHA256':candidate_digest.hexdigest(),'totalCandidateTriangles':candidates}
    if (events,hits,candidates)!=(13704,108582,8710095):raise ValueError('actual total counts changed')
    data=(json.dumps(result,separators=(',',':'))+'\n').encode()
    if data!=(H/'EXPECTED_COUNTS.json').read_bytes():raise ValueError('committed expected count bytes differ')
    print(json.dumps({'status':'all_saved_counts_reproduced','events':events,'hitOccurrences':hits,
                      'triangleCandidates':candidates,'expectedCountsSHA256':hashlib.sha256(data).hexdigest(),
                      'nativeExecuted':False}))
if __name__=='__main__':main()

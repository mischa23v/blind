#!/usr/bin/env python3
"""Stdlib actual-chain/baseline freeze, no GEOS/native re-execution."""
import hashlib,importlib.util,json,pathlib
H=pathlib.Path(__file__).resolve().parent;R=H.parents[1];W=R.parent
def module(path,name):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def sha(path):
    with path.open('rb')as f:return hashlib.file_digest(f,'sha256').hexdigest()
def main():
    selection=module(H/'selection.py','candidate_selection')
    pairs_path=W/'conference-geos-simplification-attempt-001/comparison/PAIRS.json'
    if sha(pairs_path)!=selection.PAIRS_SHA:raise ValueError('actual pairs input identity')
    guard=json.loads((W/'conference-geos-simplification-attempt-001/GUARD_RUN/RESULT.json').read_text())
    if guard['sourceCommit']!=selection.PAIR_SOURCE or guard['status']!='completed-zero-exit':raise ValueError('actual simplification source/outcome')
    old=R/'research/conference-body-source-20261029';oldpins=json.loads((old/'SOURCE_PINS.json').read_text());prefix='research/conference-body-source-20261029/'
    loader=module(R/'research/conference-body-postrun-source-20261030/run_aggregate_isolated.py','pinned_loader')
    c=loader.load_frozen_contracts(old,oldpins['inputs'][prefix+'contracts.py'],oldpins['inputs'][prefix+'schedule_source.py'])
    routes=selection.select_simplified(json.loads(pairs_path.read_text()),json.loads((old/'ROUTES.json').read_text()),c.make_schedule)
    public=R/'research/conference-contact-ids-result-20261030/public';summary=json.loads((public/'SUMMARY.json').read_text())
    if summary['sourceCommit']!='e9bfe8deefd7b91494aec0c77afb5787f3913712' or summary['status']!='COMPLETE_ID_RECOUNT_AND_HEIGHT_BANDS_VERIFIED':raise ValueError('baseline source-bound recount identity')
    baseline={'sourceCommit':summary['sourceCommit'],'sourceManifestSHA256':summary['sourceManifestSHA256'],
      'summarySHA256':sha(public/'SUMMARY.json'),'nativeRerunRequired':False,'paths':[]}
    for name in selection.NAMES:
        p=public/(name+'.json');row=json.loads(p.read_text())
        baseline['paths'].append({'name':name,'authoredEvents':row['authoredEvents'],'sourceRecountSHA256':sha(p),
          'arms':{k:{'contactEvents':a['references']['startFoot']['events']['contact'],'hitOccurrences':a['hitOccurrences'],
                     'uniqueFaceCount':a['uniqueFaceCount'],'uniqueIDs':a['uniqueIDs']}for k,a in row['arms'].items()}})
    for name,data in (('ROUTES.json',routes),('BASELINE.json',baseline)):
        text=json.dumps(data,indent=2)+'\n';p=H/name
        if p.exists():
            if p.read_text()!=text:raise ValueError('existing freeze differs: '+name)
        else:p.write_text(text)
    print(json.dumps({'status':'source_only_frozen','events':7470,'routesSHA256':sha(H/'ROUTES.json'),
                      'baselineSHA256':sha(H/'BASELINE.json'),'nativeExecuted':False}))
if __name__=='__main__':main()

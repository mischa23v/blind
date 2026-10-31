"""Freeze evaluator code, source plans and original reference inputs BEFORE native parsing."""
from pathlib import Path
import json,shutil
from runtime import H,sha,save
assert not(H/'FROZEN.json').exists(),'never overwrite frozen execution inputs'
source=H.parent/'source-forward';p=H/'inputs/PHONE_FRAME_METADATA_ONLY.json'
if not p.exists():shutil.copyfile(source/'inputs/PHONE_FRAME_METADATA_ONLY.json',p)
assert sha(p)==sha(source/'inputs/PHONE_FRAME_METADATA_ONLY.json')
expected={'gt_mesh.ply':'e18db651c694046de7994237e276d88138ecef9071351281a418de9c9a279b5e','icp_iphone.json':'95b4e26d6d260bd9b06cff801648fc38c030a510cf4055af2294490cf49938d4'}
for name,digest in expected.items():assert sha(H/'inputs'/name)==digest,name
matrix=json.loads((H/'MATRIX.json').read_text());assert len(matrix['episodes'])==100 and all(x['status']=='notRun'for x in matrix['episodes']);assert len({(x['pairIndex'],x['conditionID'])for x in matrix['episodes']})==100
assert all(sha(H/r['path'])==r['sha256']for r in matrix['plans'])
files=[*sorted(H.glob('*.py')),*sorted((H/'plans').glob('*.json')),H/'MATRIX.json',H/'CONDITIONS.json',H/'ADAPTATION_RECEIPT.json',H/'HISTORICAL_SELECTED_PLAN.json',*[H/'inputs'/n for n in['gt_mesh.ply','icp_iphone.json','PHONE_FRAME_METADATA_ONLY.json']]]
save(H/'FROZEN.json',{'scope':'supplied-pose static public-room evaluator; no live authority','files':{str(p.relative_to(H)):sha(p)for p in files},'matrixSHA256':sha(H/'MATRIX.json'),'sourceQueryManifestSHA256':matrix['sourceManifestSHA256'],'sourceQueryCohortUnchanged':True,'all100EpisodesScheduledBeforeNativeReferenceLoadOrQueries':True,'referenceRole':'world support/contact veto only; never controller input','floorModel':'per-pair predeclared stage59 seeded component/patch fitting; unchanged historic fixed-plane provenance only; localmax9 foot height','physicalAuthority':False});print(sha(H/'FROZEN.json'))

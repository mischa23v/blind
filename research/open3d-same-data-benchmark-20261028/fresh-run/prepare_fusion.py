from pathlib import Path
import sys,json,hashlib
R=Path(__file__).resolve().parent
sys.path.insert(0,str(R/'source'));import acquire_environment as g
old=json.loads((R.parent/'evidence/KOIVU_FROZEN.json').read_text());c=json.loads((R.parent/'DATA_CONTRACT.json').read_text());base=R/'inputs/room_datasets/koivu/iphone/long_capture'
assert g.digest(base/'transformations.json')==c['sourcePoseSHA256']
assert (base/'test.txt').read_text().splitlines()==c['excludedTestIDs']
pins={};rows=[]
for row in old['trainingFrames']:
 new=dict(row)
 for key,folder in [('rgbPath','images'),('depthPath','depth')]:
  p=base/folder/Path(row[key]).name;assert g.digest(p)==old['pins'][row[key]];new[key]=str(p);pins[str(p)]=g.digest(p)
 rows.append(new)
for row in c['depthManifest']:
 p=base/'depth'/row['file'];assert p.stat().st_size==row['bytes'] and g.digest(p)==row['sha256'];pins[str(p)]=row['sha256']
for p in [base/'transformations.json',base/'test.txt',R/'fusion_worker.py',R/'source/acquire_environment.py']:
 pins[str(p)]=g.digest(p)
new=dict(old,pins=pins,trainingFrames=rows,posePath=str(base/'transformations.json'),splitPath=str(base/'test.txt'))
g.dump(R/'FUSION_FROZEN.json',new)
g.dump(R/'FUSION_PREPARATION.json',{'sourceOriginalSHA256':g.digest(R.parent/'evidence/koivu_author_fusion.py'),'newWrapperSHA256':g.digest(R/'fusion_worker.py'),'frozenSHA256':g.digest(R/'FUSION_FROZEN.json'),'all265RGBAnd294DepthHashesMatch':True,'originalPoseAndSplitMatch':True,'changes':['paths remapped into isolated stage','worker result serialized independently from stdout','existing integration worker body otherwise unchanged'],'physicalAuthority':False})
print(g.digest(R/'FUSION_FROZEN.json'))

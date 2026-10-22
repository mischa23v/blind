"""Post-hoc investigation ONLY; does not tune policy or produce new validation."""
import argparse,json,pathlib
import cv2,numpy as np
from image_smoke import MODEL_FILES,checked_file

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--assets',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True);a=p.parse_args();cv2.setNumThreads(1)
 m={n:checked_file(a.assets,'models/'+n,h) for n,h in MODEL_FILES.items()}
 d=cv2.FaceDetectorYN_create(str(m['face_detection_yunet_2023mar.onnx']),'',(92,112),.9,.3,5000);r=cv2.FaceRecognizerSF_create(str(m['face_recognition_sface_2021dec.onnx']),'')
 data={};metrics=[]
 keys=[f's{i}/1.pgm' for i in range(1,21)]+[f's21/{j}.pgm' for j in range(1,11)]
 for key in keys:
  im=cv2.imread(str(a.assets/'orl'/key));_,faces=d.detect(im)
  item={'image':key,'channelsIdentical':bool(np.array_equal(im[:,:,0],im[:,:,1]) and np.array_equal(im[:,:,0],im[:,:,2])),'facesDetected':0 if faces is None else len(faces)}
  if faces is not None and len(faces)==1:
   f=faces[0];x,y,w,h=[float(v) for v in f[:4]]
   crop=r.alignCrop(im,f);feature=r.feature(crop).copy();data[key]=feature
   item.update(box=[x,y,w,h],clippedBox=bool(x<0 or y<0 or x+w>im.shape[1] or y+h>im.shape[0]),detectionScore=float(f[-1]),alignedSize=list(crop.shape),featureDimensions=int(feature.size),landmarks=f[4:14].tolist())
  metrics.append(item)
 scores=[];maxdiff=0.
 for j in range(1,11):
  key=f's21/{j}.pgm'
  if key not in data:continue
  row=[]
  for i in range(1,21):
   k=f's{i}/1.pgm'
   if k not in data:continue
   v=data[key].reshape(-1);u=data[k].reshape(-1)
   own=float(np.dot(v/np.linalg.norm(v),u/np.linalg.norm(u)))
   official=float(r.match(data[key].copy(),data[k].copy(),cv2.FaceRecognizerSF_FR_COSINE))
   maxdiff=max(maxdiff,abs(own-official));row.append({'identity':i,'officialCosine':official})
  row.sort(key=lambda z:z['officialCosine'],reverse=True)
  scores.append({'image':key,'ranked':row,'topTwoGap':row[0]['officialCosine']-row[1]['officialCosine']})
 report={'purpose':__doc__,'noThresholdChanges':True,'maxNormalizedDotVsOfficialMatchAbsDifference':maxdiff,'observations':metrics,'scores':scores,
 'limitations':['All inspected images are development/error-analysis data now, not fresh heldout.','No iOS CGImage orientation/channel conversion or clipping-policy parity test.','Face-detector confidence is not identity confidence or PAD evidence.']}
 a.output.write_text(json.dumps(report,indent=2));print('Maximum dot-versus-official-match difference:',maxdiff)
 for row in scores:print(row['image'],row['ranked'][:2],row['topTwoGap'])
if __name__=='__main__':main()

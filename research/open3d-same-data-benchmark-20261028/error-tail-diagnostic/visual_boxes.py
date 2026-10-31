"""Post-hoc visually selected rectangles; descriptive residuals, not semantic ground truth."""
from pathlib import Path
import numpy as np,json
from PIL import Image
D=Path(__file__).resolve().parent;R=D.parent/'fresh-run'
boxes={'frame_00197':[('visually selected open central floor',[160,780,600,970]),('back wall away from chair silhouettes',[300,220,620,350])],'frame_00228':[('back wall central panel',[300,40,420,300]),('far chair back interior',[220,390,300,460]),('near chair back interior',[150,620,350,780])],'frame_00031':[('wall under board',[400,700,650,850])]}
out=[]
for n,bs in boxes.items():
 with np.load(R/'evaluation/tsdf'/(n+'.npz'))as f:row=f['row'];col=f['column'];t=f['axialMetres']
 with np.load(R/'evaluation/faro'/(n+'.npz'))as f:
  assert np.array_equal(row,f['row'])and np.array_equal(col,f['column']);z=f['axialMetres']
 sensor=np.asarray(Image.open(R/'inputs/room_datasets/koivu/iphone/long_capture/depth'/(n+'.png')))[row,col]/1000
 for label,(x0,y0,x1,y1)in bs:
  m=(row>=y0)&(row<=y1)&(col>=x0)&(col<=x1);q=m&np.isfinite(t)&np.isfinite(z);s=q&(sensor>0)
  out.append({'frame':n,'postHocVisualBox':label,'pixelBounds':[x0,y0,x1,y1],'scheduled':int(m.sum()),'paired':int(q.sum()),'over50cm':int(np.sum(abs(t[q]-z[q])>.5)),'medianAbsoluteResidual':float(np.median(abs(t[q]-z[q]))),'p95AbsoluteResidual':float(np.quantile(abs(t[q]-z[q]),.95)),'tsdfMedianDepth':float(np.median(t[q])),'faroMedianDepth':float(np.median(z[q])),'sensorMedianDepth':float(np.median(sensor[s])),'medianAbsTsdfSensor':float(np.median(abs(t[s]-sensor[s]))),'medianAbsFaroSensor':float(np.median(abs(z[s]-sensor[s])))})
(D/'VISUAL_BOX_RESULTS.json').write_text(json.dumps(out,indent=2)+'\n')

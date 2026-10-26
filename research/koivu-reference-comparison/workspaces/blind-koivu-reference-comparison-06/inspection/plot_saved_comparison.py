"""Derive fixed analytical displays from saved ray artifacts; never loads VTK/mesh."""
from pathlib import Path
import gc,hashlib,json,os,resource,shutil,signal,sys,threading,time
ROOT=Path(__file__).resolve().parent;STAGE06=ROOT.parent;WORKSPACE=STAGE06.parent
RUN=STAGE06/'run-evaluate/comparison';OUT=ROOT/'run.partial';FINAL=ROOT/'run'
DATA=WORKSPACE/'blind-mushroom-koivu-acquisition-01'
IDS=[1,5,9,13,17,21,25,29]
RESULT_SHA='3dd8431ea152ac1019fc52e70cdeb49c2dfa8065917d92d546cf8a33f47f48cd'
EXTRACTION_SHA='0bada1c6775e8c5b21d4c6cbd259008621620d4849483daadb9c7887df5a22f7'
ARCHIVE_SHA='68735cfa0758e1288a006c30dc8b95ffb4caa3392bc9c68c0c3ea6c111966518'
CAP=64*1024**2;RESERVE=768*1024**2;RSS=256*1024**2;CPU=30.;WALL=45.

def sha(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024**2),b''):h.update(b)
 return h.hexdigest()
def tree_bytes():return sum(p.stat().st_size for p in STAGE06.rglob('*') if p.is_file())
def dump(path,value):
 with path.open('x') as f:json.dump(value,f,indent=2,sort_keys=True,allow_nan=False);f.write('\n')

class Budget:
 def __init__(self):self.start=time.monotonic();self.cpu_start=time.process_time();self.stop=threading.Event();self.peak=0
 def values(self):
  self.peak=max(self.peak,resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024)
  return {'wallSeconds':time.monotonic()-self.start,'cpuSeconds':time.process_time()-self.cpu_start,'observedPeakRSSBytes':self.peak,'allStage06Bytes':tree_bytes(),'freeBytes':shutil.disk_usage(ROOT).free}
 def violation(self,r):
  if r['wallSeconds']>WALL:return '45-second wall budget'
  if r['cpuSeconds']>CPU:return '30-second CPU budget'
  if r['observedPeakRSSBytes']>RSS:return '256-MiB RSS budget'
  if r['allStage06Bytes']>CAP:return '64-MiB aggregate stage-06 output budget'
  if r['freeBytes']<RESERVE:return '768-MiB free reserve'
 def check(self):
  r=self.values();why=self.violation(r)
  if why:raise RuntimeError(why)
  return r
 def watch(self):
  while not self.stop.wait(.05):
   try:
    r=self.values();why=self.violation(r)
    if why:
     try:dump(OUT/'WATCHDOG_FAILURE.json',{'status':'stopped; partial retained','reason':why,'resources':r,'noComparisonRerun':True})
     finally:os.kill(os.getpid(),signal.SIGKILL)
   except FileNotFoundError:pass


def main():
 if OUT.exists() or FINAL.exists():raise RuntimeError('refuse existing output or failed partial overwrite')
 OUT.mkdir();(OUT/'panels').mkdir();(OUT/'original-rgb').mkdir();(OUT/'cache').mkdir()
 budget=Budget();resource.setrlimit(resource.RLIMIT_CPU,(30,30))
 def alarm(signum,frame):raise TimeoutError('45-second wall budget')
 signal.signal(signal.SIGALRM,alarm);signal.alarm(45)
 threading.Thread(target=budget.watch,daemon=True).start()
 try:
  for name in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','NUMEXPR_NUM_THREADS']:os.environ[name]='1'
  os.environ['MPLCONFIGDIR']=str(OUT/'cache');os.environ['PYTHONDONTWRITEBYTECODE']='1'
  import numpy as np
  import matplotlib
  matplotlib.use('Agg')
  import matplotlib.pyplot as plt
  from matplotlib.colors import ListedColormap,BoundaryNorm
  budget.check()
  result_path=RUN/'COMPARISON_RESULTS.json';extract_path=DATA/'RECORDED_SUBSET_EXTRACTION_RECEIPT.json'
  if sha(result_path)!=RESULT_SHA or sha(extract_path)!=EXTRACTION_SHA:raise ValueError('frozen result/extraction receipt changed')
  result=json.loads(result_path.read_text());extract=json.loads(extract_path.read_text())
  if extract['sourceArchiveSHA256']!=ARCHIVE_SHA:raise ValueError('original RGB archive association')
  expected_names=[f'frame_{i:05d}' for i in IDS]
  if [f['basename'] for f in result['frames']]!=expected_names or result['sampleStride']!=4:raise ValueError('frozen frame/stride selection mismatch')
  artifacts={f['path']:f for f in result['rayArtifacts']};selected={f['name']:f for f in extract['files']}
  inputs=[{'path':str(result_path),'sha256':RESULT_SHA},{'path':str(extract_path),'sha256':EXTRACTION_SHA},
   {'path':str(Path(__file__)),'sha256':sha(Path(__file__))},{'path':str(ROOT/'DISPLAY_PROTOCOL.md'),'sha256':sha(ROOT/'DISPLAY_PROTOCOL.md')}]
  for name in expected_names:
   a=artifacts[name+'-scheduled-rays.npz'];p=RUN/a['path']
   if p.stat().st_size!=a['bytes'] or sha(p)!=a['sha256']:raise ValueError('saved ray artifact changed')
   inputs.append({'path':str(p),'sha256':a['sha256'],'bytes':a['bytes']})
   member=f'room_datasets/koivu/iphone/long_capture/images/{name}.jpg';a=selected[member];p=DATA/'recorded_subset'/member
   if p.stat().st_size!=a['bytes'] or sha(p)!=a['sha256']:raise ValueError('original selected RGB changed')
   inputs.append({'path':str(p),'sha256':a['sha256'],'bytes':a['bytes']})
  outputs=[];displays=[]
  depth_cmap=plt.get_cmap('viridis').copy();depth_cmap.set_bad('#dedede');depth_cmap.set_under('#f4ad32');depth_cmap.set_over('#d3429b')
  signed_cmap=plt.get_cmap('coolwarm').copy();signed_cmap.set_bad('#dedede')
  abs_cmap=plt.get_cmap('magma').copy();abs_cmap.set_bad('#dedede');abs_cmap.set_over('#43c5c6')
  avail_cmap=ListedColormap(['#347bb1','#df9b32','#8b68b8','#dedede']);avail_norm=BoundaryNorm([-.5,.5,1.5,2.5,3.5],4)
  edge_cmap=ListedColormap(['#dedede','#4f4f4f','#dc8648','#326e9a','#70a97e','#a364ad']);edge_norm=BoundaryNorm([-1.5,-.5,.5,1.5,2.5,3.5,4.5],6)
  for name,frame in zip(expected_names,result['frames']):
   budget.check()
   with np.load(RUN/(name+'-scheduled-rays.npz'),allow_pickle=False) as z:
    sensor=z['sensorAxialNominalMetres'].copy();ref=z['referenceAxialRegisteredNominalMetres'].copy();status=z['status'].copy();edge=z['referenceEdgeCategory'].copy();row=z['row'].copy();col=z['column'].copy()
   if sensor.shape!=(249,185) or any(a.shape!=sensor.shape for a in [ref,status,edge,row,col]):raise ValueError('saved scheduled grid shape mismatch')
   if not np.array_equal(row,np.broadcast_to(np.arange(0,996,4,dtype=np.uint16)[:,None],sensor.shape)) or not np.array_equal(col,np.broadcast_to(np.arange(0,740,4,dtype=np.uint16)[None,:],sensor.shape)):raise ValueError('saved scheduled-grid coordinates mismatch')
   sv=np.isfinite(sensor)&(sensor>0);rv=np.isfinite(ref)&(ref>0);paired=sv&rv
   expected=np.full(sensor.shape,3,dtype=np.uint8);expected[paired]=0;expected[sv&~rv]=1;expected[~sv&rv]=2
   if not np.array_equal(status,expected):raise ValueError('stored availability enum differs from finite-positive masks')
   counts={'paired':int((status==0).sum()),'sensorOnly':int((status==1).sum()),'referenceOnly':int((status==2).sum()),'neither':int((status==3).sum()),'scheduled':int(status.size)}
   if counts!=frame['counts']:raise ValueError('saved availability differs from frozen result counts')
   if not set(np.unique(edge))<=set(range(-1,5)) or not np.array_equal(edge==-1,~rv):raise ValueError('edge enum/no-reference mask mismatch')
   if [int(((edge==i)&rv).sum()) for i in range(5)]!=[e['referenceValidCount'] for e in frame['byReferenceEdge']]:raise ValueError('saved edge counts differ from frozen categories')
   delta=sensor-ref;absolute=np.abs(delta)
   clips={'sensorBelow015':int((sv&(sensor<.15)).sum()),'sensorAbove8':int((sv&(sensor>8)).sum()),'referenceBelow015':int((rv&(ref<.15)).sum()),'referenceAbove8':int((rv&(ref>8)).sum()),
    'signedBelowMinus1':int((paired&(delta< -1)).sum()),'signedAbovePlus1':int((paired&(delta>1)).sum()),'absoluteAbove1':int((paired&(absolute>1)).sum())}
   fig,axes=plt.subplots(2,3,figsize=(16,9),layout='constrained')
   im=axes[0,0].imshow(np.ma.masked_where(~sv,sensor),origin='upper',interpolation='nearest',cmap=depth_cmap,vmin=.15,vmax=8)
   fig.colorbar(im,ax=axes[0,0],extend='both',label='Saved processed axial depth [nominal m]')
   axes[0,0].set_title(f'Original processed depth — scheduled samples\nmasked={int((~sv).sum()):,}; display clipped low/high={clips["sensorBelow015"]}/{clips["sensorAbove8"]}')
   im=axes[0,1].imshow(np.ma.masked_where(~rv,ref),origin='upper',interpolation='nearest',cmap=depth_cmap,vmin=.15,vmax=8)
   fig.colorbar(im,ax=axes[0,1],extend='both',label='Registered reference axial depth [nominal m]')
   axes[0,1].set_title(f'Author-registered reference intersection\nno reference={int((~rv).sum()):,}; clipped low/high={clips["referenceBelow015"]}/{clips["referenceAbove8"]}')
   im=axes[0,2].imshow(np.ma.masked_where(~paired,delta),origin='upper',interpolation='nearest',cmap=signed_cmap,vmin=-1,vmax=1)
   fig.colorbar(im,ax=axes[0,2],extend='both',label='Sensor minus registered reference [nominal m]')
   axes[0,2].set_title(f'Signed discrepancy — paired rays only\nmasked={int((~paired).sum()):,}; clipped below/above={clips["signedBelowMinus1"]}/{clips["signedAbovePlus1"]}')
   im=axes[1,0].imshow(np.ma.masked_where(~paired,absolute),origin='upper',interpolation='nearest',cmap=abs_cmap,vmin=0,vmax=1)
   fig.colorbar(im,ax=axes[1,0],extend='max',label='Absolute discrepancy [nominal m]')
   axes[1,0].set_title(f'Absolute discrepancy — paired rays only\nmasked={int((~paired).sum()):,}; display clipped >1={clips["absoluteAbove1"]}')
   im=axes[1,1].imshow(status,origin='upper',interpolation='nearest',cmap=avail_cmap,norm=avail_norm)
   cb=fig.colorbar(im,ax=axes[1,1],ticks=[0,1,2,3]);cb.ax.set_yticklabels(['Paired','Sensor only','Reference only','Neither'])
   axes[1,1].set_title(f'Four-way saved availability — not free space\npaired={counts["paired"]:,}; sensor-only={counts["sensorOnly"]:,}; ref-only={counts["referenceOnly"]:,}; neither={counts["neither"]:,}')
   im=axes[1,2].imshow(edge,origin='upper',interpolation='nearest',cmap=edge_cmap,norm=edge_norm)
   cb=fig.colorbar(im,ax=axes[1,2],ticks=[-1,0,1,2,3,4]);cb.ax.set_yticklabels(['No reference','Raster boundary','Support boundary','Delta ≤ .02','.02 < delta ≤ .10','Delta > .10'])
   axes[1,2].set_title('Fixed stored reference-edge categories\nNo recomputed edges, threshold fitting or smoothing')
   for ax in axes.flat:ax.set_xlabel('Scheduled column index (×4 = source column)');ax.set_ylabel('Scheduled row index (×4 = source row)');ax.title.set_fontsize(10)
   for ax in fig.axes:ax.tick_params(labelsize=8)
   fig.suptitle(f'ANALYTICAL DIAGNOSTICS · Koivu {name} · 249×185 stride-4 scheduled grid\nNominal registered units; original confidence/tracking unavailable; NOT hazard detection or independent accuracy proof',fontsize=13)
   panel=OUT/'panels'/(name+'-analytic-panel.png');fig.savefig(panel,dpi=110);plt.close(fig);gc.collect();budget.check()
   member=f'room_datasets/koivu/iphone/long_capture/images/{name}.jpg';original=DATA/'recorded_subset'/member;rgb=OUT/'original-rgb'/(name+'.jpg')
   with original.open('rb') as source,rgb.open('xb') as target:shutil.copyfileobj(source,target,1024**2)
   if sha(rgb)!=selected[member]['sha256']:raise ValueError('byte-identical RGB copy mismatch')
   for p,kind in [(panel,'analytical saved-array display'),(rgb,'untouched original RGB JPEG')]:outputs.append({'path':str(p.relative_to(OUT)),'kind':kind,'bytes':p.stat().st_size,'sha256':sha(p)})
   displays.append({'frame':name,'scheduledGridShape':[249,185],'counts':counts,'displayClippedCounts':clips})
   print(json.dumps({'frame':name,'panel':str(panel),'byteIdenticalRGB':str(rgb),'resources':budget.check()}),flush=True)
  for entry in inputs:
   if sha(Path(entry['path']))!=entry['sha256']:raise ValueError('input/source changed during display generation')
  (OUT/'ATTRIBUTION.md').write_text('Original RGB: MuSHRoom Koivu iPhone long capture, official Zenodo record https://zenodo.org/records/10230733 , CC BY 4.0 https://creativecommons.org/licenses/by/4.0/ . Original archive SHA-256 '+ARCHIVE_SHA+'. RGB JPEG copies are byte-identical to the original selected archive members. Separate PNG panels are analytical visualizations of frozen processed-depth/reference-comparison arrays, not original sensor imagery or AI-generated scenes. No holes filled, no depth/raycast rerun, and no confidence/tracking fabricated. No physical-accuracy, obstacle/hazard detection, body-clearance or navigation success is established.\n')
  resources=budget.check()
  receipt={'status':'completed derived display only','sourceInputs':inputs,'sourceAndNPZHashesVerifiedBeforeAndAfter':True,'outputs':outputs,'frames':displays,
   'fixedDisplayRanges':{'depthNominalMetres':[.15,8],'signedDiscrepancy':[-1,1],'absoluteDiscrepancy':[0,1]},
   'interpolation':'nearest; no filled holes','originalRGBByteIdentical':True,'newVTKOrRaycastOrDepthDecode':False,'registrationFitted':False,'detectorOrNavigationCalled':False,
   'resourceBounds':{'cpuSeconds':CPU,'wallSeconds':WALL,'observedPeakRSSBytes':RSS,'allStage06Bytes':CAP,'freeReserveBytes':RESERVE},'resourcesBeforeReceipt':resources}
  dump(OUT/'INSPECTION_RECEIPT.json',receipt);budget.check();budget.stop.set();signal.alarm(0);OUT.rename(FINAL)
  print(json.dumps({'status':'completed','directory':str(FINAL),'panels':8,'originalRGBs':8,'resources':resources}),flush=True)
 except BaseException as error:
  budget.stop.set();signal.alarm(0)
  try:dump(OUT/'FAILURE_RECEIPT.json',{'error':repr(error),'partialRetained':True,'resources':budget.values(),'noComparisonRerun':True})
  except Exception:pass
  raise
if __name__=='__main__':main()

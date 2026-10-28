"""Read saved raw voxels and saved partial corridors only; no native rerun."""
from pathlib import Path
import os,resource,time,json,math,hashlib
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))});resource.setrlimit(resource.RLIMIT_AS,(1024**3,1024**3));resource.setrlimit(resource.RLIMIT_CPU,(60,60));start=time.monotonic()
import numpy as np
from PIL import Image,ImageDraw,ImageFont
H=Path(__file__).resolve().parent;ROOT=H.parents[2];f=json.loads((H/'FROZEN_INPUTS_AND_ANCHORS.json').read_text());r=json.loads((H/'RECORDED_RESULT.json').read_text());DT=np.dtype([('x','<f4'),('y','<f4'),('z','<f4'),('size','<f4'),('p','<f4'),('type','<i4'),('node','<i4'),('occupied','<i4')]);a=np.memmap(ROOT/f['files'][0]['path'],dtype=DT,mode='r');a=a[a['occupied']==1]
W,HGT=1800,1240;im=Image.new('RGB',(W,HGT),'#f4f6fa');d=ImageDraw.Draw(im)
font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(n):return ImageFont.truetype(font_path,n)
F=font(19);SM=font(16);TITLE=font(30);HD=font(23)
def txt(pos,s,fill='#1c2738',ff=F):d.text(pos,s,fill=fill,font=ff)
txt((36,24),'Corrected OctoMap: real occupancy + saved partial projected corridors',ff=TITLE)
txt((36,68),'0 complete projected corridors   |   18 association failures   |   2 partial corridors   |   0 movement episodes')
txt((36,101),'All requested-route, endpoint-connection and evidence-qualified admission flags remain false.',fill='#a1234a')
colors=['#d82e85','#e17617'];partial=[q for q in r['queries']if q['status']=='partialProjectedCorridor']
def panel(box,bounds,title):
 x0,y0,x1,y1=box;loX,hiX,loY,hiY=bounds;scale=min((x1-x0)/(hiX-loX),(y1-y0)/(hiY-loY));ox=x0+((x1-x0)-(hiX-loX)*scale)/2;oy=y1-((y1-y0)-(hiY-loY)*scale)/2
 def px(x,y):return (ox+(x-loX)*scale,oy-(y-loY)*scale)
 txt((x0,y0-32),title,ff=HD);p0=px(loX,hiY);p1=px(hiX,loY);d.rectangle((*p0,*p1),fill='#ffffff',outline='#74839b',width=1)
 for x in range(math.ceil(loX),math.floor(hiX)+1):
  u,v=px(x,loY);uu,vv=px(x,hiY);d.line((u,v,uu,vv),fill='#e0e6ef');txt((u-9,v+5),str(x),ff=SM)
 for y in range(math.ceil(loY),math.floor(hiY)+1):
  u,v=px(loX,y);uu,vv=px(hiX,y);d.line((u,v,uu,vv),fill='#e0e6ef');txt((u-33,v-9),str(y),ff=SM)
 # Exact closed XY extent of every occupied voxel intersecting this panel. All heights projected.
 m=(a['x']+a['size']/2>=loX)&(a['x']-a['size']/2<=hiX)&(a['y']+a['size']/2>=loY)&(a['y']-a['size']/2<=hiY)
 b=a[m]
 for ground,col in [(True,'#b7d8d0'),(False,'#7c8798')]:
  c=b[(b['type']==1)==ground]
  for row in c:
   x,y,s=float(row['x']),float(row['y']),float(row['size'])/2
   u,v=px(max(loX,x-s),min(hiY,y+s));uu,vv=px(min(hiX,x+s),max(loY,y-s));d.rectangle((u,v,uu,vv),fill=col)
 for i,q in enumerate(partial):
  path=q['result']['path'];points=[px(p[0],-p[2])for p in path]
  # Cropping is performed by the panel image boundary for local segments below.
  for p,bp in zip(path,path[1:]):
   if all(loX<=x<=hiX and loY<=y<=hiY for x,y in [(p[0],-p[2]),(bp[0],-bp[2])]):d.line((*px(p[0],-p[2]),*px(bp[0],-bp[2])),fill=colors[i],width=5)
  if path and loX<=path[-1][0]<=hiX and loY<=-path[-1][2]<=hiY:
   u,v=px(path[-1][0],-path[-1][2]);d.rectangle((u-4,v-4,u+4,v+4),fill=colors[i])
 for anchor in f['anchors']:
  i=anchor['anchorIndex'];x,y,_=anchor['provisionalTopDatasetWorldXYZ']
  if not(loX<=x<=hiX and loY<=y<=hiY):continue
  u,v=px(x,y);rr=.24*scale;d.ellipse((u-rr,v-rr,u+rr,v+rr),outline='#3a243f',width=2)
  d.ellipse((u-5,v-5,u+5,v+5),fill='#ffffff',outline='#392247',width=3);txt((u+8,v-26),'A'+str(i),fill='#392247',ff=HD)
  if i in [0,1]:
   q=next(q for q in r['queries']if q['startAnchorIndex']==i and q['result']['projectedStart']is not None);p=q['result']['projectedStart'];uu,vv=px(p[0],-p[2]);d.line((u,v,uu,vv),fill='#9634a2',width=2);d.polygon([(uu,vv-5),(uu+5,vv),(uu,vv+5),(uu-5,vv)],fill='#9634a2')
 return int(len(b))
count=panel((75,200,1030,1110),(-5.2,6.3,-5.6,5.6),'Full recorded occupancy, dataset WORLD XY metres')
counts=[count]
for n,anchor in enumerate(f['anchors'][:2]):
 x,y,_=anchor['provisionalTopDatasetWorldXYZ'];b=(1120,200+n*450,1760,585+n*450);counts.append(panel(b,(x-.85,x+.85,y-.65,y+.65),f'A{n}: partial corridor {partial[n]["projectedCandidateLengthMetres"]:.3f} m (not travel)'))
legend=[('#b7d8d0','Occupied native-ground label (not verified support)'),('#7c8798','Other occupied, ALL heights projected'),('#d82e85','Partial projected corridor A0 to A1'),('#e17617','Partial projected corridor A1 to A0')]
for i,(c,label)in enumerate(legend):
 xx=75+(i%2)*820;yy=1132+(i//2)*29;d.rectangle((xx,yy,xx+22,yy+18),fill=c);txt((xx+32,yy-2),label,ff=SM)
txt((75,1194),'White is not observed-free certification. Circles: synthetic planner radius 0.24m. Purple offsets are unchecked connectors.',fill='#a1234a',ff=SM)
im.save(H/'OCCUPANCY_AND_PARTIAL_CORRIDORS.png')
receipt={'source':'exact saved occupied leaf boxes; all-height XY projection; saved paths only','occupiedVoxels':len(a),'panelVoxelCounts':counts,'nativeQueriesRerun':0,'physicalAuthority':False,'elapsedSeconds':time.monotonic()-start,'peakSelfRSSBytes':resource.getrusage(resource.RUSAGE_SELF).ru_maxrss*1024,'figureSHA256':hashlib.sha256((H/'OCCUPANCY_AND_PARTIAL_CORRIDORS.png').read_bytes()).hexdigest()};(H/'FIGURE_RECEIPT.json').write_text(json.dumps(receipt,indent=2)+'\n');print(json.dumps(receipt))

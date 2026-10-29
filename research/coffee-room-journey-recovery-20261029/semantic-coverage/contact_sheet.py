from pathlib import Path
import json,hashlib
from PIL import Image,ImageOps,ImageDraw
R=Path(__file__).resolve().parent;s=json.loads((R/'SELECTION.json').read_text());a=json.loads((R/'ACQUISITION_RESULT.json').read_text());assert a['selectionSHA256']==hashlib.sha256((R/'SELECTION.json').read_bytes()).hexdigest();names=[n for n in s['members'] if '/images/' in n];assert len(names)==24
for page in range(2):
 sheet=Image.new('RGB',(1200,1230),'white');draw=ImageDraw.Draw(sheet)
 for j,name in enumerate(names[page*12:(page+1)*12]):
  p=R/'selected'/name;h=hashlib.sha256(p.read_bytes()).hexdigest();assert next(x for x in a['files'] if x['member']==name)['sha256']==h
  with Image.open(p) as img:
   assert img.width*img.height<10000000
   img=ImageOps.exif_transpose(img).convert('RGB');img.thumbnail((296,380));x=(j%4)*300;y=(j//4)*410;sheet.paste(img,(x,y+24));draw.text((x+4,y+5),p.stem,fill='black')
 sheet.save(R/f'contact-{page+1}.jpg',quality=92)
print('Two sheets; only original24 predetermined RGB frames, no geometry interpretation.')

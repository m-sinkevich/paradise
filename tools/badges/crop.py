# Кадрирование исходных фото из docx (word/media/imageN.png) → catalog/photos/<slug>.jpg
# Запуск: распаковать docx в папку docx/ рядом и выполнить python crop.py
from PIL import Image, ImageDraw
M={'magda':6,'alissia':4,'antoine':2,'tamara':3,'lin':16,'marcus':11,'dylan':1,'natella':13,'stepan':14,'ganesh':10,'giorgi':12,'silvio':15,'arsen':9,'eva':8,'mateo':7,'andrew':5}
AR=116/146
# (cx frac, top frac, crop height frac of H) ; default full width
OV={'marcus':(0.5,0.0,0.85),'natella':(0.372,0.0,1.0),'arsen':(0.43,0.02,0.92),'giorgi':(0.5,0.12,0.72),'stepan':(0.5,0.15,0.75),'silvio':(0.5,0.12,0.78),'andrew':(0.5,0.02,0.85),'ganesh':(0.5,0.05,0.85),'eva':(0.5,0.08,0.8),'lin':(0.48,0.05,0.85)}
out=[]
for slug,k in M.items():
    im=Image.open(f'docx/word/media/image{k}.png').convert('RGB'); W,H=im.size
    cx,tf,hf=OV.get(slug,(0.5,0.0,None))
    ch=H*hf if hf else min(H,W/AR); cw=ch*AR
    if cw>W: cw=W; ch=cw/AR
    left=max(0,min(cx*W-cw/2,W-cw)); top=max(0,min(tf*H,H-ch))
    c=im.crop((int(left),int(top),int(left+cw),int(top+ch))).resize((464,584),Image.LANCZOS)
    c.save(f'../../catalog/photos/{slug}.jpg',quality=86); out.append((slug,c))
sheet=Image.new('RGB',(8*170,2*230),'white'); d=ImageDraw.Draw(sheet)
for i,(s,c) in enumerate(out):
    t=c.resize((160,201)); x=(i%8)*170; y=(i//8)*230; sheet.paste(t,(x,y+20)); d.text((x,y+4),s,fill='black')
sheet.save('crops.jpg')

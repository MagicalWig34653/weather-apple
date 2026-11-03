from PIL import Image, ImageDraw, ImageFont
P='eigenentwurf-dark/previews/'
cols=[('Standard','eigenentwurf/previews/final/default.png','eigenentwurf/previews/final/default-60.png'),
('Dark final (aktuell)','eigenentwurf/previews/final/dark.png',None)]+[(n+(' gedaempft','' )[0] if 0 else n,P+n+'-dark-1024.png',P+n+'-dark-60.png') for n in ['d1','d2','d3','d4']]
labels=['Standard','Dark final','d1 gedaempft','d2 Nachtradar','d3 mono+Akzent','d4 Original x0,7']
S=420;M=30;W=len(cols)*(S+M)+M;H=S+120+M*3+30
im=Image.new('RGB',(W,H),(40,40,40));d=ImageDraw.Draw(im)
f=ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc',22)
def load(p):
    a=Image.open(p).convert('RGBA');return a
for i,(n,big,small) in enumerate(cols):
    x=M+i*(S+M)
    a=load(big).resize((S,S),Image.LANCZOS);im.paste(a,(x,M),a)
    d.text((x,M+S+8),labels[i],font=f,fill=(255,255,255))
    s=load(small) if small else load('eigenentwurf/previews/final-dark.png').resize((60,60),Image.LANCZOS)
    if small is None: s=load('eigenentwurf/previews/final/dark.png').resize((60,60),Image.LANCZOS)
    s=s.resize((60,60),Image.LANCZOS);im.paste(s,(x,M+S+50),s)
    s2=s.resize((29,29),Image.LANCZOS);im.paste(s2,(x+80,M+S+66),s2)
im.save(P+'vergleich.png')

#!/usr/bin/env python3
"""Uebersichtstafel: python3 make_overview.py v3a v3b ... (benoetigt Pillow)"""
import sys, os
from PIL import Image
H=os.path.dirname(os.path.abspath(__file__)); P=H+'/previews'
names=sys.argv[1:] or ['v3a','v3b','v3c','v3d']
cell=320; pad=24; bg=(236,236,240)
W=pad+len(names)*(cell+pad)
rows=[('default',cell),('dark',cell),('tinted',cell)]
Hh=pad+3*(cell+pad)+ (120+pad)
sheet=Image.new('RGB',(W,Hh),bg)
for i,n in enumerate(names):
    x=pad+i*(cell+pad); y=pad
    for kind,_ in rows:
        im=Image.open(f'{P}/{n}-{kind}.png').convert('RGBA').resize((cell,cell),Image.LANCZOS)
        sheet.paste(im,(x,y),im); y+=cell+pad
    xx=x
    for s in (120,60,29):
        im=Image.open(f'{P}/{n}-default-{s}.png').convert('RGBA'); sheet.paste(im,(xx,y),im); xx+=s+16
sheet.save(P+'/overview.png')
# Einzelblatt je Konzept zur Kontrolle (Default 1024->512 + kleine Groessen auf hell/dunkel)
for n in names:
    s=Image.new('RGB',(512+40+160,512+20),(236,236,240)); im=Image.open(f'{P}/{n}-default.png').convert('RGBA').resize((512,512),Image.LANCZOS); s.paste(im,(10,10),im)
    y=10
    for k in (120,60,29):
        im=Image.open(f'{P}/{n}-default-{k}.png').convert('RGBA'); s.paste(im,(540,y),im); y+=k+20
    s.save(f'{P}/_check-{n}.png')

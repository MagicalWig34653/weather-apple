#!/usr/bin/env python3
"""Uebersichtstafeln (Pillow noetig: pip3 install pillow). 
  python3 make_overview.py v4a v4b ...          -> previews/overview.png (v4)
  python3 make_overview.py --v3v4 v4a v4b ...   -> previews/overview-v3-v4.png (v3 oben, v4 unten, nur Default+Dark+Tinted je Zeile)"""
import sys, os
from PIL import Image, ImageDraw
H=os.path.dirname(os.path.abspath(__file__)); P4=H+'/previews'; P3=H+'/../v3/previews'
bg=(236,236,240)
def load(p,sz): return Image.open(p).convert('RGBA').resize((sz,sz),Image.LANCZOS)
def sheet(items, out, cell=320, pad=24):
    """items: Liste (Ordner, Name); Spalten je Konzept, Zeilen Default/Dark/Tinted + kleine Groessen"""
    W=pad+len(items)*(cell+pad); Hh=pad+3*(cell+pad)+120+pad
    im=Image.new('RGB',(W,Hh),bg)
    for i,(d,n) in enumerate(items):
        x=pad+i*(cell+pad); y=pad
        for kind in ('default','dark','tinted'):
            c=load(f'{d}/{n}-{kind}.png',cell); im.paste(c,(x,y),c); y+=cell+pad
        xx=x
        for s in (120,60,29):
            c=Image.open(f'{d}/{n}-default-{s}.png').convert('RGBA'); im.paste(c,(xx,y),c); xx+=s+16
    im.save(out)
if __name__=='__main__':
    a=sys.argv[1:]
    if a and a[0]=='--v3v4':
        names=a[1:] or ['v4a','v4b','v4c','v4d']
        # Zwei Blöcke nebeneinander: v3 (4 Konzepte) | v4 (4 Konzepte), gemeinsame Zeilen
        sheet([(P3,n) for n in ['v3a','v3b','v3c','v3d']]+[(P4,n) for n in names], P4+'/overview-v3-v4.png', cell=240, pad=18)
    else:
        names=a or ['v4a','v4b','v4c','v4d']
        sheet([(P4,n) for n in names], P4+'/overview.png')
        for n in names:   # Kontrollblatt: Default gross + Dark + Tinted
            s=Image.new('RGB',(3*532+10,532+150),bg); x=10
            for k in ('default','dark','tinted'):
                c=load(f'{P4}/{n}-{k}.png',512); s.paste(c,(x,10),c); x+=532
            xx=10
            for k in (120,60,29):
                c=Image.open(f'{P4}/{n}-default-{k}.png').convert('RGBA'); s.paste(c,(xx,540),c); xx+=k+20
            s.save(f'{P4}/_check-{n}.png')

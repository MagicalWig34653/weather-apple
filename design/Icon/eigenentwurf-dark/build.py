"""Erzeugt d1..d4.icon aus eigenentwurf-final.icon (nur Dark-Werte). Aufruf: python3 build.py (im Ordner design/Icon)"""
import json, shutil, os
std=dict(front=(0.231,0.612,0.878),band=(0.376,0.859,0.416),yel=(0.929,0.875,0.251),core=(0.918,0.212,0.098))
def muted(c,sat=0.78,v=0.72):
    g=sum(c)/3; return tuple((g+(x-g)*sat)*v for x in c)
V={
 'd1':dict(core=(0.88,0.32,0.16),yel=muted(std['yel']),band=muted(std['band']),front=muted(std['front'])),
 'd2':dict(core=(1.0,0.36,0.12),yel=(0.66,0.48,0.16),band=(0.10,0.50,0.50),front=(0.07,0.30,0.37)),
 'd3':dict(core=(1.0,0.72,0.20),yel=(0.52,0.70,0.94),band=(0.27,0.47,0.76),front=(0.16,0.30,0.52)),
 'd4':dict(core=tuple(x*0.7 for x in std['core']),yel=tuple(x*0.7 for x in std['yel']),band=tuple(x*0.7 for x in std['band']),front=tuple(x*0.7 for x in std['front'])),
}
def s(c): return "srgb:%.5f,%.5f,%.5f,1.00000"%c
src='eigenentwurf-final.icon'
for n,v in V.items():
    dst='eigenentwurf-dark/%s.icon'%n
    if os.path.exists(dst): shutil.rmtree(dst)
    shutil.copytree(src,dst)
    j=json.load(open(dst+'/icon.json'))
    m={(0,0):'core',(0,1):'yel',(1,0):'band',(2,0):'front'}
    for (g,l),k in m.items():
        for sp in j['groups'][g]['layers'][l]['fill-specializations']:
            if sp.get('appearance')=='dark': sp['value']={'solid':s(v[k])}
    json.dump(j,open(dst+'/icon.json','w'),indent=2)
    print(n,{k:tuple(round(x,3) for x in c) for k,c in v.items()})

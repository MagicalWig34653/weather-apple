#!/usr/bin/env python3
"""Erzeugt v3a..v3d als Icon-Composer-Pakete (.icon). Aufruf: python3 generate_v3.py"""
import json, math, os, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n{body}\n</svg>\n'
def rgb(h): h=h.lstrip('#'); return 'srgb:%.5f,%.5f,%.5f,1.00000'%tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
def solid(h): return {"solid": rgb(h)}
def grad(top, bottom): return {"linear-gradient":[rgb(top), rgb(bottom)], "orientation":{"start":{"x":0.5,"y":0},"stop":{"x":0.5,"y":1}}}
def layer(name, img, glass=True, fill="automatic", opacity=1):
    return {"image-name": img, "name": name, "glass": glass, "fill": fill, "opacity": opacity, "hidden": False}
def group(layers, spec=True, shadow=0.35, translucency=None):
    return {"layers": layers, "hidden": False, "lighting": "individual",
            "shadow": {"kind": "neutral", "opacity": shadow}, "specular": spec,
            "translucency": {"enabled": translucency is not None, "value": translucency or 0}}
def package(name, bg, bg_dark, layers, groups):
    d = os.path.join(HERE, name+'.icon')
    shutil.rmtree(d, ignore_errors=True); os.makedirs(d+'/Assets')
    for fn, body in layers.items(): open(f'{d}/Assets/{fn}','w').write(svg(body))
    j = {"fill": bg,
         "fill-specializations": [{"value": bg}, {"appearance": "dark", "value": bg_dark}],
         "groups": groups,
         "supported-platforms": {"circles": ["watchOS"], "squares": "shared"}}
    json.dump(j, open(d+'/icon.json','w'), indent=2)
def pt(cx, cy, r, deg): a = math.radians(deg); return (cx + r*math.sin(a), cy - r*math.cos(a))
def sector(cx, cy, r, a0, a1):
    x0,y0 = pt(cx,cy,r,a0); x1,y1 = pt(cx,cy,r,a1); large = 1 if (a1-a0) > 180 else 0
    return f'M{cx},{cy} L{x0:.1f},{y0:.1f} A{r},{r} 0 {large} 1 {x1:.1f},{y1:.1f} Z'
def sector_poly(cx, cy, r, a0, a1, n=48):
    pts=[(cx,cy)]+[pt(cx,cy,r,a0+(a1-a0)*k/n) for k in range(n+1)]
    return '<polygon fill="#FFC21A" points="'+' '.join(f'{x:.1f},{y:.1f}' for x,y in pts)+'"/>'
def capsule(x0,y0,x1,y1,w,fill): return f'<line x1="{x0}" y1="{y0}" x2="{x1}" y2="{y1}" stroke="{fill}" stroke-width="{w}" stroke-linecap="round"/>'

# v3a Radar-Scope/Zeitring: dicker weisser Ring (Zeitachse) + gelber Sweep-Sektor (jetzt bis +Zeit)
C=512
ring = f'<circle cx="{C}" cy="{C}" r="315" fill="none" stroke="#FFFFFF" stroke-width="90"/>'
sec = sector_poly(C,C,235,0,120)
package('v3a', grad('#2E8BFF','#0B47C9'), grad('#16346F','#0A1D45'),
  {'ring.svg': ring, 'sweep.svg': sec},
  [group([layer('Sweep','sweep.svg')]), group([layer('Ring','ring.svg')])])

# v3b Regenstriche: drei grosse schraege Kapseln, keine Wolke
s = capsule(360,210,235,640,140,'#FFFFFF') + capsule(610,330,470,800,140,'#FFC21A') + capsule(815,190,700,580,140,'#8FE3FF')
package('v3b', grad('#1D5FEA','#0A2E8F'), grad('#14295F','#091533'),
  {'streaks.svg': s}, [group([layer('Regen','streaks.svg')])])

# v3c Sonne + Regenzelle: zwei grosse ueberlappende Kreise
package('v3c', grad('#3A7BFF','#1840B8'), grad('#17306B','#0B1A45'),
  {'sun.svg': '<circle cx="385" cy="385" r="215" fill="#FFC21A"/>',
   'cell.svg': '<circle cx="610" cy="610" r="300" fill="#FFFFFF"/>'},
  [group([layer('Sonne','sun.svg')]), group([layer('Regenzelle','cell.svg')])])

# v3d Schirm: ein grosses, eindeutiges Regenmotiv ohne Wolke/Tropfen, leicht geneigt, kraeftiger Griff
rot = 'transform="rotate(-12 512 512)"'
canopy = (f'<g {rot}><path fill="#FFC21A" d="M172,500 A340,340 0 0 1 852,500 A113.33,113.33 0 0 1 625.3,500 A113.33,113.33 0 0 1 398.7,500 A113.33,113.33 0 0 1 172,500 Z"/></g>')
handle = (f'<g {rot}><path fill="none" stroke="#FFFFFF" stroke-width="96" stroke-linecap="round" '
          'd="M512,480 V740 A92,92 0 0 1 328,740"/></g>')
package('v3d', grad('#12A8D6','#0A4FA8'), grad('#0F3A4A','#08202E'),
  {'canopy.svg': canopy, 'handle.svg': handle},
  [group([layer('Schirm','canopy.svg')]), group([layer('Griff','handle.svg')])])

#!/usr/bin/env python3
"""Erzeugt v2a/v2b/v2c als Icon-Composer-Pakete (.icon). Aufruf: python3 generate_v2.py"""
import json, os
HERE = os.path.dirname(os.path.abspath(__file__))
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n{body}\n</svg>\n'
def circle(cx,cy,r,fill,extra=''): return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" {extra}/>'
def cloud(fill, dx=0, dy=0):
    return (f'<g transform="translate({dx} {dy})" fill="{fill}">'
            '<rect x="215" y="540" width="600" height="190" rx="95"/>'
            '<circle cx="400" cy="520" r="150"/><circle cx="580" cy="450" r="185"/><circle cx="700" cy="580" r="130"/></g>')
def drop(fill, cx, cy, s=1.0):
    return (f'<g transform="translate({cx} {cy}) scale({s})" fill="{fill}">'
            '<path d="M0,-150 C45,-85 100,-35 100,45 A100,100 0 0 1 -100,45 C-100,-35 -45,-85 0,-150Z"/></g>')
def rgb(h): h=h.lstrip('#'); return 'srgb:%.5f,%.5f,%.5f,1.00000'%tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
def group(name, img, glass=True, spec=True, dark_fill=None):
    layer = {"image-name": img, "name": name, "glass": glass, "fill": "automatic", "opacity": 1, "hidden": False}
    return {"layers":[layer], "hidden":False, "lighting":"individual",
            "shadow":{"kind":"neutral","opacity":0.35}, "specular":spec,
            "translucency":{"enabled":False,"value":0}}
def package(name, bg, bg_dark, layers, groups):
    d = os.path.join(HERE, name+'.icon'); os.makedirs(d+'/Assets', exist_ok=True)
    for fn, body in layers.items(): open(f'{d}/Assets/{fn}','w').write(svg(body))
    j = {"fill":{"solid":rgb(bg)},
         "fill-specializations":[{"value":{"solid":rgb(bg)}},{"appearance":"dark","value":{"solid":rgb(bg_dark)}}],
         "groups":groups,
         "supported-platforms":{"circles":["watchOS"],"squares":"shared"}}
    json.dump(j, open(d+'/icon.json','w'), indent=2)

# v2a: Radar behalten, 3 konzentrische Scheiben (Blau, Gruen, Gelb)
package('v2a','#1769E0','#0A2D6E',{
  'radar.svg': circle(512,512,370,'#FFFFFF','fill-opacity="0.30"')+circle(512,512,255,'#18B26B')+circle(512,512,120,'#FFC21A'),
},[group('Radar','radar.svg')])

# v2b: Wolke (weiss) + ein grosser gelber Tropfen
package('v2b','#1769E0','#0A2D6E',{
  'cloud.svg': cloud('#FFFFFF', -10, -100),
  'drop.svg':  drop('#FFC21A', 600, 795, 0.95),
},[group('Wolke','cloud.svg'),group('Tropfen','drop.svg')])

# v2c: maximal reduziert, ein grosser weisser Tropfen mit Radar-Ring
package('v2c','#0A84FF','#06265A',{
  'rain.svg': circle(512,512,380,'#FFFFFF','fill-opacity="0.25"')+drop('#FFFFFF', 512, 560, 2.0),
},[group('Tropfen mit Ring','rain.svg')])

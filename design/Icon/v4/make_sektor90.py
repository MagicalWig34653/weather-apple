#!/usr/bin/env python3
"""Erzeugt v4b-sektor90.icon und v4b-sektor90-uebergang.icon aus v4b-original.icon (Aufruf: python3 make_sektor90.py).
Winkelkonvention der SVGs (generate_v4.py, pt()): Kompasswinkel, 0 Grad = oben (12 Uhr), im Uhrzeigersinn, Mittelpunkt (512,512) = weisser Punkt.
Original: Sektor -8..80 Grad (sw1), 30..80 (sw2), 60..80 (sw3). Neu: 0..90 (sw1), 40..90 (sw2), 70..90 (sw3) = Viertelkreis 12 bis 3 Uhr.
Variante 'uebergang': Sektor-Fill = Verlauf der Nutzerfassung (Gruen, Alpha 0.30 -> 1.0), Richtung wie dort (start (0,0) -> stop (1,0.814), ca. 39 Grad, y nach unten), auf die Sektor-Bounding-Box skaliert."""
import json, math, os, shutil, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from generate_v4 import wedge, P, svg
C, R = 512, 372
ANG = {'sw1': (0, 90), 'sw2': (40, 90), 'sw3': (70, 90)}
GREEN_A = "display-p3:0.44053,0.82207,0.44527,0.30000"; GREEN_B = "extended-srgb:0.20392,0.78039,0.34902,1.00000"
DARK_A = "srgb:0.74902,0.81569,1.00000,0.30000"; DARK_B = "srgb:0.74902,0.81569,1.00000,1.00000"
OPACITY = {"sw1": 0.75, "sw2": 0.45, "sw3": 0.45}   # nur Uebergangsvariante (Original: 0.18/0.30/0.50)
def orient():
    # Sektor 0..90 = Viertelkreis rechts oben: Bounding-Box x 0.5..0.863, y 0.137..0.5
    cx, cy, span = 0.5 + 0.363/2, 0.5 - 0.363/2, 0.363
    a = math.atan2(0.8140708780160858, 1.0); dx, dy = math.cos(a), math.sin(a); h = span*(abs(dx)+abs(dy))/2
    return {"start": {"x": round(cx-dx*h, 4), "y": round(cy-dy*h, 4)}, "stop": {"x": round(cx+dx*h, 4), "y": round(cy+dy*h, 4)}}
def build(name, gradient):
    src, dst = os.path.join(HERE, 'v4b-original.icon'), os.path.join(HERE, name+'.icon')
    shutil.rmtree(dst, ignore_errors=True); shutil.copytree(src, dst)
    for k, (a0, a1) in ANG.items(): open(f'{dst}/Assets/{k}.svg', 'w').write(svg(P(wedge(C, C, R, a0, a1))))
    p = os.path.join(dst, 'icon.json'); j = json.load(open(p))
    if gradient:
        for g in j['groups']:
            for l in g['layers']:
                if l['image-name'].startswith('sw'):
                    l['opacity-specializations'] = [{"value": OPACITY[l['image-name'][:3]]}]
                    tinted = [s for s in l['fill-specializations'] if s.get('appearance') == 'tinted']
                    l['fill-specializations'] = [{"value": {"linear-gradient": [GREEN_A, GREEN_B], "orientation": orient()}},
                        {"appearance": "dark", "value": {"linear-gradient": [DARK_A, DARK_B], "orientation": orient()}}] + tinted
    json.dump(j, open(p, 'w'), indent=2)
if __name__ == '__main__':
    build('v4b-sektor90', False); build('v4b-sektor90-uebergang', True)

#!/usr/bin/env python3
"""Erzeugt v4a..v4d als Icon-Composer-Pakete (.icon). Aufruf: python3 generate_v4.py
Befund Runde 4: fill-specializations (Dark/Tinted) wirken in ictool/Icon Composer nur, wenn KEIN Top-Level-"fill"
(und bei Ebenen kein Basis-"fill") neben den Specializations steht. Deshalb: nur Specializations, Basisfarbe als Eintrag ohne appearance.
Alle Ebenen-SVGs sind weisse Masken (flach, voll deckend, scharfe Kanten); Farbe/Deckkraft kommen per Fill/Opacity aus icon.json."""
import json, math, os, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
def svg(body): return f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n{body}\n</svg>\n'
def rgb(h): h=h.lstrip('#'); return 'srgb:%.5f,%.5f,%.5f,1.00000'%tuple(int(h[i:i+2],16)/255 for i in (0,2,4))
def solid(h): return {"solid": rgb(h)}
def grad(top, bottom): return {"linear-gradient":[rgb(top), rgb(bottom)], "orientation":{"start":{"x":0.5,"y":0},"stop":{"x":0.5,"y":1}}}
def gray(v): return {"solid": "extended-gray:%.5f,1.00000" % v}
def spec(default, dark, tinted=None):
    s=[{"value":default},{"appearance":"dark","value":dark}]
    if tinted is not None: s.append({"appearance":"tinted","value":tinted})
    return s
def layer(name, img, col, dark, tint, opacity=1.0, dark_opacity=None, tint_opacity=None, glass=True):
    """col/dark: Hex; tint: Grauwert 0..1 (Mono/Tinted-Annotation)"""
    d={"image-name":img,"name":name,"glass":glass,"hidden":False,
       "fill-specializations":spec(solid(col),solid(dark),gray(tint))}
    o=[{"value":opacity}]
    if dark_opacity is not None: o.append({"appearance":"dark","value":dark_opacity})
    if tint_opacity is not None: o.append({"appearance":"tinted","value":tint_opacity})
    d["opacity-specializations"]=o
    return d
def group(layers, spec_on=True, shadow=0.30, trans=None, shadow_kind="neutral"):
    return {"layers": layers, "hidden": False, "lighting": "individual",
            "shadow": {"kind": shadow_kind, "opacity": shadow}, "specular": spec_on,
            "translucency": {"enabled": trans is not None, "value": trans or 0}}
def package(name, bg, bg_dark, files, groups):
    d = os.path.join(HERE, name+'.icon')
    shutil.rmtree(d, ignore_errors=True); os.makedirs(d+'/Assets')
    for fn, body in files.items(): open(f'{d}/Assets/{fn}','w').write(svg(body))
    j = {"fill-specializations": [{"value": bg}, {"appearance":"dark","value": bg_dark}],
         "groups": groups, "supported-platforms": {"circles": ["watchOS"], "squares": "shared"}}
    json.dump(j, open(d+'/icon.json','w'), indent=2)
W='#FFFFFF'
def P(d, extra=''): return f'<path fill="{W}" {extra} d="{d}"/>'
def rot(a, cx, cy, inner): return f'<g transform="rotate({a} {cx} {cy})">{inner}</g>'
def f(v): return ('%.1f'%v).rstrip('0').rstrip('.')

# ---------- Tropfen mit korrekter Kurve: Spitze oben (leicht gerundet), Kugel unten, konkave Flanken ----------
def drop(cx, tip_y, h, r, tipr=7):
    by = tip_y + h - r                      # Kugelmittelpunkt
    d = by - tip_y; al = math.asin(r/d)
    px, py = r*math.cos(al), by - r*math.sin(al)   # Tangentenpunkt rechts (relativ cx)
    # Flanke: kubisch von Spitze zum Tangentenpunkt; C1 nach innen gezogen => leicht konkav (organisch)
    t = (px, py - tip_y)
    c1 = (tipr*0.2 + t[0]*0.10, tip_y + t[1]*0.38)
    c2 = (px - t[0]*0.30, py - t[1]*0.30)       # kollinear zur Tangente im Anschluss
    L=lambda x: cx - x; R=lambda x: cx + x
    return (f'M{f(cx-tipr)},{f(tip_y+tipr*1.6)} Q{f(cx)},{f(tip_y-tipr*0.3)} {f(cx+tipr)},{f(tip_y+tipr*1.6)} '
            f'C{f(R(c1[0]+tipr))},{f(c1[1])} {f(R(c2[0]))},{f(c2[1])} {f(R(px))},{f(py)} '
            f'A{r},{r} 0 1 1 {f(L(px))},{f(py)} '
            f'C{f(L(c2[0]))},{f(c2[1])} {f(L(c1[0]+tipr))},{f(c1[1])} {f(cx-tipr)},{f(tip_y+tipr*1.6)} Z')

# ---------- Schirm ----------
HW, AX, AY = 335, 512, 168          # halbe Breite, Scheitel
TY = {-1:512, -1/3:548, 1/3:548, 1:512}   # Spitzen: Mitte tiefer (Wölbung zum Betrachter)
def rib(t):
    x=AX+HW*t; y=TY[t]
    return (f'{f(AX+HW*t*0.60)},{f(AY+6)}', f'{f(x)},{f(AY+(y-AY)*0.42)}', f'{f(x)},{f(y)}')
def seg(t):    return 'C'+' '.join(rib(t))                          # Scheitel -> Spitze t
def seg_rev(t):
    c1,c2,e=rib(t); return f'C{c2} {c1} {AX},{AY}'                  # Spitze t -> Scheitel
SC={(1,1/3):f'{f(AX+HW*0.67)},{f(466)}', (1/3,-1/3):f'{AX},{f(480)}', (-1/3,-1):f'{f(AX-HW*0.67)},{f(466)}'}
def tip(t): return f'{f(AX+HW*t)},{f(TY[t])}'
def umbrella_parts():
    outline=(f'M{AX},{AY} {seg(1)} Q{SC[(1,1/3)]} {tip(1/3)} Q{SC[(1/3,-1/3)]} {tip(-1/3)} Q{SC[(-1/3,-1)]} {tip(-1)} {seg_rev(-1)} Z')
    center=f'M{AX},{AY} {seg(-1/3)} Q{SC[(1/3,-1/3)]} {tip(1/3)} {seg_rev(1/3)} Z'
    left =f'M{AX},{AY} {seg(-1)} Q{SC[(-1/3,-1)]} {tip(-1/3)} {seg_rev(-1/3)} Z'
    right=f'M{AX},{AY} {seg(1)} Q{SC[(1,1/3)]} {tip(1/3)} {seg_rev(1/3)} Z'
    return outline, center, left, right

def build_v4a():
    outline, center, left, right = umbrella_parts()
    rj='stroke-linejoin="round" stroke="#FFFFFF" stroke-width="26"'   # Spitzen weich runden
    T=-9
    canopy = rot(T,512,520, P(outline, rj))
    sides  = rot(T,512,520, P(left, rj)+P(right, rj))
    shaft = (f'<path fill="none" stroke="{W}" stroke-width="64" stroke-linecap="round" d="M512,420 V770 A82,82 0 0 1 348,770"/>'
             f'<rect x="495" y="112" width="34" height="110" rx="17" fill="{W}"/>')
    handle = rot(T,512,520, shaft)
    drops = (P(drop(150,650,190,62)) + P(drop(884,710,150,50)) + P(drop(130,330,120,40)))
    files={'drops.svg':drops,'canopy.svg':canopy,'sides.svg':sides,'handle.svg':handle}
    package('v4a', grad('#22B4E6','#0B3C9E'), grad('#123C5C','#08182C'), files, [
      group([layer('Bahnen','sides.svg','#F0820F','#B5690F',0.55, opacity=0.55),
             layer('Dach','canopy.svg','#FFC21A','#E8A91A',0.82)], shadow=0.35),
      group([layer('Griff','handle.svg','#FFFFFF','#E6F4FF',1.0)], shadow=0.30),
      group([layer('Tropfen','drops.svg','#CFF5FF','#5FA8C8',0.62, opacity=0.78)], shadow=0.20, trans=0.35)])

# ---------- Radar ----------
def pt(cx, cy, r, deg): a = math.radians(deg); return (cx + r*math.sin(a), cy - r*math.cos(a))
def wedge(cx, cy, r, a0, a1):
    x0,y0=pt(cx,cy,r,a0); x1,y1=pt(cx,cy,r,a1)
    return f'M{cx},{cy} L{f(x0)},{f(y0)} A{r},{r} 0 {1 if a1-a0>180 else 0} 1 {f(x1)},{f(y1)} Z'
def blob(cx, cy, s):
    """organische Regenzelle: 3 Lappen, kubisch; Ausdehnung etwa 2s x 1.6s"""
    q=lambda x,y:(f(cx+x*s),f(cy+y*s))
    pts=[q(-1.0,0.45),q(-1.1,-0.10),q(-0.55,-0.55),q(-0.25,-0.55)]
    return (f'M{q(-0.75,0.62)[0]},{q(-0.75,0.62)[1]} C{q(-1.15,0.62)[0]},{q(-1.15,0.62)[1]} {q(-1.2,-0.05)[0]},{q(-1.2,-0.05)[1]} {q(-0.78,-0.15)[0]},{q(-0.78,-0.15)[1]} '
            f'C{q(-0.80,-0.62)[0]},{q(-0.80,-0.62)[1]} {q(-0.15,-0.95)[0]},{q(-0.15,-0.95)[1]} {q(0.12,-0.52)[0]},{q(0.12,-0.52)[1]} '
            f'C{q(0.40,-0.82)[0]},{q(0.40,-0.82)[1]} {q(1.12,-0.55)[0]},{q(1.12,-0.55)[1]} {q(1.05,0.05)[0]},{q(1.05,0.05)[1]} '
            f'C{q(1.20,0.20)[0]},{q(1.20,0.20)[1]} {q(1.10,0.62)[0]},{q(1.10,0.62)[1]} {q(0.75,0.62)[0]},{q(0.75,0.62)[1]} Z')

def smooth_closed(pts):
    n=len(pts); d=f'M{f(pts[0][0])},{f(pts[0][1])} '
    for i in range(n):
        p0,p1,p2,p3=pts[(i-1)%n],pts[i],pts[(i+1)%n],pts[(i+2)%n]
        c1=(p1[0]+(p2[0]-p0[0])/6, p1[1]+(p2[1]-p0[1])/6); c2=(p2[0]-(p3[0]-p1[0])/6, p2[1]-(p3[1]-p1[1])/6)
        d+=f'C{f(c1[0])},{f(c1[1])} {f(c2[0])},{f(c2[1])} {f(p2[0])},{f(p2[1])} '
    return d+'Z'
def echo(cx, cy, s, radii, rot0=0, sx=1.0):
    n=len(radii); return smooth_closed([(cx+sx*s*r*math.sin(math.radians(rot0+360*i/n)), cy-s*r*math.cos(math.radians(rot0+360*i/n))) for i,r in enumerate(radii)])

def build_v4b():
    C=512
    rings = (f'<circle cx="{C}" cy="{C}" r="372" fill="{W}"/>')
    ring2 = f'<circle cx="{C}" cy="{C}" r="262" fill="{W}"/>'
    ring3 = f'<circle cx="{C}" cy="{C}" r="150" fill="{W}"/>'
    sw1 = P(wedge(C,C,372,-8,80)); sw2 = P(wedge(C,C,372,30,80)); sw3 = P(wedge(C,C,372,60,80))
    cell = P(blob(648,352,128)); dot=f'<circle cx="{C}" cy="{C}" r="46" fill="{W}"/>'
    files={'r1.svg':rings,'r2.svg':ring2,'r3.svg':ring3,'sw1.svg':sw1,'sw2.svg':sw2,'sw3.svg':sw3,'cell.svg':cell,'dot.svg':dot}
    package('v4b', grad('#3A6BFF','#0F1F86'), grad('#18235E','#090F33'), files, [
      group([layer('Zelle','cell.svg','#FFC21A','#E8A91A',0.92), layer('Ort','dot.svg','#FFFFFF','#EAF0FF',1.0)], shadow=0.30),
      group([layer('Sweep 3','sw3.svg','#FFFFFF','#BFD0FF',0.85, opacity=0.50),
             layer('Sweep 2','sw2.svg','#FFFFFF','#BFD0FF',0.75, opacity=0.30),
             layer('Sweep 1','sw1.svg','#FFFFFF','#BFD0FF',0.65, opacity=0.18)], shadow=0.15, trans=0.0),
      group([layer('Ring innen','r3.svg','#FFFFFF','#9DB4FF',0.9, opacity=0.18),
             layer('Ring mitte','r2.svg','#FFFFFF','#9DB4FF',0.9, opacity=0.14),
             layer('Ring aussen','r1.svg','#FFFFFF','#9DB4FF',0.9, opacity=0.12)], shadow=0.15, trans=0.5)])

# ---------- Regenwolke ----------
def cloud_path(x0,y0,s=1.0):
    pts = """M130,440 C58,440 0,384 0,314 C0,246 52,194 118,192 C138,190 156,193 170,198
      C186,92 266,6 366,6 C440,6 502,52 524,118 C536,122 552,122 566,120
      C590,98 640,90 672,118 C700,142 706,200 706,270 C706,372 650,440 570,440 Z"""
    import re
    nums=[float(v) for v in re.findall(r'-?\d+\.?\d*', pts)]
    out=[]; i=0
    for tok in re.findall(r'[MCZL]|-?\d+\.?\d*,-?\d+\.?\d*', pts):
        if tok in 'MCZL': out.append(tok)
        else:
            x,y=tok.split(','); out.append(f(x0+float(x)*s)+','+f(y0+float(y)*s))
    return ' '.join(out)
def build_v4c():
    front = P(cloud_path(250,300,0.80)); back = P(cloud_path(110,160,0.58))
    drops = P(drop(372,600,200,64)) + P(drop(560,660,220,70)) + P(drop(744,610,170,54))
    files={'front.svg':front,'back.svg':back,'drops.svg':drops}
    package('v4c', grad('#6A5CFF','#1B1F8F'), grad('#241F5E','#0E0C2E'), files, [
      group([layer('Tropfen','drops.svg','#FFC21A','#E8A91A',0.80)], shadow=0.30),
      group([layer('Wolke vorn','front.svg','#FFFFFF','#E8EEFF',1.0, opacity=0.96)], shadow=0.35, trans=0.25),
      group([layer('Wolke hinten','back.svg','#A9CBFF','#6E8CC0',0.55, opacity=0.70)], shadow=0.20, trans=0.4)])

# ---------- Tropfen-Pin ----------
def build_v4d():
    big = P(drop(512,150,700,225))
    inner = '<circle cx="512" cy="625" r="118" fill="#FFFFFF"/>'
    ringA = '<circle cx="512" cy="512" r="440" fill="#FFFFFF"/>'
    ringB = '<circle cx="512" cy="512" r="330" fill="#FFFFFF"/>'
    files={'drop.svg':big,'place.svg':inner,'rA.svg':ringA,'rB.svg':ringB}
    package('v4d', grad('#16C3C9','#0A4F9C'), grad('#0F4C58','#071F3A'), files, [
      group([layer('Ort','place.svg','#0F5DB8','#0B2D52',0.10, glass=False)], shadow=0.25),
      group([layer('Tropfen','drop.svg','#FFFFFF','#DDF3FF',1.0, opacity=0.96)], shadow=0.35, trans=0.3),
      group([layer('Welle innen','rB.svg','#FFFFFF','#8FD8E8',0.55, opacity=0.18),
             layer('Welle aussen','rA.svg','#FFFFFF','#8FD8E8',0.55, opacity=0.12)], shadow=0.10, trans=0.5)])

if __name__=='__main__':
    import sys
    for n in (sys.argv[1:] or ['a','b','c','d']): globals()['build_v4'+n]()

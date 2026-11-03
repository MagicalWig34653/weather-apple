#!/usr/bin/env python3
"""Baut design/Icon/overview/all-icons.png und index.html aus den ictool-Vorschauen.
Pillow noetig (nicht im Repo installiert): PYTHONPATH=<ordner mit PIL> python3 build_overview.py
Quellen: design/Icon/<runde>/previews/<name>-{default,dark,tinted,default-120,-60,-29}.png"""
import base64, html, io, os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ICON = os.path.dirname(HERE)

# (Ordner, Name, Runde, Titel, Konzept, Farben, Befund)
ICONS = [
 ('current', 'current', 'current', 'AppIcon (produktiv)', 'Vollflaechige Radarkarte, eine Ebene (map-weather.svg), Glas aus.', 'Kartengruen, Strassen, Radarfarben', 'Foto-/Kartenartig; Dark/Tinted nur Systemvorgabe (Ebene "automatic"), kleine Groessen detailreich.'),
 ('v2', 'v2a', 'v2', 'v2a Scheiben', 'Drei konzentrische Scheiben (Radarringe).', 'Blau, Weiss (transluzent)', 'Vom Nutzer abgelehnt: liest sich als Zielscheibe, kaum Kontrast.'),
 ('v2', 'v2b', 'v2', 'v2b Wolke + Tropfen', 'Wolke mit gelbem Tropfen.', 'Blau, Weiss, Gelb', 'Abgelehnt: Kategorie-Klischee, Clipart-Anmutung.'),
 ('v2', 'v2c', 'v2', 'v2c Tropfen + Ring', 'Weisser Tropfen in Ring.', 'Blau, Weiss', 'Abgelehnt: generisch; Tropfen verschwindet in Dark.'),
 ('v3', 'v3a', 'v3', 'v3a Zeitring', 'Weisser Ring als Zeitachse, gelber Sektor als Radar-Sweep.', 'Blau, Weiss, Gelb', 'Funktionsnah; liest sich auch als Timer.'),
 ('v3', 'v3b', 'v3', 'v3b Regenstriche', 'Drei grosse schraege Kapseln als Regen.', 'Blau, Weiss, Gelb, Hellblau', 'Sehr klar bei 29 px; wirkt wie Slashes.'),
 ('v3', 'v3c', 'v3', 'v3c Sonne + Zelle', 'Gelber Kreis ueberlappt grossen weissen Kreis.', 'Blau, Gelb, Weiss', 'Minimal, aber generisch (Apple-Wetter-/Mastercard-Naehe).'),
 ('v3', 'v3d', 'v3', 'v3d Schirm', 'Grosser gelber Schirm, weisser Griff, leicht geneigt.', 'Teal/Blau, Gelb, Weiss', 'Vom Nutzer "schon gut"; staerkste Lesbarkeit. Dark-Fills dort ohne Wirkung (Basis-fill).'),
 ('v4', 'v4a', 'v4', 'v4a Schirm (veredelt)', 'Gewoelbter Schirm, 3 Bahnen, Griff hinter dem Dach, Tropfen hinten.', 'Cyan-Blau, Amber, Weiss, Hellblau', 'Reicher als v3d; Tropfen verschwinden bei 29 px. Vom Nutzer nicht gewaehlt.'),
 ('v4', 'v4b', 'v4', 'v4b Radar + Wolke', 'Radarscope mit gestuftem weissem Sweep, ambernes Regenecho.', 'Blau, Weiss, Amber', 'Beste Funktionsmetapher, bei 29 px am schwaechsten.'),
 ('v4', 'v4c', 'v4', 'v4c Regenwolke', 'Zwei Wolken (hinten blass, vorn glasig), drei Tropfen.', 'Violett-Indigo, Weiss, Hellblau, Amber', 'Kategorie-Klischee, handwerklich solide.'),
 ('v4', 'v4d', 'v4', 'v4d Tropfen-Pin', 'Grosser Tropfen mit Ort-Loch, zwei Wellenscheiben.', 'Tuerkis-Blau, Weiss, Tiefblau', 'Klare Silhouette; nur zwei Farbtoene. Dark/Tinted per Specialization.'),
 ('v5', 'v5a', 'v5', 'v5a Schirm bereit', 'Geneigte ambernfarbene Schirmhaube, heller kraeftiger Griff, flache konkave Unterkante.', 'Petrol, Amber, Weissblau', 'Klare Silhouette, bei 29 px lesbar; Griff-Haube-Trennung in Tinted schwach.'),
 ('v5', 'v5b', 'v5', 'v5b Regenfront', 'Asymmetrische tuerkise Niederschlagskontur, Mint-Zone, heller Kern.', 'Nachtblau, Tuerkis, Mint, Cremeweiss', 'Bei 29 px Blob; Tinted: Staffelung nur noch ueber Grauwerte, flach.'),
 ('v5', 'v5c', 'v5', 'v5c Regenbahnen', 'Drei verjuengte schraege Regenbahnen, weisse Hauptbahn.', 'Violett, Weiss, Mint, Lavendel', 'Sehr klar bei 29 px; Naehe zu v3b (Konzept weiterentwickelt).'),
 ('eigenentwurf', 'original', 'eigen', 'Eigenentwurf (Original)', 'Nutzer-Entwurf aus dem Icon Composer: vier konzentrische Konturen (Front, Band, gelbe Zone, roter Kern) als Regenradar-Niederschlag.', 'Grau, Blau, Gruen, Gelb, Rot', 'Standard stark; Dark: Gelb und Rot beide Weiss (Kern verschmilzt), Tinted: Kernebenen gleich hell.'),
 ('eigenentwurf', 'final', 'eigen', 'Eigenentwurf (final)', 'Wie Original; nur Dark/Tinted ergaenzt: gelbe Zone Dark Amber, Tinted 0.86, Tinted-Hintergrund Dunkelgrau.', 'wie Original; Dark: Amber ergaenzt', 'Staffelung in allen Modi sichtbar; Standardfarben unveraendert.'),
]
ROUNDS = [
 ('current', 'Aktuell', 'Produktives AppIcon.icon (Weather/Resources/Icon). Nur gerendert, nicht veraendert.'),
 ('v2', 'Runde 2', 'Erste Entwuerfe; vom Nutzer abgelehnt ("sprechen mich alle nicht an").'),
 ('v3', 'Runde 3', 'Neu nach Profiregeln (Leitfaden). Nutzer: "schon gut", v3d favorisiert.'),
 ('v4', 'Runde 4', 'Veredelung ohne Nutzervorgaben, Dark/Tinted-Fills per Specialization, 3 Gruppen. Nutzer gefiel v4 nicht.'),
 ('v5', 'Runde 5', 'Freie Gestaltung (Codex), hier erstmals mit ictool gerendert; Paketformat auf Specializations ohne Basis-fill korrigiert.'),
 ('eigen', 'Eigenentwurf', 'Vom Nutzer selbst im Icon Composer gebaut (design/Icon/eigenentwurf.icon); final = Dark/Tinted ergaenzt.'),
]

def pdir(folder): return f'{ICON}/{folder}/previews'
def path(folder, name, kind): return f'{pdir(folder)}/{name}-{kind}.png'

# ------------------------------------------------------------------ PNG
def font(size, bold=False):
    for p in ('/System/Library/Fonts/Helvetica.ttc', '/System/Library/Fonts/Supplemental/Arial.ttf'):
        if os.path.exists(p):
            try: return ImageFont.truetype(p, size, index=1 if bold else 0)
            except Exception: return ImageFont.truetype(p, size)
    return ImageFont.load_default()

def wrap(draw, text, f, width):
    lines, cur = [], ''
    for w in text.split():
        t = (cur + ' ' + w).strip()
        if draw.textlength(t, font=f) <= width: cur = t
        else: lines.append(cur); cur = w
    return lines + [cur]

def load(folder, name, kind, size):
    return Image.open(path(folder, name, kind)).convert('RGBA').resize((size, size), Image.LANCZOS)

def build_png():
    W, M = 4800, 60
    colw = (W - 2 * M) // 4
    big, small = 640, 300
    bg = (236, 236, 240); ink = (30, 36, 48); sub = (90, 98, 112)
    fT, fH, fN, fD, fS = font(84, True), font(54, True), font(40, True), font(30), font(26)
    rowh = 150 + big + 70
    H = M + 200 + len(ROUNDS) * 1000 + 700 + M
    im = Image.new('RGB', (W, H), bg); d = ImageDraw.Draw(im)
    d.text((M, M), 'ShowerNow App-Icon-Entwuerfe: aktuell, v2 bis v5, Eigenentwurf', font=fT, fill=ink)
    d.text((M, M + 96), 'Render: ictool (Icon Composer, Xcode 27.2), iOS. Gross: Default 1024 px. Rechts: Dark und Tinted (Tint 0.58 / 0.8). Unten: Groessenvergleich 120/60/29 px.', font=fD, fill=sub)
    y = M + 160
    for key, title, desc in ROUNDS:
        d.text((M, y), f'{title}', font=fH, fill=ink)
        d.text((M + 360, y + 14), desc, font=fD, fill=sub)
        y += 90
        for i, (folder, name, rnd, t, concept, colors, finding) in enumerate([x for x in ICONS if x[2] == key]):
            x = M + i * colw
            d.text((x, y), t, font=fN, fill=ink)
            for k, ln in enumerate(wrap(d, concept, fD, colw - 50)[:2]):
                d.text((x, y + 52 + k * 36), ln, font=fD, fill=sub)
            iy = y + 130
            c = load(folder, name, 'default', big); im.paste(c, (x, iy), c)
            c = load(folder, name, 'dark', small); im.paste(c, (x + big + 40, iy), c)
            c = load(folder, name, 'tinted', small); im.paste(c, (x + big + 40, iy + small + 40), c)
            d.text((x + big + 40, iy + 2 * small + 48), 'Dark / Tinted', font=fS, fill=sub)
        y += 130 + big + 48 + 60
    # Groessenvergleich
    d.text((M, y), 'Groessenvergleich (tatsaechliche Pixel: 120, 60, 29)', font=fH, fill=ink)
    y += 90
    n = len(ICONS); cw = (W - 2 * M) // n
    for i, (folder, name, *_r) in enumerate(ICONS):
        x = M + i * cw
        d.text((x, y), name, font=fN, fill=ink)
        xx = x
        for s in (120, 60, 29):
            c = Image.open(path(folder, name, f'default-{s}')).convert('RGBA')
            im.paste(c, (xx, y + 60), c); xx += s + 8
    y += 60 + 120 + 40
    # Dunkler Streifen: Dark-Variante in 60/29
    d.rectangle([M - 20, y, W - M + 20, y + 230], fill=(18, 18, 20))
    for i, (folder, name, *_r) in enumerate(ICONS):
        x = M + i * cw
        d.text((x, y + 12), name + ' dark', font=fS, fill=(200, 200, 205))
        c = load(folder, name, 'dark', 120); im.paste(c, (x, y + 56), c)
        c = load(folder, name, 'dark', 60); im.paste(c, (x + 128, y + 56), c)
        c = load(folder, name, 'dark', 29); im.paste(c, (x + 196, y + 56), c)
    im = im.crop((0, 0, W, y + 230 + M))
    out = f'{HERE}/all-icons.png'
    im.save(out, optimize=True)
    print('PNG', out, im.size, os.path.getsize(out))

# ------------------------------------------------------------------ HTML
def b64(img, fmt='PNG'):
    buf = io.BytesIO(); img.save(buf, fmt, optimize=True)
    return 'data:image/png;base64,' + base64.b64encode(buf.getvalue()).decode()

def build_html(limit=1024):
    imgs = {}
    for folder, name, *_ in ICONS:
        for kind in ('default', 'dark', 'tinted'):
            im = Image.open(path(folder, name, kind)).convert('RGBA')
            if limit != 1024: im = im.resize((limit, limit), Image.LANCZOS)
            imgs[(name, kind)] = b64(im)
            for s, cs in ((120, 120), (58, 58)):   # 2x fuer 60 pt und 29 pt
                imgs[(name, kind, s)] = b64(Image.open(path(folder, name, kind)).convert('RGBA').resize((s, s), Image.LANCZOS))
    css = """
:root{--bg:#f2f2f6;--fg:#1c1f26;--mut:#5c6370;--card:#fff;--line:#d9dbe2}
*{box-sizing:border-box}body{margin:0;font:16px/1.45 -apple-system,BlinkMacSystemFont,"Helvetica Neue",Arial,sans-serif;background:var(--bg);color:var(--fg)}
header{position:sticky;top:0;z-index:5;background:rgba(242,242,246,.92);backdrop-filter:blur(8px);border-bottom:1px solid var(--line);padding:12px 24px;display:flex;gap:16px;align-items:center;flex-wrap:wrap}
h1{font-size:20px;margin:0 16px 0 0}.seg{display:inline-flex;border:1px solid var(--line);border-radius:8px;overflow:hidden}
.seg button{border:0;background:#fff;padding:7px 16px;font:inherit;cursor:pointer;color:var(--fg)}.seg button.on{background:#1c1f26;color:#fff}
main{max-width:1500px;margin:0 auto;padding:8px 24px 64px}section{margin:36px 0}h2{font-size:24px;margin:0 0 4px}.desc{color:var(--mut);margin:0 0 16px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:18px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px}
.card img.ic{width:100%;height:auto;display:block;cursor:zoom-in;border-radius:22%;transition:transform .15s}.card img.ic:hover{transform:scale(1.03)}
.card h3{margin:10px 0 2px;font-size:17px}.card p{margin:2px 0;color:var(--mut);font-size:14px}.card dl{margin:8px 0 0;font-size:13px;display:grid;grid-template-columns:auto 1fr;gap:2px 8px}.card dt{color:var(--mut)}.card dd{margin:0}
.home{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:8px}
.screen{border-radius:22px;padding:18px;min-height:210px}.screen.light{background:linear-gradient(160deg,#cfe0f5,#f4e6d8)}.screen.dark{background:linear-gradient(160deg,#10131c,#241c2e)}.screen.tint{background:linear-gradient(160deg,#1b2324,#262a2d)}
.screen h4{margin:0 0 12px;font-size:13px;font-weight:600;opacity:.75}.screen.dark h4,.screen.tint h4{color:#ddd}
.row{display:flex;gap:16px;flex-wrap:wrap;align-items:flex-end;margin-bottom:10px}.cell{text-align:center;font-size:11px}.cell img{display:block;margin:0 auto 4px}.cell .l{opacity:.7}.dark .cell,.tint .cell{color:#ddd}
.s60{width:60px;height:60px;border-radius:13.5px}.s29{width:29px;height:29px;border-radius:6.5px}
#lb{position:fixed;inset:0;background:rgba(10,12,18,.86);display:none;align-items:center;justify-content:center;z-index:20;cursor:zoom-out;flex-direction:column;color:#fff}
#lb.show{display:flex}#lb img{width:min(1024px,92vmin);height:min(1024px,92vmin);border-radius:22%}#lb span{margin-top:12px;font-size:14px}
@media(max-width:800px){.home{grid-template-columns:1fr}}
"""
    out = ['<!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>ShowerNow App-Icon-Entwuerfe</title><style>', css, '</style></head><body>']
    out.append('<header><h1>ShowerNow App-Icon-Entwuerfe</h1><span class="seg" id="seg"><button data-m="default" class="on">Default</button><button data-m="dark">Dark</button><button data-m="tinted">Tinted</button></span><span style="color:var(--mut);font-size:13px">Klick auf ein Icon: Ansicht 1024 px. Render: ictool, Xcode 27.2. Keine Geraetepruefung.</span></header><main>')
    for key, title, desc in ROUNDS:
        out.append(f'<section><h2>{html.escape(title)}</h2><p class="desc">{html.escape(desc)}</p><div class="grid">')
        items = [x for x in ICONS if x[2] == key]
        for folder, name, rnd, t, concept, colors, finding in items:
            e = html.escape
            out.append(f'<div class="card"><img class="ic" data-n="{name}" data-t="{e(t)}" src="{imgs[(name,"default")]}" alt="{e(t)}"><h3>{e(t)}</h3><p>{e(concept)}</p>'
                       f'<dl><dt>Name</dt><dd>{name}</dd><dt>Runde</dt><dd>{e(rnd)}</dd><dt>Farben</dt><dd>{e(colors)}</dd><dt>Befund</dt><dd>{e(finding)}</dd></dl></div>')
        out.append('</div></section>')
    # Homescreen
    out.append('<section><h2>Homescreen-Simulation</h2><p class="desc">Alle Icons in 60 pt und 29 pt (2x-Pixel). Hell: Default, dunkel: Dark, getoent: Tinted. Hintergruende sind Platzhalter, keine echten Wallpaper.</p><div class="home">')
    for cls, label, kind in (('light', 'Hell (Default)', 'default'), ('dark', 'Dunkel (Dark)', 'dark'), ('tint', 'Getoent (Tinted)', 'tinted')):
        out.append(f'<div class="screen {cls}"><h4>{label}</h4><div class="row">')
        for folder, name, *_ in ICONS:
            out.append(f'<div class="cell"><img class="s60" src="{imgs[(name,kind,120)]}" alt="{name}"><span class="l">{name}</span></div>')
        out.append('</div><div class="row">')
        for folder, name, *_ in ICONS:
            out.append(f'<div class="cell"><img class="s29" src="{imgs[(name,kind,58)]}" alt="{name}"></div>')
        out.append('</div></div>')
    out.append('</div></section>')
    out.append('</main><div id="lb"><img id="lbi" alt=""><span id="lbt"></span></div>')
    data = '{' + ','.join(f'"{n}":{{"dark":"{imgs[(n,"dark")]}","tinted":"{imgs[(n,"tinted")]}"}}' for _, n, *_ in ICONS) + '}'
    # Daten nur einmal: die Karten-Bilder sind Default; Umschalter tauscht src aus DATA
    js = """
var DATA=%s,mode='default';document.querySelectorAll('img.ic').forEach(function(i){DATA[i.dataset.n].default=i.src});
function setMode(m){mode=m;document.querySelectorAll('#seg button').forEach(function(b){b.classList.toggle('on',b.dataset.m===m)});
document.querySelectorAll('img.ic').forEach(function(i){i.src=DATA[i.dataset.n][m]})}
document.getElementById('seg').addEventListener('click',function(e){if(e.target.dataset.m)setMode(e.target.dataset.m)});
var lb=document.getElementById('lb');
document.querySelectorAll('img.ic').forEach(function(i){i.addEventListener('click',function(){document.getElementById('lbi').src=DATA[i.dataset.n][mode];document.getElementById('lbt').textContent=i.dataset.t+' ('+mode+', 1024 px)';lb.classList.add('show')})});
lb.addEventListener('click',function(){lb.classList.remove('show')});
document.addEventListener('keydown',function(e){if(e.key==='Escape')lb.classList.remove('show')});
""" % data
    out.append('<script>' + js + '</script></body></html>')
    text = '\n'.join(out)
    open(f'{HERE}/index.html', 'w').write(text)
    print('HTML', len(text), 'Bytes')
    return len(text)

if __name__ == '__main__':
    build_png()
    size = build_html(1024)
    if size > 12_000_000:
        print('zu gross, 512 px'); build_html(512)

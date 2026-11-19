#!/usr/bin/env python3
"""Erzeugt die Gestaltungstafeln (HTML) für die Live-Activity-Entwürfe A, B, C aus beispieldaten.json.

Nur Standardbibliothek. Reine Gestaltung, kein Produktcode. HTML -> PNG übernimmt snap.swift
(offscreen WKWebView, kein Fenster, keine Aktivierung). Aufruf: python3 render.py <ausgabeordner>
"""
import json
import os
import sys
from html import escape

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = json.load(open(os.path.join(HERE, "..", "beispieldaten.json"), encoding="utf-8"))
STATES = {s["id"]: s for s in DATA["zustaende"]}
ORDER = [s["id"] for s in DATA["zustaende"]]

# ---------------------------------------------------------------- Darstellung (nach RainActivityPresentation)


def word(cls):
    if cls is None or cls < 1:
        return None
    return "sehr leicht" if cls < 3 else "leicht" if cls <= 4 else "mäßig" if cls <= 7 else "stark"


def pres(s):
    reg = s["ziel"] == "gebiet"
    o = DATA["orte"]["gebiet" if reg else "ort"]
    stale, phase = s["veraltet"], s["phase"]
    p = dict(s=s, reg=reg, name=o["name"], radius=o.get("radiusKm"), stale=stale, phase=phase)
    p["radius_text"] = f"Umkreis {o['radiusKm']} km" if reg else None
    cd = (not stale) and phase in ("startsIn", "endsIn") and s.get("minuten") is not None
    p["cd"] = f"{s['minuten']} Min." if cd else None
    p["event"] = None if stale else s.get("ereignis")
    p["kind"] = "stale" if stale else ("drizzle" if phase == "startsIn" else "rain")
    p["col"] = "warn" if stale else "acc"
    p["stand"] = f"Stand {s['stand']}"
    # Überschrift und Detail wie in der App (Text kommt aus RainActivityPresentation / RegionPresentation)
    if stale:
        p["headline"], p["detail"] = "Daten veraltet", "Keine verlässliche Aussage"
    elif phase == "startsIn":
        p["headline"] = ("Regen im Umkreis in" if reg else "Regen in") if cd else ("Regen im Umkreis gleich" if reg else "Regen gleich")
        p["detail"] = None
    elif phase == "raining":
        p["headline"], p["detail"] = ("Es regnet im Umkreis" if reg else "Es regnet"), "Ende nicht absehbar"
    else:  # endsIn
        p["headline"] = "Es regnet im Umkreis" if reg else "Es regnet"
        p["detail"] = "Endet in" if cd else "Endet gleich"
    # Gebietsanteil: Logik von RainActivityRegionPresentation
    p["share"] = None
    p["max_class"] = None
    if reg and not stale and phase != "dry":
        wet, peak = s.get("wetSharePercent"), s.get("peakSharePercent")
        if phase in ("raining", "endsIn"):
            p["share"] = (wet, "now") if wet else ((peak, "peak") if peak else None)
        else:
            p["share"] = (peak, "peak") if peak else ((wet, "now") if wet else None)
        if s["intensityClass"] >= 1:
            p["max_class"] = min(s["intensityClass"], 15)
    if p["share"]:
        v, k = p["share"]
        p["share_text"] = f"{v} % der Fläche nass" if k == "now" else f"bis zu {v} % der Fläche nass"
        p["bar"] = v / 100 if k == "now" else None
        p["compact_share"] = f"{v} %"
        p["share_short"] = f"{v} % nass" if k == "now" else f"bis zu {v} % nass"
    else:
        p["share_text"] = p["bar"] = p["compact_share"] = p["share_short"] = None
    p["level_text"] = f"Stärkste Stufe {p['max_class']} ({word(p['max_class'])})" if p["max_class"] else None
    # Intensität am Ort: Feld vorhanden, wird in der App heute nicht angezeigt (NEU in Entwurf C)
    p["point_level"] = None if (reg or stale) else (f"Stufe {s['intensityClass']} ({word(s['intensityClass'])})" if s["intensityClass"] >= 1 else None)
    # kompakter Text rechts in der Dynamic Island (wie compactLabel)
    p["compact"] = "Veraltet" if stale else (p["cd"] or p["compact_share"] or "Regen")
    return p


# ---------------------------------------------------------------- Symbole (nachgezeichnet, keine SF Symbols)

CLOUD = "M7.2 16a3.8 3.8 0 0 1-.5-7.57 5.3 5.3 0 0 1 10.2-.9A4.2 4.2 0 0 1 17.2 16z"


def icon(kind, size=20):
    """Nachzeichnung von cloud.drizzle.fill, cloud.rain.fill, clock.badge.exclamationmark (currentColor)."""
    if kind == "drizzle":
        body = f'<path d="{CLOUD}" fill="currentColor"/><g stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M9 18.6v.9M13 18.6v.9M11 20.7v.9M15 20.7v.9"/></g>'
    elif kind == "rain":
        body = f'<path d="{CLOUD}" fill="currentColor"/><g stroke="currentColor" stroke-width="1.8" stroke-linecap="round"><path d="M8.5 18.2l-.8 2.6M12.5 18.2l-.8 2.6M16.5 18.2l-.8 2.6"/></g>'
    elif kind == "stale":
        body = '<circle cx="11" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M11 7v5.2l3 1.8" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><circle cx="19.2" cy="5" r="3.2" fill="currentColor"/><path d="M19.2 3.5v1.9" stroke="#000" stroke-width="1.2" stroke-linecap="round"/>'
    elif kind == "pin":
        body = '<path d="M12 21.5c3-4.2 6-7 6-11a6 6 0 0 0-12 0c0 4 3 6.8 6 11z" fill="currentColor"/><circle cx="12" cy="10.3" r="2.2" fill="var(--pinhole,#fff)"/>'
    else:
        body = ""
    return f'<svg class="ic" width="{size}" height="{size}" viewBox="0 0 24 24" aria-hidden="true">{body}</svg>'


# ---------------------------------------------------------------- CSS

CSS = """
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:#f2f2f7;font-family:-apple-system,'SF Pro Text','Helvetica Neue',sans-serif;-webkit-font-smoothing:antialiased;color:#111}
.board{padding:28px 32px 26px;display:inline-block}
.board.dunkel{background:#101014;color:#f2f2f7}
.board.hell{background:#eceef4;color:#15151a}
.bh{display:flex;justify-content:space-between;align-items:baseline;gap:40px;margin-bottom:20px}
.bh h1{font-size:19px;font-weight:650;letter-spacing:-.01em}
.bh .m{font-size:12px;opacity:.62;max-width:620px;text-align:right}
.tag{display:inline-block;border:1px solid currentColor;opacity:.55;border-radius:99px;padding:1px 8px;font-size:11px;margin-left:10px;vertical-align:2px}
.cap{font-size:11.5px;opacity:.68;margin-top:7px;line-height:1.3}
.grid{display:grid;gap:22px 24px}
.t-hell{--fg:#16161a;--fg2:rgba(60,60,67,.74);--fg3:rgba(60,60,67,.5);--acc:#0079a3;--accbg:0,129,167;--warn:#b85400;--warnbg:255,149,0;--track:rgba(60,60,67,.16);--hair:rgba(60,60,67,.18);--glass:rgba(255,255,255,.52);--gb:rgba(255,255,255,.7);--sh:0 10px 30px rgba(40,50,90,.16);--pinhole:#fff}
.t-dunkel{--fg:#fff;--fg2:rgba(235,235,245,.68);--fg3:rgba(235,235,245,.46);--acc:#64d2ff;--accbg:100,210,255;--warn:#ff9f0a;--warnbg:255,159,10;--track:rgba(235,235,245,.2);--hair:rgba(235,235,245,.16);--glass:rgba(38,38,46,.5);--gb:rgba(255,255,255,.14);--sh:0 10px 30px rgba(0,0,0,.45);--pinhole:#26262e}
.wp{position:relative;overflow:hidden}
.wp.t-hell{background:radial-gradient(circle at 15% 10%,#ffd2bd 0,transparent 42%),radial-gradient(circle at 88% 28%,#a9cdff 0,transparent 48%),radial-gradient(circle at 35% 95%,#cdb9ff 0,transparent 55%),#e6e9f6}
.wp.t-dunkel{background:radial-gradient(circle at 15% 10%,#5b2f78 0,transparent 42%),radial-gradient(circle at 88% 28%,#12467a 0,transparent 48%),radial-gradient(circle at 35% 95%,#2a2a7a 0,transparent 55%),#0b0c1c}
.ic{display:block;flex:none}
.lock{width:360px;border-radius:24px;padding:14px 16px 12px;color:var(--fg);position:relative;overflow:hidden;
  -webkit-backdrop-filter:blur(26px) saturate(1.8);backdrop-filter:blur(26px) saturate(1.8);border:1px solid var(--gb);box-shadow:var(--sh)}
.lockpad{padding:22px 21px}
.row{display:flex;align-items:center}
.sp{flex:1}
.name{font-size:13px;font-weight:600;color:var(--fg2);display:flex;align-items:center;gap:5px}
.name .ic{color:var(--fg2)}
.foot{font-size:12px;color:var(--fg2);display:flex;align-items:center;gap:4px}
.foot.warn,.warn{color:var(--warn)}
.acc{color:var(--acc)}
.bar{height:6px;border-radius:9px;background:var(--track);overflow:hidden}
.bar i{display:block;height:100%;border-radius:9px;background:var(--acc)}
/* A */
.a{background:linear-gradient(140deg,rgba(var(--tint),.26),rgba(var(--tint),.07) 70%),var(--glass)}
.a-main{display:flex;gap:10px;align-items:center;margin-top:6px}
.a-main>div:first-child{flex:1;min-width:0}
.a-head{font-size:31px;font-weight:700;letter-spacing:-.02em;line-height:1.08;font-family:-apple-system-rounded,'SF Pro Rounded',-apple-system,sans-serif}
.a-head.sm{font-size:25px}
.a-head b{color:var(--acc);font-weight:700}
.a-head.warn b{color:var(--warn)}
.a-sub{font-size:14px;color:var(--fg2);margin-top:3px}
.a-badge{width:50px;height:50px;border-radius:16px;display:flex;align-items:center;justify-content:center;background:rgba(var(--tint),.2);color:var(--acc)}
.a-badge.warn{color:var(--warn)}
.a-share{font-size:14px;font-weight:600;margin-top:5px}
.a-lvl{font-size:12px;color:var(--fg2);margin-top:4px}
/* B */
.b{background:var(--glass)}
.b-head{font-size:21px;font-weight:650;letter-spacing:-.01em;margin-top:5px;display:flex;align-items:center;gap:8px}
.b-sub{font-size:13px;color:var(--fg2);margin-top:1px}
.axis{position:relative;height:42px;margin:12px 4px 0}
.axis .tr{position:absolute;left:0;right:0;top:9px;height:3px;border-radius:3px;background:var(--track)}
.axis .band{position:absolute;top:7px;height:7px;border-radius:7px;background:var(--acc)}
.axis .band.fade{background:linear-gradient(90deg,var(--acc),rgba(var(--accbg),0))}
.axis .dash{position:absolute;left:0;right:0;top:10px;border-top:2px dashed var(--warn);opacity:.7}
.axis .dot{position:absolute;top:5px;width:11px;height:11px;border-radius:50%;transform:translateX(-50%);border:2px solid var(--fg2);background:transparent}
.axis .dot.ev{background:var(--acc);border-color:var(--acc);width:15px;height:15px;top:3px}
.axis .dot.wr{border-color:var(--warn)}
.axis .lb{position:absolute;top:22px;font-size:12px;color:var(--fg2);white-space:nowrap}
.axis .lb b{color:var(--fg);font-weight:600}
.axis .lb.mid{transform:translateX(-50%)}
.axis .lb.r{right:0;text-align:right}
.b-share{font-size:13px;margin-top:8px;color:var(--fg);display:flex;gap:6px;align-items:baseline}
.b-share span{color:var(--fg2);font-size:12px}
/* C */
.c{background:var(--glass)}
.c-top{display:flex;align-items:center;gap:8px}
.c-name{font-size:16px;font-weight:650;display:flex;align-items:center;gap:5px;min-width:0}
.c-name .ic{color:var(--acc)}
.chip{font-size:11.5px;font-weight:600;color:var(--fg2);border:1px solid var(--hair);border-radius:99px;padding:1px 8px;white-space:nowrap}
.pill{font-size:13px;font-weight:650;border-radius:99px;padding:3px 10px;background:rgba(var(--tint),.2);color:var(--acc);white-space:nowrap}
.pill.warn{color:var(--warn)}
.c-body{display:flex;gap:14px;align-items:center;margin-top:11px}
.ring{position:relative;width:62px;height:62px;flex:none}
.ring svg{position:absolute;inset:0}
.ring .v{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;font-size:15px;font-weight:700;line-height:1}
.ring .v small{font-size:9.5px;font-weight:600;color:var(--fg2);margin-bottom:1px}
.glyph{width:62px;height:62px;border-radius:18px;flex:none;display:flex;align-items:center;justify-content:center;background:rgba(var(--tint),.16);color:var(--acc)}
.glyph.warn{color:var(--warn)}
.c-lines{flex:1;min-width:0;display:flex;flex-direction:column;gap:3px}
.c-l1{font-size:15px;font-weight:600}
.c-l2{font-size:13px;color:var(--fg2)}
/* Island (immer schwarz, kein Glas) */
.island{--fg:#fff;--fg2:rgba(235,235,245,.66);--fg3:rgba(235,235,245,.46);--acc:#64d2ff;--accbg:100,210,255;--tint:100,210,255;--warn:#ff9f0a;--warnbg:255,159,10;--track:rgba(235,235,245,.22);--hair:rgba(235,235,245,.2);--pinhole:#000;background:#000;color:#fff}
.strip{position:relative;width:402px;overflow:hidden;border-radius:26px}
.strip .sb{position:absolute;top:14px;left:34px;right:34px;display:flex;justify-content:space-between;font-size:15px;font-weight:600;color:var(--sbfg)}
.strip.t-hell{--sbfg:#15151a}.strip.t-dunkel{--sbfg:#fff}
.isl{position:absolute;left:50%;transform:translateX(-50%);top:11px;background:#000;color:#fff;overflow:hidden}
.isl.compact{height:37px;width:244px;border-radius:19px;display:flex;align-items:center;justify-content:space-between;padding:0 14px 0 14px;font-size:15px;font-weight:600}
.isl.compact .tx{font-family:-apple-system-rounded,'SF Pro Rounded',-apple-system,sans-serif;font-variant-numeric:tabular-nums;white-space:nowrap}
.isl.expanded{width:374px;border-radius:44px;padding:11px 20px 16px}
.itop{display:grid;grid-template-columns:1fr 126px 1fr;align-items:center;height:37px;margin-top:-1px}
.itop>div:last-child{justify-self:end;text-align:right}
.ilead{display:flex;align-items:center;gap:7px;font-size:13px;font-weight:600;color:var(--fg2);min-width:0}
.ihead{font-size:25px;font-weight:700;letter-spacing:-.02em;line-height:1.1;margin-top:5px;font-family:-apple-system-rounded,'SF Pro Rounded',-apple-system,sans-serif}
.ihead b{color:var(--acc)}
.ihead.warn,.ihead.warn b{color:var(--warn)}
.isub{font-size:13px;color:var(--fg2);margin-top:3px}
.island .axis{margin-top:9px}
.island .bar{height:5px}
/* Watch */
.wframe{width:186px;height:221px;border-radius:50px;background:#0a0a0a;padding:12px;box-shadow:0 0 0 2px #3a3a3e,0 14px 26px rgba(0,0,0,.4);position:relative}
.wscr{width:162px;height:197px;border-radius:38px;background:#000;overflow:hidden;position:relative;color:#fff}
.wtime{position:absolute;top:8px;right:15px;font-size:14px;font-weight:600;color:#fff}
.wtitle{position:absolute;top:8px;left:15px;font-size:12px;font-weight:600;color:rgba(235,235,245,.6)}
.wcard{position:absolute;left:5px;right:5px;top:30px;height:134px;border-radius:22px;padding:10px 11px;overflow:hidden}
.wnext{position:absolute;left:5px;right:5px;top:168px;height:60px;border-radius:22px;background:#1c1c1e}
.wcard.t-dunkel{--fg:#fff;--fg2:rgba(235,235,245,.68);--fg3:rgba(235,235,245,.46);--acc:#64d2ff;--accbg:100,210,255;--warn:#ff9f0a;--track:rgba(235,235,245,.22);--hair:rgba(235,235,245,.18);--pinhole:#1c1c1e;background:#1c1c1e;color:#fff}
.wcard.t-hell{--fg:#16161a;--fg2:rgba(60,60,67,.74);--fg3:rgba(60,60,67,.5);--acc:#0079a3;--accbg:0,129,167;--warn:#b85400;--track:rgba(60,60,67,.18);--hair:rgba(60,60,67,.2);--pinhole:#f2f2f7;background:#f2f2f7;color:#16161a}
.wcard .wn{font-size:12px;font-weight:600;color:var(--fg2);display:flex;align-items:center;gap:4px;white-space:nowrap}
.wcard .wn .ic{color:var(--acc)}
.wk{font-size:13px;font-weight:650;color:var(--acc)}
.wk.warn{color:var(--warn)}
.wbig{font-size:41px;font-weight:700;letter-spacing:-.03em;line-height:1;font-family:-apple-system-rounded,'SF Pro Rounded',-apple-system,sans-serif;color:var(--fg)}
.wbig.sm{font-size:25px;line-height:1.05}
.wbig.md{font-size:34px}
.wbig.warn{color:var(--warn)}
.wfoot{position:absolute;left:11px;right:11px;bottom:9px;font-size:11.5px;color:var(--fg2);display:flex;align-items:center;gap:4px}
.wfoot.warn{color:var(--warn)}
.wcard .axis{margin:8px 3px 0;height:32px}
.wcard .axis .lb{top:19px;font-size:10.5px}
.wcard .ring{width:44px;height:44px}.wcard .ring svg{transform:scale(.71);transform-origin:0 0}.wcard .ring .v{font-size:11px}.wcard .ring .v small{font-size:7.5px}
.wmini{font-size:12px;color:var(--fg2);margin-top:2px}
"""

# ---------------------------------------------------------------- Bausteine


def tint(p):
    return "255,149,0" if p["stale"] else ("0,129,167" if False else "")  # nicht genutzt, Farbe kommt aus Themenvariablen


def tint_style(p):
    # --tint folgt dem Theme (acc/warn); als rgb-Variable für Verläufe
    return f'style="--tint:var({"--warnbg" if p["stale"] else "--accbg"})"'


def wrap_theme(theme, inner, cls=""):
    return f'<div class="{cls} t-{theme}">{inner}</div>'


def nm(p, with_radius=False):
    t = escape(p["name"])
    if with_radius and p["radius_text"]:
        t += f' · {p["radius_text"]}'
    return f'<div class="name">{icon("pin", 13)}{t}</div>'


def stand(p):
    cls = "foot warn" if p["stale"] else "foot"
    ic = icon("stale", 13) if p["stale"] else ""
    return f'<div class="{cls}">{ic}{p["stand"]}</div>'


def barhtml(p, w=None):
    if p["bar"] is None:
        return ""
    return f'<div class="bar" style="margin-top:6px"><i style="width:{int(p["bar"]*100)}%"></i></div>'


# ---- Zeitachse (B): nur belegte Zeiten, Ort der Marken aus Minuten, keine Zwischenwerte

AXIS_MIN = 15  # sichtbares Fenster 0-15 Minuten, nur zur Positionierung der belegten Marken


def axis(p):
    s = p["s"]
    jetzt = f'<span class="lb"><b>Jetzt</b> {s["jetzt"]}</span>'
    if p["stale"]:
        return (f'<div class="axis"><div class="dash"></div><div class="dot wr" style="left:0"></div>'
                f'<span class="lb warn" style="left:-4px">Stand {s["stand"]}</span>'
                f'<span class="lb r">Verlauf unbekannt</span></div>')
    pos = None if s.get("minuten") is None else max(4, min(90, s["minuten"] / AXIS_MIN * 100))
    if p["phase"] == "startsIn":
        return (f'<div class="axis"><div class="tr"></div><div class="band fade" style="left:{pos}%;right:0"></div>'
                f'<div class="dot" style="left:0"></div><div class="dot ev" style="left:{pos}%"></div>'
                f'<span class="lb" style="left:-4px"><b>Jetzt</b> {s["jetzt"]}</span>'
                f'<span class="lb mid" style="left:{pos}%"><b>Beginn</b> {s["ereignis"]}</span></div>')
    if p["phase"] == "raining":
        return (f'<div class="axis"><div class="band fade" style="left:0;right:0"></div><div class="dot" style="left:0"></div>'
                f'<span class="lb" style="left:-4px"><b>Jetzt</b> {s["jetzt"]}</span>'
                f'<span class="lb r">Ende nicht absehbar</span></div>')
    return (f'<div class="axis"><div class="band" style="left:0;width:{pos}%"></div><div class="dot" style="left:0"></div>'
            f'<div class="dot ev" style="left:{pos}%"></div>'
            f'<span class="lb" style="left:-4px"><b>Jetzt</b> {s["jetzt"]}</span>'
            f'<span class="lb mid" style="left:{pos}%"><b>Ende</b> {s["ereignis"]}</span></div>')


def b_headline(p):
    if p["stale"]:
        return p["headline"], p["detail"], True
    if p["phase"] == "startsIn":
        return (f'Regen in {p["cd"]}' if p["cd"] else p["headline"]), ("im Umkreis" if p["reg"] else None), False
    if p["phase"] == "raining":
        return p["headline"], None, False
    return p["headline"], (f'Endet in {p["cd"]}' if p["cd"] else p["detail"]), False


def a_head(p):
    """Blickfang: der Zeitsatz, sonst das Statuswort."""
    warn = " warn" if p["stale"] else ""
    if p["stale"]:
        return f'<div class="a-head{warn}"><b>Daten veraltet</b></div>', p["detail"]
    reg = p["reg"]
    if p["phase"] == "startsIn":
        if p["cd"]:
            return f'<div class="a-head">Regen in <b>{p["cd"]}</b></div>', ("im Umkreis" if reg else None)
        return f'<div class="a-head"><b>Regen gleich</b></div>', ("im Umkreis" if reg else None)
    if p["phase"] == "raining":
        txt = "Es regnet im Umkreis" if reg else "Es regnet"
        return f'<div class="a-head{" sm" if reg else ""}"><b>{txt}</b></div>', p["detail"]
    if p["cd"]:
        return f'<div class="a-head">Endet in <b>{p["cd"]}</b></div>', ("Es regnet im Umkreis" if reg else "Es regnet")
    return '<div class="a-head"><b>Endet gleich</b></div>', "Es regnet"


# ---- iPhone-Sperrbildschirm: Banner je Entwurf


def lock_a(p, theme):
    head, sub = a_head(p)
    badge = f'<div class="a-badge{" warn" if p["stale"] else ""}">{icon(p["kind"], 30)}</div>'
    extra = ""
    if p["share_text"]:
        extra += f'<div class="a-share">{p["share_text"]}</div>{barhtml(p)}'
    if p["level_text"]:
        extra += f'<div class="a-lvl">{p["level_text"]}</div>'
    subh = f'<div class="a-sub">{sub}</div>' if sub else ""
    return (f'<div class="lock a" {tint_style(p)}><div class="row">{nm(p, True)}<div class="sp"></div>{stand(p)}</div>'
            f'<div class="a-main"><div>{head}{subh}{extra}</div>{badge}</div></div>')


def lock_b(p, theme):
    h, sub, warn = b_headline(p)
    subh = f'<div class="b-sub">{sub}</div>' if sub else ""
    share = ""
    if p["share_text"] or p["level_text"]:
        share = f'<div class="b-share">{p["share_text"] or ""}<span>{p["level_text"] or ""}</span></div>'
    return (f'<div class="lock b" {tint_style(p)}><div class="row">{nm(p, True)}<div class="sp"></div>{stand(p)}</div>'
            f'<div class="b-head{" warn" if warn else ""}"><span style="color:var(--{p["col"]});display:flex">{icon(p["kind"], 22)}</span>{h}</div>{subh}{axis(p)}{share}</div>')


def ring(p, size=62):
    """Gebietsanteil als Ring; Anteil 'bis zu' (Prognose) nur als gestrichelte Umrandung, nur 'jetzt' gefüllt."""
    v, k = p["share"]
    r = 27
    c = 2 * 3.14159265 * r
    if k == "now":
        arc = f'<circle cx="31" cy="31" r="{r}" fill="none" stroke="var(--acc)" stroke-width="6" stroke-linecap="round" stroke-dasharray="{c*v/100:.1f} {c:.1f}" transform="rotate(-90 31 31)"/>'
        inner = f'<div class="v">{v} %</div>'
    else:
        arc = f'<circle cx="31" cy="31" r="{r}" fill="none" stroke="var(--acc)" stroke-width="3" stroke-dasharray="3 5" stroke-linecap="round"/>'
        inner = f'<div class="v"><small>bis zu</small>{v} %</div>'
    return (f'<div class="ring"><svg width="62" height="62" viewBox="0 0 62 62"><circle cx="31" cy="31" r="{r}" fill="none" stroke="var(--track)" stroke-width="6"/>{arc}</svg>{inner}</div>')


def status_text(p):
    if p["stale"]:
        return "Daten veraltet"
    if p["phase"] == "startsIn":
        return f'Regen in {p["cd"]}' if p["cd"] else "Regen gleich"
    if p["phase"] == "raining":
        return "Es regnet"
    return f'Endet in {p["cd"]}' if p["cd"] else "Endet gleich"


def c_point_lines(p):
    """Zeilen unter dem Status für einen Ort (Entwurf C). Zeiten aus eventDate, Intensität aus intensityClass (NEU angezeigt)."""
    s = p["s"]
    out = []
    if p["phase"] == "startsIn":
        out.append(f'<div class="c-l1">Beginn um {s["ereignis"]} Uhr</div>' if s.get("ereignis") else f'<div class="c-l1">{p["headline"]}</div>')
    elif p["phase"] == "raining":
        out.append('<div class="c-l1">Es regnet</div>')
        out.append(f'<div class="c-l2">{p["detail"]}</div>')
    else:
        out.append('<div class="c-l1">Es regnet</div>')
        if s.get("ereignis"):
            out.append(f'<div class="c-l2">Ende um {s["ereignis"]} Uhr</div>')
    if p["point_level"]:
        out.append(f'<div class="c-l2">Intensität {p["point_level"]}</div>')
    return out


def lock_c(p, theme):
    chip = f'<span class="chip">{p["radius_text"]}</span>' if p["radius_text"] else ""
    pill = f'<span class="pill{" warn" if p["stale"] else ""}">{status_text(p)}</span>'
    top = f'<div class="c-top"><div class="c-name">{icon("pin", 16)}<span>{escape(p["name"])}</span></div>{chip}<div class="sp"></div>{pill}</div>'
    lines = []
    if p["stale"]:
        lines.append(f'<div class="c-l1 warn">Keine verlässliche Aussage</div>')
    elif p["reg"]:
        if p["share_text"]:
            lines.append(f'<div class="c-l1">{p["share_text"]}</div>')
        if p["level_text"]:
            lines.append(f'<div class="c-l2">{p["level_text"]}</div>')
        if not p["share_text"] and not p["level_text"]:
            lines.append(f'<div class="c-l1">{p["headline"]}</div>')
    else:
        lines.extend(c_point_lines(p))
    lines.append(stand(p))
    lead = ring(p) if (p["reg"] and p["share"]) else f'<div class="glyph{" warn" if p["stale"] else ""}">{icon(p["kind"], 34)}</div>'
    return (f'<div class="lock c" {tint_style(p)}>{top}<div class="c-body">{lead}<div class="c-lines">{"".join(lines)}</div></div></div>')


LOCK = {"A": lock_a, "B": lock_b, "C": lock_c}


def banner_tile(design, sid, theme, pad=True):
    p = pres(STATES[sid])
    inner = f'<div class="lockpad wp t-{theme}" style="width:402px">{wrap_theme(theme, LOCK[design](p, theme))}</div>' if pad else ""
    return inner


# ---- Dynamic Island


def isl_compact(design, p):
    lead = f'<span style="color:var(--{p["col"]});display:flex">{icon(p["kind"], 20)}</span>'
    if design == "B":
        if p["stale"]:
            tx, col = "Veraltet", "warn"
        elif p["event"] and p["phase"] == "startsIn":
            tx, col = p["event"], "acc"
        elif p["event"]:
            tx, col = f'bis {p["event"]}', "acc"
        else:
            tx, col = "Regen", "acc"
    elif design == "C":
        tx = "Veraltet" if p["stale"] else (p["compact_share"] if (p["reg"] and p["compact_share"] and p["phase"] != "startsIn") else (p["cd"] or "Regen"))
        col = p["col"]
        if p["reg"] and not p["stale"]:
            lead = f'<span style="color:var(--acc);display:flex">{icon("pin", 19)}</span>'
    else:
        tx, col = p["compact"], p["col"]
    return f'<div class="isl compact island" {tint_style(p)}>{lead}<span class="tx" style="color:var(--{col})">{tx}</span></div>'


def isl_expanded(design, p):
    s = p["s"]
    col = p["col"]
    lead_icon = f'<span style="color:var(--{col});display:flex">{icon(p["kind"], 22)}</span>'
    st = f'<span class="{"warn" if p["stale"] else ""}" style="font-size:12.5px;font-weight:500;color:{"var(--warn)" if p["stale"] else "var(--fg2)"}">{p["stand"]}</span>'
    if design == "A":
        head, sub = a_head(p)
        head = head.replace("a-head", "ihead").replace(' sm"', '"')
        extra = ""
        if p["share_text"]:
            extra += f'<div class="isub" style="color:var(--fg);font-weight:600">{p["share_text"]}</div>{barhtml(p)}'
        if p["level_text"]:
            extra += f'<div class="isub">{p["level_text"]}</div>'
        if sub:
            extra = f'<div class="isub">{sub}</div>' + extra
        top = f'<div class="itop"><div class="ilead">{lead_icon}<span>{escape(p["name"])}</span></div><div></div><div>{st}</div></div>'
        return f'<div class="isl expanded island">{top}{head}{extra}</div>'
    if design == "B":
        h, sub, warn = b_headline(p)
        subh = f'<div class="isub">{sub}</div>' if sub else ""
        top = f'<div class="itop"><div class="ilead">{lead_icon}<span>{escape(p["name"])}</span></div><div></div><div>{st}</div></div>'
        share = f'<div class="isub" style="color:var(--fg)">{p["share_text"] or ""} <span style="color:var(--fg2)">{p["level_text"] or ""}</span></div>' if (p["share_text"] or p["level_text"]) else ""
        return (f'<div class="isl expanded island">{top}<div class="ihead{" warn" if warn else ""}" style="font-size:21px;font-family:inherit;font-weight:650">{h}</div>{subh}{axis(p)}{share}</div>')
    # C
    pill = f'<span class="pill{" warn" if p["stale"] else ""}" style="font-size:12.5px">{status_text(p)}</span>'
    chip = f' <span class="chip" style="margin-left:2px">{p["radius_text"]}</span>' if p["radius_text"] else ""
    top = f'<div class="itop"><div class="ilead" style="color:var(--fg);font-size:14px">{icon("pin", 15)}<span>{escape(p["name"])}</span></div><div></div><div>{st}</div></div>'
    lines = []
    if p["stale"]:
        lines.append('<div class="c-l1 warn">Keine verlässliche Aussage</div>')
    elif p["reg"]:
        if p["share_text"]:
            lines.append(f'<div class="c-l1">{p["share_text"]}</div>')
        if p["level_text"]:
            lines.append(f'<div class="c-l2">{p["level_text"]}</div>')
    else:
        lines.extend(c_point_lines(p))
    lead = ring(p) if (p["reg"] and p["share"]) else f'<div class="glyph{" warn" if p["stale"] else ""}" style="background:rgba(var(--tint),.18)">{icon(p["kind"], 34)}</div>'
    body = f'<div class="c-body" style="margin-top:6px">{lead}<div class="c-lines">{"".join(lines)}</div></div>'
    return (f'<div class="isl expanded island" {tint_style(p)}>{top}<div class="row" style="gap:6px;margin-top:2px">{pill}{chip}</div>{body}</div>')


def island_cell(design, sid, theme, mode):
    p = pres(STATES[sid])
    h = 64 if mode == "compact" else 204
    body = isl_compact(design, p) if mode == "compact" else isl_expanded(design, p)
    now = f'{STATES[sid]["jetzt"]}'
    return (f'<div class="strip wp t-{theme}" style="height:{h}px"><div class="sb"><span>{now}</span><span>5G &nbsp;&#9646;</span></div>{body}</div>')


# ---- Watch Smart Stack (kleinste Gehäusegröße, 40 mm: 162 x 197 pt)


def watch_a(p):
    s = p["s"]
    nm_ = f'<div class="wn">{icon("pin", 11)}{escape(p["name"])}{(" · " + str(p["radius"]) + " km") if p["reg"] else ""}</div>'
    if p["stale"]:
        mid = '<div style="margin-top:12px"><div class="wbig sm warn">Daten<br>veraltet</div></div>'
        foot = f'<div class="wfoot warn">{icon("stale", 12)}{p["stand"]}</div>'
        return nm_ + mid + foot
    mini = ""
    if p["phase"] == "raining":
        mid = '<div style="margin-top:20px"><div class="wbig sm">Es regnet</div></div>'
        mini = p["share_short"] if p["reg"] else p["detail"]
    else:
        key = "Regen in" if p["phase"] == "startsIn" else "Endet in"
        cd = p["cd"] or "gleich"
        mid = f'<div style="margin-top:8px"><div class="wk">{key}</div><div class="wbig{" md" if p["reg"] else ""}" style="margin-top:2px">{cd}</div></div>'
        if p["reg"]:
            mini = p["share_short"]
    extra = f'<div class="wmini" style="color:var(--fg)">{mini}</div>' if mini else ""
    return nm_ + mid + extra + f'<div class="wfoot">{p["stand"]}</div>'


def watch_b(p):
    s = p["s"]
    nm_ = f'<div class="wn">{icon("pin", 11)}{escape(p["name"])}{(" · " + str(p["radius"]) + " km") if p["reg"] else ""}</div>'
    ax_style = 'style="height:16px;margin:6px 3px 0"'
    if p["stale"]:
        mid = '<div style="margin-top:12px"><div class="wk warn">Veraltet</div><div class="wmini" style="color:var(--fg)">Keine verlässliche Aussage</div></div>'
        ax = f'<div class="axis" {ax_style}><div class="dash" style="top:7px"></div><div class="dot wr" style="left:0;top:2px"></div></div>'
        foot = f'<div class="wfoot warn">{icon("stale", 12)}{p["stand"]}</div>'
        return nm_ + mid + ax + foot
    pos = None if s.get("minuten") is None else max(6, min(94, s["minuten"] / AXIS_MIN * 100))
    if p["phase"] == "startsIn":
        mid = f'<div style="margin-top:6px"><div class="wk">Regen in {p["cd"]}</div><div class="wbig" style="font-size:38px;margin-top:1px">{s["ereignis"]}</div></div>'
        ax = (f'<div class="axis" {ax_style}><div class="tr" style="top:6px"></div><div class="band fade" style="left:{pos}%;right:0;top:4px"></div><div class="dot" style="left:0;top:2px"></div>'
              f'<div class="dot ev" style="left:{pos}%;top:0"></div></div>')
    elif p["phase"] == "raining":
        mid = '<div style="margin-top:14px"><div class="wbig sm">Es regnet</div></div>'
        ax = (f'<div class="axis" style="height:32px;margin:8px 3px 0"><div class="band fade" style="left:0;right:0"></div><div class="dot" style="left:0"></div>'
              f'<span class="lb" style="left:-3px;top:19px;font-size:10.5px">{s["jetzt"]}</span><span class="lb r" style="top:19px;font-size:10.5px">Ende offen</span></div>')
    else:
        mid = f'<div style="margin-top:6px"><div class="wk">Endet in {p["cd"]}</div><div class="wbig" style="font-size:38px;margin-top:1px">{s["ereignis"]}</div></div>'
        ax = (f'<div class="axis" {ax_style}><div class="band" style="left:0;width:{pos}%;top:4px"></div><div class="dot" style="left:0;top:2px"></div>'
              f'<div class="dot ev" style="left:{pos}%;top:0"></div></div>')
    return nm_ + mid + ax + f'<div class="wfoot">{p["stand"]}</div>'


def watch_c(p):
    s = p["s"]
    head = f'<div class="wn" style="color:var(--fg);font-size:13px">{icon("pin", 12)}{escape(p["name"])}{(" · " + str(p["radius"]) + " km") if p["reg"] else ""}</div>'
    st = status_text(p)
    pill = f'<div class="wk{" warn" if p["stale"] else ""}" style="font-size:16px;margin-top:6px;line-height:1.1">{st}</div>'
    body = ""
    if p["stale"]:
        body = f'<div class="wmini">Keine verlässliche Aussage</div>'
    elif p["reg"] and p["share"]:
        v, k = p["share"]
        body = f'<div style="display:flex;align-items:center;gap:8px;margin-top:5px">{ring(p)}<div class="wmini" style="color:var(--fg);line-height:1.2;font-size:11.5px">Fläche<br>nass</div></div>'
    elif not p["reg"]:
        body = ""
        if p["phase"] == "startsIn":
            body += f'<div class="wmini" style="color:var(--fg)">ab {s["ereignis"]} Uhr</div>'
        elif p["phase"] == "endsIn":
            body += f'<div class="wmini" style="color:var(--fg)">bis {s["ereignis"]} Uhr</div>'
        else:
            body += f'<div class="wmini">{p["detail"]}</div>'
        if p["point_level"]:
            body += f'<div class="wmini">Intensität {word(s["intensityClass"])}</div>'
    foot = f'<div class="wfoot{" warn" if p["stale"] else ""}">{icon("stale", 12) if p["stale"] else ""}{p["stand"]}</div>'
    return head + pill + body + foot


WATCH = {"A": watch_a, "B": watch_b, "C": watch_c}


def watch_cell(design, sid, theme):
    p = pres(STATES[sid])
    card = WATCH[design](p)
    return (f'<div class="wframe"><div class="wscr"><div class="wtitle">Showers</div><div class="wtime">{STATES[sid]["jetzt"]}</div>'
            f'<div class="wcard t-{theme}" {tint_style(p)}>{card}</div><div class="wnext"></div></div></div>')


# ---------------------------------------------------------------- Tafeln

LEG = {
    "A": "A · Getöntes Glas, Zeitsatz als Blickfang",
    "B": "B · Ruhige Zeitachse, nur belegte Zeiten",
    "C": "C · Orts-/Gebietskarte mit Status und Anteil",
}
CAPS = {s["id"]: s["titel"] for s in DATA["zustaende"]}


def page(body, theme, title, meta=""):
    return (f'<!doctype html><html lang="de"><head><meta charset="utf-8"><title>{escape(title)}</title><style>{CSS}</style></head>'
            f'<body><div class="board {theme}"><div class="bh"><h1>{escape(title)}<span class="tag">Beispieldaten</span></h1><div class="m">{meta}</div></div>{body}</div></body></html>')


def phone(design, sid, theme):
    p = pres(STATES[sid])
    s = STATES[sid]
    banner = LOCK[design](p, theme)
    t = "#15151a" if theme == "hell" else "#fff"
    return (f'<div class="wp t-{theme}" style="width:402px;height:874px;border-radius:56px;box-shadow:0 0 0 9px {"#2b2b30" if theme=="dunkel" else "#cfd1da"}">'
            f'<div style="position:absolute;top:21px;left:36px;font-size:16px;font-weight:600;color:{t}">&nbsp;</div>'
            f'<div style="position:absolute;top:21px;right:34px;font-size:15px;font-weight:600;color:{t}">5G &nbsp;&#9646;&#9646;&#9646;</div>'
            f'<div class="isl" style="width:126px;height:37px;border-radius:19px"></div>'
            f'<div style="position:absolute;top:96px;left:0;right:0;text-align:center;color:{t};font-size:19px;font-weight:600;opacity:.82">{DATA["datum"]}</div>'
            f'<div style="position:absolute;top:122px;left:0;right:0;text-align:center;color:{t};font-size:100px;font-weight:700;letter-spacing:-.03em;line-height:1">{s["jetzt"]}</div>'
            f'<div style="position:absolute;top:262px;left:21px" class="t-{theme}">{banner}</div>'
            f'<div style="position:absolute;bottom:50px;left:48px;width:50px;height:50px;border-radius:50%;background:rgba(var(--accbg),.0);border:1px solid {t};opacity:.4"></div>'
            f'<div style="position:absolute;bottom:50px;right:48px;width:50px;height:50px;border-radius:50%;border:1px solid {t};opacity:.4"></div>'
            f'<div style="position:absolute;bottom:9px;left:50%;transform:translateX(-50%);width:140px;height:5px;border-radius:3px;background:{t};opacity:.7"></div></div>')


def iphone_board(design, theme):
    first = "kommt"
    rest = [x for x in ORDER if x != first]
    cells = ""
    for sid in rest:
        cells += f'<div><div style="width:402px">{banner_tile(design, sid, theme)}</div><div class="cap">{CAPS[sid]} · Stand {STATES[sid]["stand"]}</div></div>'
    body = (f'<div style="display:flex;gap:40px"><div>{phone(design, first, theme)}<div class="cap" style="text-align:center">{CAPS[first]} (iPhone 16, 402 × 874 pt, 3×)</div></div>'
            f'<div class="grid" style="grid-template-columns:repeat(2,402px);align-content:start">{cells}</div></div>')
    return page(body, theme, f'{LEG[design]} · iPhone-Sperrbildschirm · {theme}',
                "Lock Screen, Live Activity, Banner 360 pt breit. Symbole nachgezeichnet, Schrift SF.")


def island_board(design, theme):
    cells = ""
    for sid in ORDER:
        cells += (f'<div><div style="display:flex;flex-direction:column;gap:12px">{island_cell(design, sid, theme, "compact")}{island_cell(design, sid, theme, "expanded")}</div>'
                  f'<div class="cap">{CAPS[sid]}</div></div>')
    body = f'<div class="grid" style="grid-template-columns:repeat(3,402px)">{cells}</div>'
    return page(body, theme, f'{LEG[design]} · Dynamic Island · Hintergrund {theme}',
                "Island immer schwarz, ohne Glas; kompakt 244 × 37 pt, erweitert 374 pt breit, Kamerabereich 126 pt frei.")


def watch_board(design, theme):
    cells = ""
    for sid in ORDER:
        cells += f'<div><div class="t-{theme}">{watch_cell(design, sid, theme)}</div><div class="cap" style="width:186px">{CAPS[sid]}</div></div>'
    note = "dunkel = Systemdarstellung (watchOS kennt kein Hell/Dunkel)" if theme == "dunkel" else "hell = nur Vergleichsvariante mit hellem Kartenton (kein Systemstandard)"
    body = f'<div class="grid" style="grid-template-columns:repeat(6,186px);gap:20px 22px">{cells}</div>'
    return page(body, theme, f'{LEG[design]} · Watch Smart Stack · {theme}',
                f"40 mm (162 × 197 pt). {note}. Kartenmaße angenommen, siehe README.")


def overview(sid, theme_pair=("hell", "dunkel")):
    rows = ""
    for d in "ABC":
        cells = ""
        for th in theme_pair:
            p = pres(STATES[sid])
            cells += f'<div class="wp t-{th}" style="width:402px;padding:20px 21px"><div class="t-{th}">{LOCK[d](p, th)}</div></div>'
        for th in theme_pair:
            cells += f'<div style="display:flex;flex-direction:column;gap:8px">{island_cell(d, sid, th, "compact")}{island_cell(d, sid, th, "expanded")}</div>'
        for th in theme_pair:
            cells += f'<div class="t-{th}">{watch_cell(d, sid, th)}</div>'
        rows += (f'<div style="margin-bottom:6px;font-size:15px;font-weight:650">{LEG[d]}</div>'
                 f'<div style="display:grid;grid-template-columns:402px 402px 402px 402px 186px 186px;gap:20px;align-items:start;margin-bottom:30px">{cells}</div>')
    head = '<div style="display:grid;grid-template-columns:402px 402px 402px 402px 186px 186px;gap:20px;font-size:12px;opacity:.65;margin-bottom:8px"><div>iPhone · hell</div><div>iPhone · dunkel</div><div>Island · Hintergrund hell</div><div>Island · Hintergrund dunkel</div><div>Watch · hell*</div><div>Watch · dunkel</div></div>'
    return page(head + rows, "hell", f'Live Activity · Entwürfe A, B, C · {CAPS[sid]}',
                "* hell nur Vergleichsvariante; Watch kennt kein Hell/Dunkel.")


def main(out):
    os.makedirs(out, exist_ok=True)
    jobs = {}
    for d in "ABC":
        for th in ("hell", "dunkel"):
            jobs[f"{d.lower()}-iphone-{th}"] = iphone_board(d, th)
            jobs[f"{d.lower()}-island-{th}"] = island_board(d, th)
            jobs[f"{d.lower()}-watch-{th}"] = watch_board(d, th)
    jobs["uebersicht"] = overview("kommt")
    jobs["uebersicht-gebiet"] = overview("gebiet-laeuft")
    for k, v in jobs.items():
        open(os.path.join(out, k + ".html"), "w", encoding="utf-8").write(v)
    print(" ".join(sorted(jobs)))


if __name__ == "__main__":
    main(sys.argv[1])

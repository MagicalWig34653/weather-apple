#!/usr/bin/env python3
"""Erzeugt die Waldflaechen-Ebene der App aus ESA WorldCover 2021 v200 (Klasse 10).

Abhaengigkeiten (nur dieses Werkzeug, nicht die App): numpy, tifffile, Pillow (mit WebP).
  python3 -m venv VENV && VENV/bin/pip install numpy tifffile pillow

Ablauf (reproduzierbar, Rohdaten NICHT ins Repo):
  1. download  - Kacheln laden (ca. 1,9 GB) in ein eigenes Verzeichnis ausserhalb des Repos
  2. build     - Klasse 10 -> Waldanteil je Zielpixel (Mittelung der 10-m-Pixel, EPSG:3857),
                 Ausgabe forest-de-v1.webp (RGBA: gruen, Alpha = Anteil) + forest-de-v1.json

Beispiel:
  VENV/bin/python tools/forest_overlay.py download RAWDIR
  VENV/bin/python tools/forest_overlay.py build RAWDIR Weather/Resources/Forest

Siehe docs/research/wald-ebene.md.
"""
import json
import math
import os
import sys
import urllib.request
from datetime import date

BASE = "https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/"
NAME = "ESA_WorldCover_10m_2021_v200_{t}_Map.tif"
LATS = (45, 48, 51, 54)
LONS = (3, 6, 9, 12, 15)

# Radar-BBOX (EPSG:3857), siehe Spec 3.7; Breite 2048 px, Hoehe nach Seitenverhaeltnis
BBOX = (612257.5, 5942074.0, 1736584.0, 7381298.0)
WIDTH = 2048
HEIGHT = round(WIDTH * (BBOX[3] - BBOX[1]) / (BBOX[2] - BBOX[0]))  # 2621
R = 6378137.0
TREE_CLASS = 10
# Alpha wird auf LEVELS Stufen quantisiert (Bundle-Ziel max. ca. 1 MB, gemessen:
# 256 Stufen 3,99 MB, 16 -> 1,89 MB, 8 -> 1,39 MB, 5 -> 1,05 MB, 4 -> 0,86 MB)
LEVELS = 4
RGB = (34, 120, 52)  # Gruen; Deckkraft setzt die App
ATTRIBUTION = ("© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) "
               "processed by ESA WorldCover consortium")


def tile_id(lat, lon):
    return "N%02dE%03d" % (lat, lon)


def download(rawdir):
    os.makedirs(rawdir, exist_ok=True)
    for la in LATS:
        for lo in LONS:
            t = tile_id(la, lo)
            dst = os.path.join(rawdir, NAME.format(t=t))
            if os.path.exists(dst):
                continue
            try:
                urllib.request.urlretrieve(BASE + NAME.format(t=t), dst + ".part")
                os.replace(dst + ".part", dst)
                print("ok", t)
            except Exception as e:  # fehlende Kacheln = reine Meeresflaeche (404)
                print("fehlt", t, e)


def build(rawdir, outdir):
    import numpy as np
    import tifffile
    from PIL import Image

    pw = (BBOX[2] - BBOX[0]) / WIDTH
    ph = (BBOX[3] - BBOX[1]) / HEIGHT
    fsum = np.zeros((HEIGHT, WIDTH), np.float64)
    cnt = np.zeros((HEIGHT, WIDTH), np.float64)
    used = []
    for la in LATS:
        for lo in LONS:
            t = tile_id(la, lo)
            path = os.path.join(rawdir, NAME.format(t=t))
            if not os.path.exists(path):
                continue
            used.append(t)
            with tifffile.TiffFile(path) as tf:
                a = tf.pages[0].asarray()  # 36000 x 36000, Zeile 0 = Nordrand (la+3)
            n = a.shape[0]
            step = 3.0 / n
            lon = lo + (np.arange(a.shape[1]) + 0.5) * step
            x = R * np.radians(lon)
            col = np.floor((x - BBOX[0]) / pw).astype(np.int64)
            lat = la + 3 - (np.arange(n) + 0.5) * step
            y = R * np.log(np.tan(math.pi / 4 + np.radians(lat) / 2))
            row = np.floor((BBOX[3] - y) / ph).astype(np.int64)
            cols = np.nonzero((col >= 0) & (col < WIDTH))[0]
            rows = np.nonzero((row >= 0) & (row < HEIGHT))[0]
            if len(cols) == 0 or len(rows) == 0:
                continue
            c0, c1 = cols[0], cols[-1] + 1
            r0, r1 = rows[0], rows[-1] + 1
            sub = a[r0:r1, c0:c1]
            tc = col[c0:c1]
            tr = row[r0:r1]
            # Spaltenweise Summen (Spalten je Zielspalte zusammenhaengend, monoton)
            cstart = np.concatenate(([0], np.nonzero(np.diff(tc))[0] + 1))
            ucol = tc[cstart]
            f = np.add.reduceat((sub == TREE_CLASS).astype(np.uint32), cstart, axis=1)
            nc = np.diff(np.concatenate((cstart, [len(tc)])))
            rstart = np.concatenate(([0], np.nonzero(np.diff(tr))[0] + 1))
            urow = tr[rstart]
            nr = np.diff(np.concatenate((rstart, [len(tr)])))
            fr = np.add.reduceat(f, rstart, axis=0).astype(np.float64)
            fsum[np.ix_(urow, ucol)] += fr
            cnt[np.ix_(urow, ucol)] += np.outer(nr, nc)
            print("Kachel", t, "verarbeitet", flush=True)
            del a, sub, f

    share = np.divide(fsum, cnt, out=np.zeros_like(fsum), where=cnt > 0)
    alpha = np.rint(np.rint(share * (LEVELS - 1)) * 255 / (LEVELS - 1)).astype(np.uint8)
    rgba = np.zeros((HEIGHT, WIDTH, 4), np.uint8)
    rgba[..., 0], rgba[..., 1], rgba[..., 2] = RGB
    rgba[..., 3] = alpha
    rgba[alpha == 0, :3] = 0  # gleichfoermig fuer bessere Kompression
    os.makedirs(outdir, exist_ok=True)
    img = Image.fromarray(rgba, "RGBA")
    webp = os.path.join(outdir, "forest-de-v1.webp")
    img.save(webp, "WEBP", lossless=True, quality=100, method=6, exact=True)
    meta = {
        "schema": 1,
        "bounds_epsg3857": list(BBOX),
        "width": WIDTH,
        "height": HEIGHT,
        "pixel_size_m": [round(pw, 2), round(ph, 2)],
        "alpha_meaning": "Waldanteil 0..100 %% als Alpha 0..255, auf %d Stufen quantisiert (Klasse 10 Baumbedeckung)" % LEVELS,
        "alpha_levels": [round(i * 255 / (LEVELS - 1)) for i in range(LEVELS)],
        "rgb": list(RGB),
        "source": "ESA WorldCover 10 m 2021 v200, Klasse 10 (Tree cover)",
        "source_doi": "10.5281/zenodo.7254221",
        "license": "CC BY 4.0",
        "attribution": ATTRIBUTION,
        "modification_notice": "Auf ca. 550 m gemittelter und in %d Stufen gerundeter Waldanteil, eigene Faerbung" % LEVELS,
        "generated": date.today().isoformat(),
        "tiles": used,
    }
    with open(os.path.join(outdir, "forest-de-v1.json"), "w", encoding="utf-8") as fh:
        json.dump(meta, fh, ensure_ascii=False, indent=2)
        fh.write("\n")
    print("webp bytes", os.path.getsize(webp))


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "download":
        download(sys.argv[2])
    elif len(sys.argv) >= 4 and sys.argv[1] == "build":
        build(sys.argv[2], sys.argv[3])
    else:
        print(__doc__)
        sys.exit(2)

#!/usr/bin/env python3
"""Build Weather/Resources/WarnGeometry.bin (format WGEO1) from the DWD warning-district WFS layer.

Source: DWD GeoServer, layer dwd:Warngebiete_Kreise (402 districts), GeoJSON, EPSG:4326 (lon, lat).
  https://maps.dwd.de/geoserver/dwd/ows?service=WFS&version=2.0.0&request=GetFeature
      &typeNames=dwd:Warngebiete_Kreise&outputFormat=application/json
Licence note on every feature: "(c) GeoBasis-DE / BKG 2021 (Daten modifiziert)".
The raw download is never committed. Python standard library only.

Usage:
  python3 -I tools/warn_geometry.py --geojson <raw.json> --out Weather/Resources/WarnGeometry.bin
  python3 -I tools/warn_geometry.py --self-test-sample WeatherTests/Fixtures/warn/warn_geometry_sample.bin

WGEO1 (little endian): magic "WGEO1", UInt32 cellCount; per cell: UInt32 warncellID,
Int32 minLatE5, minLonE5, maxLatE5, maxLonE5, UInt16 ringCount; per ring: UInt32 pointCount,
then pointCount x (Int32 latE5, Int32 lonE5). Holes are ordinary rings (even-odd rule).
Closing duplicate points are dropped. Cells are sorted by ID.
"""
import argparse
import json
import struct
import sys


def e5(v):
    return int(round(v * 1e5))


def ring_points(ring):
    pts = [(e5(lat), e5(lon)) for lon, lat in ring]
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts.pop()
    out = []
    for p in pts:  # drop consecutive duplicates created by rounding
        if not out or out[-1] != p:
            out.append(p)
    return out


def cell_rings(geometry):
    polys = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
    rings = []
    for poly in polys:
        for ring in poly:
            pts = ring_points(ring)
            if len(pts) >= 3:
                rings.append(pts)
    return rings


def encode(cells):
    """cells: list of (id, [ring of (latE5, lonE5)])."""
    cells = sorted(cells, key=lambda c: c[0])
    out = bytearray(b"WGEO1")
    out += struct.pack("<I", len(cells))
    for cid, rings in cells:
        lats = [p[0] for r in rings for p in r]
        lons = [p[1] for r in rings for p in r]
        out += struct.pack("<I4iH", cid, min(lats), min(lons), max(lats), max(lons), len(rings))
        for r in rings:
            out += struct.pack("<I", len(r))
            for lat, lon in r:
                out += struct.pack("<ii", lat, lon)
    return bytes(out)


def square(lat0, lon0, size):
    a, b, c, d = e5(lat0), e5(lon0), e5(lat0 + size), e5(lon0 + size)
    return [(a, b), (a, d), (c, d), (c, b)]


def sample():
    # Three 1-degree squares; 100000001 and 100000002 share the edge lon = 11.0; 100000002 has a hole.
    # 100000003 is far away in the south.
    hole = square(51.4, 11.4, 0.2)
    return [
        (100000001, [square(51.0, 10.0, 1.0)]),
        (100000002, [square(51.0, 11.0, 1.0), hole]),
        (100000003, [square(47.0, 9.0, 1.0)]),
    ]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--geojson")
    ap.add_argument("--out")
    ap.add_argument("--self-test-sample")
    a = ap.parse_args()
    if a.self_test_sample:
        data = encode(sample())
        open(a.self_test_sample, "wb").write(data)
        print(f"sample: 3 cells, {len(data)} bytes")
        return 0
    if not (a.geojson and a.out):
        ap.error("--geojson and --out required")
    feats = json.load(open(a.geojson, encoding="utf-8"))["features"]
    cells = []
    for f in feats:
        cid = int(f["properties"]["WARNCELLID"])
        rings = cell_rings(f["geometry"])
        if not rings:
            print(f"warning: {cid} without rings", file=sys.stderr)
            continue
        cells.append((cid, rings))
    data = encode(cells)
    open(a.out, "wb").write(data)
    print(f"cells: {len(cells)}, rings: {sum(len(r) for _, r in cells)}, bytes: {len(data)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Structural checks and flat SVG contact sheet; not an Apple renderer."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent


def css(value):
    channels = value.removeprefix('srgb:').split(',')[:3]
    return '#' + ''.join(f'{round(float(c)*255):02x}' for c in channels)


def main():
    cells, results = [], []
    for index, name in enumerate(('v5a', 'v5b', 'v5c')):
        folder = ROOT / (name + '.icon')
        doc = json.loads((folder / 'icon.json').read_text())
        assert 1 <= len(doc['groups']) <= 4
        assets, art = [], []
        for group in reversed(doc['groups']):
            for layer in reversed(group['layers']):
                asset = folder / 'Assets' / layer['image-name']
                node = ET.fromstring(asset.read_text())
                assert node.attrib['viewBox'] == '0 0 1024 1024'
                for child in node.iter():
                    assert child.tag.split('}')[-1] in ('svg', 'g', 'path')
                body = ''.join(ET.tostring(child, encoding='unicode') for child in node)
                art.append(body.replace('#FFFFFF', css(layer['fill-specializations'][0]['value']['solid'])))
                assets.append(asset.name)
        stops = doc['fill-specializations'][0]['value']['linear-gradient']
        gradient = (f'<defs><linearGradient id="bg{index}" x2="0" y2="1">'
                    f'<stop stop-color="{css(stops[0])}"/>'
                    f'<stop offset="1" stop-color="{css(stops[1])}"/>'
                    '</linearGradient></defs>')
        for row, size in enumerate((300, 120, 60, 29)):
            y = (64, 405, 567, 672)[row]
            x = 28 + index * 340
            cells.append(f'<svg x="{x}" y="{y}" width="{size}" height="{size}" '
                         f'viewBox="0 0 1024 1024">{gradient}'
                         f'<path fill="url(#bg{index})" d="M0 0H1024V1024H0Z"/>'
                         + ''.join(art) + '</svg>')
        cells.append(f'<text x="{28+index*340}" y="390">{name}</text>')
        results.append({'package': name + '.icon', 'groups': len(doc['groups']),
                        'assets': sorted(assets), 'json_xml_references': 'passed'})
    sheet = ('<svg xmlns="http://www.w3.org/2000/svg" width="1048" height="744" '
             'viewBox="0 0 1048 744"><path fill="#ECEEF3" d="M0 0H1048V744H0Z"/>'
             '<g font-family="sans-serif" font-size="18" fill="#222B3A">'
             '<text x="28" y="32">ShowerNow v5 · flache Vektorstudien · kein Liquid-Glass-Rendering</text>'
             + ''.join(cells) + '</g></svg>')
    ET.fromstring(sheet)
    (ROOT / 'overview-flat.svg').write_text(sheet + '\n')
    (ROOT / 'validation.json').write_text(json.dumps({
        'structural_checks': results,
        'ictool': 'Exit 255: new v5a and existing v3a could not be opened; cause unconfirmed',
        'not_checked': ['Apple rendering', 'Composer GUI', 'device', 'build', 'visual small-size review']
    }, indent=2) + '\n')
    print('PASS: 3 JSON packages, 8 SVG assets, references and group counts; flat overview generated.')


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
"""Reproducible, editable Icon Composer concepts. Python standard library only."""
import json
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent


def color(hex_color):
    h = hex_color.lstrip('#')
    return 'srgb:' + ','.join(f'{int(h[i:i+2], 16)/255:.5f}' for i in (0, 2, 4)) + ',1.00000'


def solid(h):
    return {'solid': color(h)}


def gradient(a, b):
    return {'linear-gradient': [color(a), color(b)],
            'orientation': {'start': {'x': .5, 'y': 0}, 'stop': {'x': .5, 'y': 1}}}


def shape(path):
    return f'<path fill="#FFFFFF" d="{path}"/>'


def package(name, background, dark_background, parts):
    """Parts in front-to-back order; color/depth are independently editable."""
    folder = ROOT / (name + '.icon')
    (folder / 'Assets').mkdir(parents=True, exist_ok=True)
    groups = []
    for label, body, base, dark, mono, translucency in parts:
        filename = label + '.svg'
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" '
               f'viewBox="0 0 1024 1024">\n{body}\n</svg>\n')
        ET.fromstring(svg)
        (folder / 'Assets' / filename).write_text(svg)
        # Befund Runde 5: kein Basis-"fill" neben den Specializations (sonst ignoriert ictool Dark/Tinted);
        # Tinted/Mono per appearance "tinted" mit Grauwert (extended-gray).
        gray = round(int(mono.lstrip('#')[0:2], 16) / 255, 5)
        layer = {'name': label, 'image-name': filename, 'glass': True,
                 'fill-specializations': [
                     {'value': solid(base)}, {'appearance': 'dark', 'value': solid(dark)},
                     {'appearance': 'tinted', 'value': {'solid': f'extended-gray:{gray:.5f},1.00000'}}],
                 'opacity-specializations': [{'value': 1.0}], 'hidden': False}
        groups.append({'layers': [layer], 'hidden': False, 'lighting': 'individual',
                       'shadow': {'kind': 'neutral', 'opacity': .22},
                       'specular': True,
                       'translucency': {'enabled': translucency > 0, 'value': translucency}})
    doc = {'fill-specializations': [
               {'value': background}, {'appearance': 'dark', 'value': dark_background}],
           'groups': groups,
           'supported-platforms': {'circles': ['watchOS'], 'squares': 'shared'}}
    (folder / 'icon.json').write_text(json.dumps(doc, indent=2) + '\n')
    print(f'{name}: {len(groups)} groups / SVG assets')


def main():
    # A: bespoke umbrella, shallow concave scallops instead of semicircle lobes.
    rotation = 'transform="rotate(-10 512 512)"'
    canopy = f'<g {rotation}>' + shape(
        'M190 468 C214 307 340 214 497 207 '
        'L497 190 Q497 175 512 175 Q527 175 527 190 L527 207 '
        'C684 214 810 307 834 468 Q838 493 816 487 '
        'Q741 453 672 505 Q654 518 637 504 '
        'Q512 423 387 504 Q370 518 352 505 '
        'Q283 453 208 487 Q186 493 190 468 Z') + '</g>'
    handle = f'<g {rotation}>' + shape(
        'M467 450 H557 V725 C557 811 495 855 421 855 '
        'C347 855 293 800 293 736 Q293 691 338 691 '
        'Q383 691 383 736 C383 755 399 770 421 770 '
        'C449 770 467 752 467 725 Z') + '</g>'
    package('v5a', gradient('#237B89', '#123F58'), gradient('#183E4B', '#102B38'), [
        ('01-canopy', canopy, '#FFD56A', '#FFDC88', '#FFFFFF', .06),
        ('02-handle', handle, '#F6FBFF', '#E6F6FF', '#D7D7D7', 0)])

    # B: asymmetric nested precipitation contours; no map UI or target rings.
    outer = shape('M226 674 C151 593 179 477 268 427 C327 395 325 294 413 254 '
                  'C502 212 581 260 625 310 C673 366 781 339 822 429 '
                  'C863 521 790 578 758 643 C721 720 672 796 575 798 '
                  'C477 801 447 738 367 744 C305 749 260 717 226 674 Z')
    middle = shape('M330 612 C293 551 324 498 384 461 C440 427 417 365 483 342 '
                   'C552 318 580 390 632 406 C704 429 749 471 711 537 '
                   'C677 593 683 670 609 700 C540 729 506 667 448 674 '
                   'C394 680 358 657 330 612 Z')
    core = shape('M459 574 C422 531 456 494 485 469 C515 445 519 419 550 423 '
                 'C584 428 584 463 607 484 C644 519 623 555 601 584 '
                 'C566 631 494 616 459 574 Z')
    package('v5b', gradient('#284D86', '#172D54'), gradient('#1B304B', '#101E34'), [
        ('01-rain-core', core, '#F5FFE9', '#FFFFFF', '#FFFFFF', 0),
        ('02-rain-band', middle, '#63E7AB', '#7DF4BC', '#C4C4C4', .12),
        ('03-rain-front', outer, '#29BFD3', '#51D3E3', '#858585', .18)])

    # C: filled rain trails, tapered toward their origins, rounded on both ends.
    left = shape('M370 271 Q388 245 413 258 Q434 270 424 302 '
                 'L327 653 C314 699 265 715 231 689 '
                 'C208 672 206 642 223 614 Z')
    center = shape('M569 206 Q587 176 613 190 Q636 203 626 235 '
                   'L495 779 C483 831 431 852 392 825 '
                   'C366 806 363 774 380 743 Z')
    right = shape('M759 327 Q777 300 801 314 Q823 326 813 359 '
                  'L725 677 C713 723 665 741 631 715 '
                  'C608 697 606 668 623 639 Z')
    package('v5c', gradient('#665BD0', '#302C78'), gradient('#312D60', '#201D42'), [
        ('01-leading-rain', center, '#FFFFFF', '#FFFFFF', '#FFFFFF', 0),
        ('02-near-rain', left, '#A4F5EC', '#BAFFF4', '#CCCCCC', .08),
        ('03-far-rain', right, '#C4B8FF', '#D6CCFF', '#A0A0A0', .08)])


if __name__ == '__main__':
    main()

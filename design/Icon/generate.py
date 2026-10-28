"""Generate the two original editable full-bleed map concepts. No bitmap sources."""
from pathlib import Path
import json

root = Path(__file__).parent
map_content = '''
  <g id="map-base">
    <rect width="1024" height="1024" fill="#cbdabd"/>
    <path d="M-40-40H405C360 137 250 191 207 335S53 489-40 465Z" fill="#a5c394"/>
    <path d="M730 766C829 683 935 702 1060 607V1060H610C602 921 650 847 730 766Z" fill="#abc89a"/>
    <path d="M210-110C232 72 407 168 432 331S318 563 387 719S581 958 549 1133" fill="none" stroke="#e1e4d6" stroke-width="149"/>
    <path d="M210-110C232 72 407 168 432 331S318 563 387 719S581 958 549 1133" fill="none" stroke="#83cbd4" stroke-width="128"/>
    <g fill="none" stroke-linejoin="round" stroke-linecap="round">
      <path d="M-89 757C123 815 267 720 431 639S803 460 1114 506" stroke="#bbc9b4" stroke-width="49"/>
      <path d="M-89 757C123 815 267 720 431 639S803 460 1114 506" stroke="#faf9ee" stroke-width="34"/>
      <path d="M-70 230L267 328 591 238 1091 155" stroke="#b8c7b0" stroke-width="35"/>
      <path d="M-70 230L267 328 591 238 1091 155" stroke="#f9f8ec" stroke-width="24"/>
      <path d="M604-70L602 248 702 532 765 1103" stroke="#b9c9b1" stroke-width="34"/>
      <path d="M604-70L602 248 702 532 765 1103" stroke="#f9f8ed" stroke-width="23"/>
      <path d="M120 1024L191 816 143 599 250 325" stroke="#f6f6e9" stroke-width="13"/>
      <path d="M1024 802L762 792 597 900 334 948" stroke="#f5f6e9" stroke-width="13"/>
      <path d="M786 0L795 207 1014 325" stroke="#f5f6e9" stroke-width="12"/>
      <path d="M0 454L153 502 321 465" stroke="#f5f6e9" stroke-width="12"/>
    </g>
    <path d="M371 647L423 622" stroke="#fdf9e9" stroke-width="43" stroke-linecap="butt"/>
  </g>
'''
cloud = '''
  <defs>
    <linearGradient id="cloud-shade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#ffffff"/>
      <stop offset="1" stop-color="#e9f4f8"/>
    </linearGradient>
  </defs>
  <g id="cloud-shadow" opacity="0.15">
    <path d="M299 629C237 629 199 588 199 535C199 481 242 443 294 443C310 368 366 319 435 319C503 319 556 364 575 421C595 411 616 405 637 405C699 405 748 453 751 513C798 516 831 549 831 590C831 635 797 668 751 668H302Z" fill="#28485c"/>
  </g>
  <g id="cloud">
    <path d="M298 605C237 605 197 565 197 511C197 457 240 419 292 419C308 344 364 295 433 295C501 295 554 340 573 397C593 387 614 381 635 381C697 381 746 429 749 489C796 492 829 525 829 566C829 611 795 644 749 644H301Z" fill="url(#cloud-shade)"/>
  </g>
  <g id="rain" fill="none" stroke="#138ab0" stroke-width="25" stroke-linecap="round">
    <path d="M351 716L323 763"/>
    <path d="M512 710L483 760"/>
    <path d="M673 707L645 755"/>
  </g>
'''
radar = '''
  <g id="radar-outer">
    <path d="M474 157C538 101 614 116 654 155C702 126 783 148 796 208C875 225 904 290 886 348C941 401 912 471 866 502C880 576 824 637 758 640C724 704 649 715 604 684C543 725 468 701 445 646C371 627 351 555 380 504C339 447 358 381 404 353C382 285 411 216 474 197Z" fill="#159bd3" opacity="0.45"/>
    <path d="M133 637C183 605 242 627 250 680C309 693 325 742 294 785C316 834 284 880 227 885C191 935 130 931 105 885C49 882 31 833 56 794C32 744 63 694 105 686Z" fill="#159bd3" opacity="0.36"/>
  </g>
  <g id="radar-rain">
    <path d="M559 235C613 207 666 229 683 269C744 253 793 292 792 343C846 372 852 431 814 470C830 530 783 583 729 575C693 630 636 638 598 601C540 628 490 590 496 539C448 505 454 454 487 424C460 368 486 317 531 308Z" fill="#25bc83" opacity="0.70"/>
    <path d="M142 717C180 688 226 712 224 744C261 774 249 824 209 828C183 868 139 845 131 815C91 800 102 752 142 742Z" fill="#2bc78b" opacity="0.58"/>
  </g>
  <g id="radar-core">
    <path d="M631 339C672 313 720 334 720 373C760 390 769 436 737 463C744 506 701 533 668 509C627 534 590 506 601 469C568 441 581 398 609 390C598 365 609 346 631 339Z" fill="#f0cf50" opacity="0.87"/>
  </g>
'''
for name, overlay in [('Cloud',cloud),('Radar',radar)]:
    svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'+map_content+overlay+'\n</svg>\n'
    (root/f'{name}.icon/Assets/map-weather.svg').write_text(svg)
    document = {
        'fill': {'solid':'srgb:0.79608,0.85490,0.74118,1.00000'},
        'groups': [{'layers':[{'image-name':'map-weather.svg','name':f'Full-bleed map — {name.lower()}','glass':False,'fill':'automatic','opacity':1,'hidden':False}],
                    'hidden':False,'lighting':'individual','shadow':{'kind':'neutral','opacity':0},'specular':False,'translucency':{'enabled':False,'value':0}}],
        'supported-platforms': {'circles':['watchOS'],'squares':'shared'}
    }
    (root/f'{name}.icon/icon.json').write_text(json.dumps(document,indent=2)+'\n')
(root/'map-base.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'+map_content+'</svg>\n')

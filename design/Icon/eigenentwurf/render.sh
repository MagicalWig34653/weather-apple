#!/bin/zsh
# Usage: zsh design/Icon/eigenentwurf/render.sh   (rendert Original und final)
set -eu
IC="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
cd "$(dirname "$0")/.."
for pair in "eigenentwurf.icon original" "eigenentwurf-final.icon final"; do
  set -- ${=pair}; src=$1; o=eigenentwurf/previews/$2
  [ -d "$src" ] || continue
  mkdir -p $o
  "$IC" $src --export-image --output-file $o/default.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
  "$IC" $src --export-image --output-file $o/dark.png --platform iOS --rendition Dark --width 1024 --height 1024 --scale 1
  "$IC" $src --export-image --output-file $o/tinted.png --platform iOS --rendition TintedDark --tint-color 0.58 --tint-strength 0.8 --width 1024 --height 1024 --scale 1
  "$IC" $src --export-image --output-file $o/tinted-light.png --platform iOS --rendition TintedLight --tint-color 0.58 --tint-strength 0.8 --width 1024 --height 1024 --scale 1
  for s in 120 60 29; do "$IC" $src --export-image --output-file $o/default-$s.png --platform iOS --rendition Default --width $s --height $s --scale 1; done
done

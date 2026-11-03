#!/bin/zsh
# Usage: zsh design/Icon/eigenentwurf-dark/render.sh
set -eu
IC="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
cd "$(dirname "$0")/.."
for n in d1 d2 d3 d4; do
  s=eigenentwurf-dark/$n.icon; o=eigenentwurf-dark/previews
  for s2 in 1024 120 60 29; do
    "$IC" $s --export-image --output-file $o/$n-dark-$s2.png --platform iOS --rendition Dark --width $s2 --height $s2 --scale 1
  done
done

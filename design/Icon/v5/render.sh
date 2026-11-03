#!/bin/zsh
# Usage: zsh design/Icon/v5/render.sh [v5a|v5b|v5c]   (Namensschema wie v4: -default/-dark/-tinted, -default-120/60/29)
set -eu
IC="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
cd "$(dirname "$0")"
mkdir -p previews
names=(v5a v5b v5c)
if (( $# )); then names=("$1"); fi
for n in "${names[@]}"; do
  case "$n" in v5a|v5b|v5c) ;; *) print -u2 'Expected v5a, v5b or v5c'; exit 2;; esac
  o=previews
  "$IC" $n.icon --export-image --output-file $o/$n-default.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
  "$IC" $n.icon --export-image --output-file $o/$n-dark.png --platform iOS --rendition Dark --width 1024 --height 1024 --scale 1
  "$IC" $n.icon --export-image --output-file $o/$n-tinted.png --platform iOS --rendition TintedDark --tint-color 0.58 --tint-strength 0.8 --width 1024 --height 1024 --scale 1
  for s in 120 60 29; do "$IC" $n.icon --export-image --output-file $o/$n-default-$s.png --platform iOS --rendition Default --width $s --height $s --scale 1; done
done

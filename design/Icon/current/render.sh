#!/bin/zsh
# Rendert das produktive Icon (nur lesend) nach design/Icon/current/previews
IC="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
cd "$(dirname "$0")"; n=current; src=../../../Weather/Resources/Icon/AppIcon.icon; o=previews; mkdir -p $o
"$IC" $src --export-image --output-file $o/$n-default.png --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
"$IC" $src --export-image --output-file $o/$n-dark.png --platform iOS --rendition Dark --width 1024 --height 1024 --scale 1
"$IC" $src --export-image --output-file $o/$n-tinted.png --platform iOS --rendition TintedDark --tint-color 0.58 --tint-strength 0.8 --width 1024 --height 1024 --scale 1
for s in 120 60 29; do "$IC" $src --export-image --output-file $o/$n-default-$s.png --platform iOS --rendition Default --width $s --height $s --scale 1; done

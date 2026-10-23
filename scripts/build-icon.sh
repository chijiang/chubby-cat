#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_png="assets/icon/app-icon-v1.png"
iconset=".build/chubby-cat.iconset"
if [ -s assets/icon/AppIcon.icns ] && [ assets/icon/AppIcon.icns -nt "$source_png" ]; then
    printf 'Using current assets/icon/AppIcon.icns\n'
    exit 0
fi
mkdir -p "$iconset" assets/icon
width="$(sips -g pixelWidth "$source_png" | awk '/pixelWidth:/{print $2}')"
height="$(sips -g pixelHeight "$source_png" | awk '/pixelHeight:/{print $2}')"
[ "$width" = "$height" ] && [ "$width" -ge 1024 ] || { echo 'Icon source must be square and at least 1024 pixels.' >&2; exit 1; }
for points in 16 32 128 256 512; do
    sips -z "$points" "$points" "$source_png" --out "$iconset/icon_${points}x${points}.png" >/dev/null
    pixels=$((points * 2))
    sips -z "$pixels" "$pixels" "$source_png" --out "$iconset/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o assets/icon/AppIcon.icns
printf 'Icon built: assets/icon/AppIcon.icns\n'

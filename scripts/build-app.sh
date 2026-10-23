#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
configuration="${1:-debug}"
swift build --disable-sandbox --cache-path .build/cache --manifest-cache local -c "$configuration" --product chubby-cat
bin_dir="$(swift build --disable-sandbox --cache-path .build/cache --manifest-cache local -c "$configuration" --show-bin-path)"
app="$PWD/dist/chubby-cat.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/chubby-cat" "$app/Contents/MacOS/chubby-cat"
cp Sources/ChubbyCat/Resources/cat-atlas.png "$app/Contents/Resources/"
cp Sources/ChubbyCat/Resources/cat-master.png "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>chubby-cat</string>
<key>CFBundleDisplayName</key><string>chubby-cat</string>
<key>CFBundleIdentifier</key><string>com.deskkitty.prototype</string>
<key>CFBundleExecutable</key><string>chubby-cat</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>NSAppTransportSecurity</key><dict><key>NSAllowsLocalNetworking</key><true/></dict>
</dict></plist>
PLIST
codesign --force --deep --sign - "$app"
printf 'Built: %s\n' "$app"

#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/module-cache"
configuration="${1:-debug}"
source scripts/signing-preflight.sh
validate_version
case "$configuration" in
    debug|preview) ;;
    release) require_identity_name; verify_identity_available ;;
    *) fail 'Usage: bash scripts/build-app.sh [debug|preview|release] [--check]' ;;
esac
if [ "${2:-}" = '--check' ]; then printf 'Build prerequisites ready (%s).\n' "$configuration"; exit 0; fi
app_version="${APP_VERSION:-0.2.0}"
build_number="${BUILD_NUMBER:-2}"
bash scripts/build-icon.sh
swift_configuration="$configuration"
if [ "$configuration" = preview ]; then swift_configuration=release; fi
swift build --disable-sandbox --cache-path .build/cache --manifest-cache local -c "$swift_configuration" --product chubby-cat
bin_dir="$(swift build --disable-sandbox --cache-path .build/cache --manifest-cache local -c "$swift_configuration" --show-bin-path)"
app="$PWD/dist/chubby-cat.app"
if [ "$configuration" = release ]; then app="$PWD/dist/release-staging/chubby-cat.app"; fi
if [ "$configuration" = preview ]; then app="$PWD/dist/preview-staging/chubby-cat.app"; fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin_dir/chubby-cat" "$app/Contents/MacOS/chubby-cat"
cp Sources/ChubbyCat/Resources/cat-atlas.png "$app/Contents/Resources/"
cp Sources/ChubbyCat/Resources/cat-master.png "$app/Contents/Resources/"
if [ -d Sources/ChubbyCat/Resources/cat-frames ]; then
    rm -rf "$app/Contents/Resources/cat-frames"
    cp -R Sources/ChubbyCat/Resources/cat-frames "$app/Contents/Resources/"
fi
cp assets/icon/AppIcon.icns "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>chubby-cat</string>
<key>CFBundleDisplayName</key><string>chubby-cat</string>
<key>CFBundleIdentifier</key><string>com.deskkitty.prototype</string>
<key>CFBundleExecutable</key><string>chubby-cat</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
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
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $app_version" "$app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app/Contents/Info.plist"
if [ "$configuration" = release ]; then
    codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$app"
else
    codesign --force --sign - "$app"
fi
codesign --verify --deep --strict "$app"
printf 'Built: %s\n' "$app"
if [ "$configuration" = release ]; then printf 'Developer ID-signed staging app, not yet notarized. Run scripts/release.sh --notarized to complete this optional channel.\n'; fi
if [ "$configuration" = preview ]; then printf 'Self-distributed preview: ad-hoc signed, not notarized. Package with scripts/release.sh.\n'; fi

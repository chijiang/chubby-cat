#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing-preflight.sh
validate_version
case "${1:-}" in ''|--check) ;; *) fail 'Usage: bash scripts/package-preview.sh [--check]' ;; esac
for tool in ditto shasum lipo codesign python3; do command -v "$tool" >/dev/null || fail "Missing tool: $tool"; done
if [ "${1:-}" = --check ]; then
    printf 'Self-distributed preview prerequisites ready: ad-hoc signed, not notarized; no Apple account credentials required.\n'
    exit 0
fi
export APP_VERSION="${APP_VERSION:-0.2.0}"
export BUILD_NUMBER="${BUILD_NUMBER:-2}"
final_dir="$PWD/dist/previews"
name="chubby-cat-${APP_VERSION}-preview-macos-arm64.zip"
[ ! -e "$final_dir/$name" ] || fail 'This preview already exists. Increment APP_VERSION before creating another published preview.'
bash scripts/test.sh
python3 -m unittest discover -s Tests -p test_release_pipeline.py
bash scripts/build-app.sh preview
app="$PWD/dist/preview-staging/chubby-cat.app"
[ "$(lipo -archs "$app/Contents/MacOS/chubby-cat")" = arm64 ] || fail 'This preview package currently supports arm64 only.'
codesign --verify --deep --strict "$app"
work="$(mktemp -d "$PWD/dist/preview-staging/package.XXXXXX")"
trap 'rm -rf "$work"' EXIT
ditto "$app" "$work/chubby-cat.app"
cat > "$work/INSTALL.txt" <<'NOTE'
chubby-cat — self-distributed preview

This preview is ad-hoc signed, NOT Developer ID signed and NOT notarized by Apple.
It targets Apple Silicon Macs running macOS 14 or later. Cross-machine testing is ongoing.

Extract the ZIP, move chubby-cat.app to /Applications, and open it.
macOS may prevent it from opening under default security settings. Only proceed if
you trust the source; consult Apple's guidance and decide for yourself:
https://support.apple.com/102445

Do not disable Gatekeeper globally or run scripts to remove quarantine as part of installation.
Signing/notarization status describes platform verification, not a legal classification.

Your API key is stored in Keychain. No API credentials are included in this download.
NOTE
python3 - "$work/distribution.json" <<'PY'
import json, os, sys
with open(sys.argv[1], 'w', encoding='utf-8') as f:
    json.dump({'name': 'chubby-cat', 'version': os.environ['APP_VERSION'],
               'channel': 'self-distributed-preview', 'architecture': 'arm64', 'minimumMacOS': '14.0',
               'signing': 'ad-hoc', 'notarized': False}, f, indent=2)
    f.write('\n')
PY
mkdir -p "$final_dir"
ditto -c -k --sequesterRsrc "$work" "$final_dir/$name.partial"
mv "$final_dir/$name.partial" "$final_dir/$name"
(cd "$final_dir" && shasum -a 256 "$name" > "$name.sha256")
printf 'Self-distributed preview ready (not notarized): %s/%s\n' "$final_dir" "$name"
